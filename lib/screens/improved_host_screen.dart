import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ImprovedHostScreen extends StatefulWidget {
  const ImprovedHostScreen({super.key});

  @override
  State<ImprovedHostScreen> createState() => _ImprovedHostScreenState();
}

class _ImprovedHostScreenState extends State<ImprovedHostScreen> {
  final TextEditingController textEditingController = TextEditingController();
  late FlutterP2pHost p2pInterface;

  StreamSubscription<HotspotHostState>? hotspotStateStream;
  StreamSubscription<String>? receivedTextStream;

  HotspotHostState? hotspotState;

  @override
  void initState() {
    super.initState();
    p2pInterface = FlutterP2pHost();
    _initializeP2P();
  }

  void _initializeP2P() async {
    try {
      await p2pInterface.initialize();
      
      hotspotStateStream = p2pInterface.streamHotspotState().listen((state) {
        setState(() {
          hotspotState = state;
        });
        if (state.isActive && state.ssid != null) {
          _showSnackBar('Hotspot Active: ${state.ssid}', Colors.green);
        } else if (!state.isActive && hotspotState?.isActive == true) {
          _showSnackBar('Hotspot Inactive. Reason: ${state.failureReason}', Colors.red);
        }
      });
      
      receivedTextStream = p2pInterface.streamReceivedTexts().listen((text) {
        _showSnackBar('Received message: $text', Colors.blue);
      });
    } catch (e) {
      _showSnackBar('Failed to initialize P2P: $e', Colors.red);
    }
  }

  @override
  void dispose() {
    p2pInterface.dispose();
    textEditingController.dispose();
    hotspotStateStream?.cancel();
    receivedTextStream?.cancel();
    super.dispose();
  }

  void _showSnackBar(String msg, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(msg),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Setup Permissions & Services"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.security, color: Colors.orange),
                    title: const Text("Request Permissions"),
                    subtitle: const Text("Grant storage, location & WiFi permissions"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _requestAllPermissions();
                      },
                      child: const Text("Grant"),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.wifi, color: Colors.blue),
                    title: const Text("Enable Wi-Fi"),
                    subtitle: const Text("Required for hotspot creation"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _enableWifi();
                      },
                      child: const Text("Enable"),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.green),
                    title: const Text("Enable Location"),
                    subtitle: const Text("Required for WiFi Direct"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _enableLocation();
                      },
                      child: const Text("Enable"),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.indigo),
                    title: const Text("Enable Bluetooth"),
                    subtitle: const Text("Required for device discovery"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _enableBluetooth();
                      },
                      child: const Text("Enable"),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestAllPermissions() async {
    _showSnackBar("Requesting permissions...", Colors.orange);
    
    try {
      var storageGranted = await p2pInterface.askStoragePermission();
      var p2pGranted = await p2pInterface.askP2pPermissions();
      var bleGranted = await p2pInterface.askBluetoothPermissions();
      
      String result = "Storage: ${storageGranted ? '✓' : '✗'}, "
                     "P2P: ${p2pGranted ? '✓' : '✗'}, "
                     "Bluetooth: ${bleGranted ? '✓' : '✗'}";
      
      Color color = (storageGranted && p2pGranted && bleGranted) ? Colors.green : Colors.orange;
      _showSnackBar(result, color);
      
    } catch (e) {
      _showSnackBar("Permission request failed: $e", Colors.red);
    }
  }

  Future<void> _enableWifi() async {
    try {
      var wifiEnabled = await p2pInterface.enableWifiServices();
      _showSnackBar("Wi-Fi ${wifiEnabled ? 'enabled' : 'failed to enable'}", 
                   wifiEnabled ? Colors.green : Colors.red);
    } catch (e) {
      _showSnackBar("WiFi enable error: $e", Colors.red);
    }
  }

  Future<void> _enableLocation() async {
    try {
      var locationEnabled = await p2pInterface.enableLocationServices();
      _showSnackBar("Location ${locationEnabled ? 'enabled' : 'failed to enable'}", 
                   locationEnabled ? Colors.green : Colors.red);
    } catch (e) {
      _showSnackBar("Location enable error: $e", Colors.red);
    }
  }

  Future<void> _enableBluetooth() async {
    try {
      var bluetoothEnabled = await p2pInterface.enableBluetoothServices();
      _showSnackBar("Bluetooth ${bluetoothEnabled ? 'enabled' : 'failed to enable'}", 
                   bluetoothEnabled ? Colors.green : Colors.red);
    } catch (e) {
      _showSnackBar("Bluetooth enable error: $e", Colors.red);
    }
  }

  void _createGroup() async {
    _showSnackBar("Creating group...", Colors.blue);
    
    try {
      await p2pInterface.createGroup();
      _showSnackBar("Group created successfully! Advertising: ${p2pInterface.isAdvertising}", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to create group: $e", Colors.red);
    }
    setState(() {});
  }

  void _removeGroup() async {
    _showSnackBar("Removing group...", Colors.orange);
    
    try {
      await p2pInterface.removeGroup();
      _showSnackBar("Group removed successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to remove group: $e", Colors.red);
    }
    setState(() {});
  }

  void _shareHotspotWithQrcode() async {
    if (hotspotState == null || !hotspotState!.isActive) {
      _showSnackBar("Hotspot is not active", Colors.red);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hotspot QR Code'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: '${hotspotState!.ssid}|${hotspotState!.preSharedKey}',
            version: QrVersions.auto,
            size: 250.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    var text = textEditingController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Enter a message to send', Colors.orange);
      return;
    }
    if (!p2pInterface.isGroupCreated) {
      _showSnackBar('Group not created', Colors.red);
      return;
    }
    
    try {
      await p2pInterface.broadcastText(text);
      textEditingController.clear();
      _showSnackBar('Message sent: $text', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to send message: $e', Colors.red);
    }
  }

  void _sendFile() async {
    if (!p2pInterface.isGroupCreated) {
      _showSnackBar('Group not created', Colors.red);
      return;
    }
    
    try {
      // Use the file picker to select a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        File file = File(path);
        if (await file.exists()) {
          await p2pInterface.broadcastFile(file);
          _showSnackBar("Sending file: ${file.path.split('/').last}", Colors.blue);
        } else {
          _showSnackBar("File does not exist", Colors.red);
        }
      } else {
        _showSnackBar("File selection canceled", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("File send error: $e", Colors.red);
    }
  }

  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                ],
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isGroupActive = p2pInterface.isGroupCreated && hotspotState?.isActive == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Sync - Host'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_applications),
            onPressed: _showPermissionsDialog,
            tooltip: "Setup & Permissions",
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Hotspot Status Section
            _buildSection("Hotspot Control", [
              if (isGroupActive) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text("Status: Active", style: TextStyle(
                            color: Colors.green.shade700, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hotspotState?.ssid != null)
                        Text("SSID: ${hotspotState!.ssid!}", style: const TextStyle(fontFamily: 'monospace')),
                      if (hotspotState?.preSharedKey != null)
                        Text("Password: ${hotspotState!.preSharedKey!}", style: const TextStyle(fontFamily: 'monospace')),
                      if (hotspotState?.hostIpAddress != null)
                        Text("Host IP: ${hotspotState!.hostIpAddress!}", style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code),
                      label: const Text("Share QR Code"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: _shareHotspotWithQrcode,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text("Stop Hosting"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _removeGroup,
                    ),
                  ],
                )
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text("Status: ${p2pInterface.isGroupCreated ? 
                            (hotspotState?.isActive == false ? 
                              'Inactive (${hotspotState?.failureReason ?? "Unknown error"})' : 
                              'Creating...') : 
                            'Not Created'}", 
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text("Start Hosting"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _createGroup,
                  ),
                ),
              ],
            ], icon: Icons.wifi_tethering),

            // Connected Clients Section
            _buildSection("Connected Clients", [
              StreamBuilder<List<P2pClientInfo>>(
                stream: p2pInterface.streamClientList(),
                builder: (context, snapshot) {
                  var clientList = snapshot.data ?? [];
                  clientList = clientList.where((c) => !c.isHost).toList();
                  
                  if (clientList.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text("No clients connected yet", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }
                  
                  return SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: clientList.length,
                      itemBuilder: (context, index) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(Icons.person, color: Colors.blue.shade700),
                          ),
                          title: Text(clientList[index].username),
                          subtitle: Text('ID: ${clientList[index].id}'),
                          trailing: Icon(Icons.check_circle, color: Colors.green.shade600),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ], icon: Icons.people),

            // Send Message Section
            _buildSection("Send Message", [
              TextField(
                controller: textEditingController,
                decoration: InputDecoration(
                  hintText: 'Enter message to broadcast...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                enabled: isGroupActive,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Broadcast Message'),
                  onPressed: isGroupActive ? _sendMessage : null,
                ),
              ),
            ], icon: Icons.message),

            // Send File Section
            _buildSection("Share Files", [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Select & Share File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isGroupActive ? _sendFile : null,
                ),
              ),
            ], icon: Icons.folder_shared),

            // File Transfer Status Section
            _buildSection("File Transfer Status", [
              StreamBuilder<List<HostedFileInfo>>(
                stream: p2pInterface.streamSentFilesInfo(),
                builder: (context, snapshot) {
                  var sentFiles = snapshot.data ?? [];
                  if (sentFiles.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text("No files shared yet", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }
                  
                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: sentFiles.length,
                      itemBuilder: (context, index) {
                        var file = sentFiles[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(Icons.insert_drive_file, color: Colors.blue.shade700),
                            ),
                            title: Text(file.info.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${file.state.name}'),
                                ...file.receiverIds.map((id) {
                                  P2pClientInfo? receiverInfo;
                                  try {
                                    final currentClients = p2pInterface.clientList;
                                    receiverInfo = currentClients.where((c) => c.id == id).firstOrNull;
                                  } catch (_) {}
                                  var name = receiverInfo?.username ?? id.substring(0, min(8, id.length));
                                  var percent = file.getProgressPercent(id).round();
                                  return Text("→ $name: $percent%");
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ], icon: Icons.cloud_upload),

            // Received Files Section  
            _buildSection("Received Files", [
              StreamBuilder<List<ReceivableFileInfo>>(
                stream: p2pInterface.streamReceivedFilesInfo(),
                builder: (context, snapshot) {
                  var receivedFiles = snapshot.data ?? [];
                  if (receivedFiles.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_download_outlined, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text("No files received yet", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }
                  
                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: receivedFiles.length,
                      itemBuilder: (context, index) {
                        var file = receivedFiles[index];
                        var percent = file.downloadProgressPercent.round();
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(Icons.cloud_download, color: Colors.green.shade700),
                            ),
                            title: Text(file.info.name),
                            subtitle: Text("Status: ${file.state.name}, $percent%"),
                            trailing: _buildFileActionButton(file),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ], icon: Icons.cloud_download),
          ],
        ),
      ),
    );
  }

  Widget _buildFileActionButton(ReceivableFileInfo file) {
    switch (file.state) {
      case ReceivableFileState.idle:
        return ElevatedButton(
          onPressed: () async {
            _showSnackBar("Downloading ${file.info.name}...", Colors.blue);
            try {
              var downloaded = await p2pInterface.downloadFile(
                file.info.id,
                '/storage/emulated/0/Download/',
              );
              _showSnackBar("${file.info.name} download: ${downloaded ? 'Success' : 'Failed'}", 
                          downloaded ? Colors.green : Colors.red);
            } catch (e) {
              _showSnackBar("Download failed: $e", Colors.red);
            }
          },
          child: const Text('Download'),
        );
      case ReceivableFileState.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ReceivableFileState.completed:
        return Icon(Icons.check_circle, color: Colors.green.shade600);
      default:
        return Icon(Icons.error, color: Colors.red.shade600);
    }
  }
} 
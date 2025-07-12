import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'files_library_screen.dart';
import 'file_viewer_screen.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Folder sync state
  String? selectedDirectory;
  List<FileSystemEntity> folderFiles = [];

  // Store last received peer file list for host-initiated sync
  List<String> lastPeerFileList = [];

  @override
  void initState() {
    super.initState();
    p2pInterface = FlutterP2pHost();
    _initializeP2P();
    _listenForSyncRequests();
  }

  void _listenForSyncRequests() {
    receivedTextStream = p2pInterface.streamReceivedTexts().listen((text) async {
      if (text.startsWith("SYNC_FILE_LIST:")) {
        try {
          final theirList = List<String>.from(
            (text.substring("SYNC_FILE_LIST:".length)).split("|"),
          );
          lastPeerFileList = theirList;
          final myFiles = folderFiles
              .where((f) => FileSystemEntity.isFileSync(f.path))
              .map((f) => path.basename(f.path))
              .toList();
          // Find files they are missing
          final missingForPeer = myFiles.where((f) => !theirList.contains(f));
          for (final fileName in missingForPeer) {
            FileSystemEntity? fileToSend;
            try {
              fileToSend = folderFiles.firstWhere(
                (f) => path.basename(f.path) == fileName,
              );
            } catch (_) {
              fileToSend = null;
            }
            if (fileToSend != null && FileSystemEntity.isFileSync(fileToSend.path)) {
              await p2pInterface.broadcastFile(File(fileToSend.path));
              _showSnackBar('Sent missing file to peer: $fileName', Colors.blue);
            }
          }
          // Find files host is missing
          final missingForHost = theirList.where((f) => !myFiles.contains(f));
          // Request/download missing files from peer
          for (final fileName in missingForHost) {
            // Request file from peer (if protocol supports) or attempt to download
            // Here, we assume the peer will send the file automatically, but you can send a request if needed
            _showSnackBar('Host missing file: $fileName. Waiting for peer to send.', Colors.orange);
            // Optionally, you could send a request: await p2pInterface.broadcastText('REQUEST_FILE:' + fileName);
          }
          // Send host's file list back to peer for reverse sync
          await p2pInterface.broadcastText('HOST_FILE_LIST:' + myFiles.join('|'));
          _showSnackBar('Sent host file list to peer for reverse sync', Colors.green);
        } catch (e) {
          _showSnackBar('Sync receive error: $e', Colors.red);
        }
      }
      // Handle receiving peer's file for reverse sync (optional, if you want to notify)
      else if (text.startsWith("PEER_SEND_FILE:")) {
        try {
          final fileName = text.substring("PEER_SEND_FILE:".length);
          _showSnackBar('Received file from peer: $fileName', Colors.green);
        } catch (e) {
          _showSnackBar('Peer file receive error: $e', Colors.red);
        }
      }
    });
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Request Permissions",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    "Grant storage, location & WiFi permissions",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _requestAllPermissions();
                            },
                            child: const Text("Grant Permissions"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wifi, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Enable Wi-Fi",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    "Required for hotspot creation",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _enableWifi();
                            },
                            child: const Text("Enable Wi-Fi"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Enable Location",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    "Required for WiFi Direct",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _enableLocation();
                            },
                            child: const Text("Enable Location"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bluetooth, color: Colors.indigo),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Enable Bluetooth",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    "Required for device discovery",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _enableBluetooth();
                            },
                            child: const Text("Enable Bluetooth"),
                          ),
                        ),
                      ],
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
        title: const Text('PeerSync - Host'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FilesLibraryScreen(),
                ),
              );
            },
            tooltip: "Files Library",
          ),
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
            // Folder Selection Section
            _buildSection("Selected Folder", [
              Row(
                children: [
                  // Expanded(
                  //   child: Text(
                  //     // selectedDirectory ?? 'No folder selected',
                  //     style: const TextStyle(fontSize: 14, color: Colors.black87),
                  //     overflow: TextOverflow.ellipsis,
                  //   ),
                  // ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder),
                    label: const Text('Pick Folder'),
                    onPressed: _pickFolder,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync'),
                    onPressed: isGroupActive && selectedDirectory != null ? _syncFolderWithPeers : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (selectedDirectory != null)
                folderFiles.isEmpty
                  ? const Text('No files in this folder.', style: TextStyle(color: Colors.grey))
                  : SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: folderFiles.length,
                        itemBuilder: (context, index) {
                          final file = folderFiles[index];
                          return ListTile(
                            leading: Icon(
                              FileSystemEntity.isDirectorySync(file.path)
                                ? Icons.folder
                                : Icons.insert_drive_file,
                              color: FileSystemEntity.isDirectorySync(file.path)
                                ? Colors.amber
                                : Colors.blue,
                            ),
                            title: Text(path.basename(file.path)),
                          );
                        },
                      ),
                    ),
            ], icon: Icons.folder),

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

                  // Automatically download files in idle state, but do not overwrite existing files
                  for (var file in receivedFiles) {
                    if (file.state == ReceivableFileState.idle) {
                      String downloadPath = selectedDirectory ?? '';
                      String targetFolder;
                      if (downloadPath.isEmpty) {
                        getApplicationDocumentsDirectory().then((downloadsDir) {
                          targetFolder = path.join(downloadsDir.path, 'folder_sync_downloads');
                          final targetFile = File(path.join(targetFolder, file.info.name));
                          targetFile.exists().then((exists) {
                            if (!exists) {
                              p2pInterface.downloadFile(file.info.id, targetFolder).then((downloaded) async {
                                if (downloaded && selectedDirectory != null) {
                                  final dir = Directory(selectedDirectory!);
                                  final files = await dir.list().toList();
                                  setState(() {
                                    folderFiles = files;
                                  });
                                }
                              });
                            }
                          });
                        });
                      } else {
                        targetFolder = downloadPath;
                        final targetFile = File(path.join(targetFolder, file.info.name));
                        targetFile.exists().then((exists) {
                          if (!exists) {
                            p2pInterface.downloadFile(file.info.id, targetFolder).then((downloaded) async {
                              if (downloaded && selectedDirectory != null) {
                                final dir = Directory(selectedDirectory!);
                                final files = await dir.list().toList();
                                setState(() {
                                  folderFiles = files;
                                });
                              }
                            });
                          }
                        });
                      }
                    }
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
                            trailing: file.state == ReceivableFileState.completed
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.blue),
                                      onPressed: () async {
                                        await _viewDownloadedFile(file);
                                      },
                                      tooltip: 'View File',
                                    ),
                                    Icon(Icons.check_circle, color: Colors.green.shade600),
                                  ],
                                )
                              : (file.state == ReceivableFileState.downloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : null),
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

  // ...existing code...

  Future<void> _viewDownloadedFile(ReceivableFileInfo file) async {
    try {
      String folderPath;
      if (selectedDirectory != null) {
        folderPath = selectedDirectory!;
      } else {
        final downloadsDir = await getApplicationDocumentsDirectory();
        folderPath = path.join(downloadsDir.path, 'folder_sync_downloads');
      }
      final filePath = path.join(folderPath, file.info.name);
      final downloadedFile = File(filePath);
      if (await downloadedFile.exists()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FileViewerScreen(
              file: downloadedFile,
              fileName: file.info.name,
            ),
          ),
        );
      } else {
        _showSnackBar("File not found. Please download it first.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error opening file: $e", Colors.red);
    }
  }

  Future<void> _pickFolder() async {
    try {
      // Request storage permission
      if (!await Permission.storage.request().isGranted) {
        _showSnackBar('Storage permission denied', Colors.red);
        return;
      }
      if (Platform.isAndroid && (await Permission.manageExternalStorage.status).isDenied) {
        await Permission.manageExternalStorage.request();
      }
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        final dir = Directory(directoryPath);
        final files = await dir.list().toList();
        setState(() {
          selectedDirectory = directoryPath;
          folderFiles = files;
        });
        _showSnackBar('Selected folder: $directoryPath', Colors.blue);
      } else {
        _showSnackBar('Folder selection cancelled', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error picking folder: $e', Colors.red);
    }
  }

  Future<void> _syncFolderWithPeers() async {
    if (selectedDirectory == null) {
      _showSnackBar('No folder selected to sync', Colors.red);
      return;
    }
    if (!p2pInterface.isGroupCreated) {
      _showSnackBar('Group not created', Colors.red);
      return;
    }
    try {
      final myFiles = folderFiles
          .where((f) => FileSystemEntity.isFileSync(f.path))
          .map((f) => path.basename(f.path))
          .toList();
      // Send host file list to peers
      await p2pInterface.broadcastText('SYNC_FILE_LIST:' + myFiles.join('|'));
      _showSnackBar('Sync request sent to peers', Colors.blue);

      // Always attempt bidirectional sync if peer file list is available
      if (lastPeerFileList.isNotEmpty) {
        // Find files peer is missing
        final missingForPeer = myFiles.where((f) => !lastPeerFileList.contains(f));
        for (final fileName in missingForPeer) {
          FileSystemEntity? fileToSend;
          try {
            fileToSend = folderFiles.firstWhere(
              (f) => path.basename(f.path) == fileName,
            );
          } catch (_) {
            fileToSend = null;
          }
          if (fileToSend != null && FileSystemEntity.isFileSync(fileToSend.path)) {
            await p2pInterface.broadcastFile(File(fileToSend.path));
            _showSnackBar('Sent missing file to peer: $fileName', Colors.blue);
          }
        }
        // Find files host is missing
        final missingForHost = lastPeerFileList.where((f) => !myFiles.contains(f));
        // Actively download missing files from peer
        for (final fileName in missingForHost) {
          _showSnackBar('Downloading missing file from peer: $fileName', Colors.orange);
          // Attempt to download file (if API supports by name)
          try {
            final downloadsDir = await getApplicationDocumentsDirectory();
            final syncDownloadsPath = path.join(downloadsDir.path, 'folder_sync_downloads');
            // You may need to map fileName to fileId if needed
            var downloaded = await p2pInterface.downloadFile(
              fileName,
              syncDownloadsPath,
            );
            _showSnackBar("${fileName} download: ${downloaded ? 'Success' : 'Failed'}", downloaded ? Colors.green : Colors.red);
            if (downloaded && selectedDirectory != null) {
              final dir = Directory(selectedDirectory!);
              final files = await dir.list().toList();
              setState(() {
                folderFiles = files;
              });
            }
          } catch (e) {
            _showSnackBar("Download failed for $fileName: $e", Colors.red);
          }
        }
      } else {
        // If no peer file list yet, wait for peer to respond and sync will happen via listener
        debugPrint('[Sync] No peer file list yet, waiting for peer response...');
      }
    } catch (e) {
      _showSnackBar('Sync error: $e', Colors.red);
    }
  }
}
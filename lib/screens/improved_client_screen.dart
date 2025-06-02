import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'files_library_screen.dart';
import 'file_viewer_screen.dart';

class ImprovedClientScreen extends StatefulWidget {
  const ImprovedClientScreen({super.key});

  @override
  State<ImprovedClientScreen> createState() => _ImprovedClientScreenState();
}

class _ImprovedClientScreenState extends State<ImprovedClientScreen> {
  final TextEditingController textEditingController = TextEditingController();
  late FlutterP2pClient p2pInterface;

  StreamSubscription<HotspotClientState>? hotspotStateStream;
  StreamSubscription<String>? receivedTextStream;

  HotspotClientState? hotspotState;
  List<BleDiscoveredDevice> discoveredDevices = [];
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    p2pInterface = FlutterP2pClient();
    _initializeP2P();
  }

  void _initializeP2P() async {
    try {
      await p2pInterface.initialize();
      
      hotspotStateStream = p2pInterface.streamHotspotState().listen((state) {
        setState(() {
          hotspotState = state;
        });
        if (state.isActive) {
          _showSnackBar('Connected to host: ${state.hostSsid ?? "Unknown"}', Colors.green);
        } else {
          _showSnackBar('Disconnected from host', Colors.orange);
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
                                    "Required for connecting to hosts",
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

  void _startPeerDiscovery() async {
    if (_isDiscovering) {
      _showSnackBar('Already discovering peers', Colors.orange);
      return;
    }
    
    setState(() {
      _isDiscovering = true;
      discoveredDevices.clear();
    });
    
    _showSnackBar('Starting peer discovery...', Colors.blue);
    
    try {
      await p2pInterface.startScan(
        (devices) {
          setState(() {
            discoveredDevices = devices;
          });
        },
        onDone: () {
          setState(() {
            _isDiscovering = false;
          });
          _showSnackBar('Peer discovery finished. Found ${discoveredDevices.length} hosts', Colors.green);
        },
        onError: (error) {
          setState(() {
            _isDiscovering = false;
          });
          _showSnackBar('Peer discovery error: $error', Colors.red);
        },
      );
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _showSnackBar('Failed to start peer discovery: $e', Colors.red);
    }
  }

  void _connectWithDevice(BleDiscoveredDevice device) async {
    _showSnackBar('Connecting to ${device.deviceName}...', Colors.blue);
    
    try {
      await p2pInterface.connectWithDevice(device);
      _showSnackBar('Connected to ${device.deviceName}', Colors.green);
      setState(() {
        discoveredDevices.clear();
        _isDiscovering = false;
      });
    } catch (e) {
      _showSnackBar('Failed to connect: $e', Colors.red);
    }
  }

  void _connectWithCredentials(String ssid, String preSharedKey) async {
    _showSnackBar('Connecting with credentials...', Colors.blue);
    
    try {
      await p2pInterface.connectWithCredentials(ssid, preSharedKey);
      _showSnackBar("Connected to $ssid", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to connect: $e", Colors.red);
    }
  }

  void _disconnect() async {
    _showSnackBar('Disconnecting...', Colors.orange);
    
    try {
      await p2pInterface.disconnect();
      _showSnackBar("Disconnected successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Disconnect error: $e", Colors.red);
    }
    setState(() {});
  }

  void _sendMessage() async {
    var text = textEditingController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Enter a message to send', Colors.orange);
      return;
    }
    if (!(hotspotState?.isActive == true)) {
      _showSnackBar('Not connected to any host', Colors.red);
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
    if (!(hotspotState?.isActive == true)) {
      _showSnackBar('Not connected to any host', Colors.red);
      return;
    }
    
    try {
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

  void _showQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScanned: _connectWithCredentials,
        ),
      ),
    );
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
    bool isConnected = hotspotState?.isActive == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerSync - Client'),
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
            // Connection Status Section
            _buildSection("Connection Status", [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isConnected ? Colors.green.shade200 : Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected
                              ? "Connected to: ${hotspotState?.hostSsid ?? 'Unknown'}"
                              : "Not Connected",
                          style: TextStyle(
                            color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 8),
                      if (hotspotState?.hostGatewayIpAddress != null)
                        Text("Host IP: ${hotspotState!.hostGatewayIpAddress!}", style: const TextStyle(fontFamily: 'monospace')),
                      if (hotspotState?.hostIpAddress != null)
                        Text("My IP: ${hotspotState!.hostIpAddress!}", style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            ], icon: Icons.signal_wifi_4_bar),

            // Connect to Host Section
            _buildSection("Connect to Host", [
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ElevatedButton.icon(
                    icon: _isDiscovering
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_isDiscovering
                        ? "Discovering... (${discoveredDevices.length})"
                        : "Discover Hosts"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: !isConnected && !_isDiscovering ? _startPeerDiscovery : null,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan QR Code"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: !isConnected ? _showQRScanner : null,
                  ),
                  if (isConnected)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link_off),
                      label: const Text("Disconnect"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: _disconnect,
                    ),
                ],
              ),
            ], icon: Icons.wifi_find),

            // Discovered Hosts Section
            if (discoveredDevices.isNotEmpty && !isConnected)
              _buildSection("Discovered Hosts", [
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: discoveredDevices.length,
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.computer, color: Colors.blue.shade700),
                        ),
                        title: Text(discoveredDevices[index].deviceName),
                        subtitle: Text(discoveredDevices[index].deviceAddress),
                        trailing: ElevatedButton(
                          onPressed: () => _connectWithDevice(discoveredDevices[index]),
                          child: const Text("Connect"),
                        ),
                      ),
                    ),
                  ),
                ),
              ], icon: Icons.devices),

            // Participants Section
            _buildSection("Participants", [
              StreamBuilder<List<P2pClientInfo>>(
                stream: p2pInterface.streamClientList(),
                builder: (context, snapshot) {
                  var clientList = snapshot.data ?? [];
                  if (clientList.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text("No other participants yet", style: TextStyle(color: Colors.grey.shade600)),
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
                            backgroundColor: clientList[index].isHost ? Colors.green.shade100 : Colors.blue.shade100,
                            child: Icon(
                              clientList[index].isHost ? Icons.computer : Icons.person,
                              color: clientList[index].isHost ? Colors.green.shade700 : Colors.blue.shade700,
                            ),
                          ),
                          title: Text(clientList[index].username),
                          subtitle: Text('Role: ${clientList[index].isHost ? "Host" : "Client"}'),
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
                  hintText: 'Enter message to send...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                enabled: isConnected,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Send Message'),
                  onPressed: isConnected ? _sendMessage : null,
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
                  onPressed: isConnected ? _sendFile : null,
                ),
              ),
            ], icon: Icons.folder_shared),

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

            // Sent Files Status Section
            _buildSection("Sent Files Status", [
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
                          Text("No files sent yet", style: TextStyle(color: Colors.grey.shade600)),
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
                                    receiverInfo = p2pInterface.clientList.firstWhere((c) => c.id == id);
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
              // Get app's downloads directory
              final downloadsDir = await getApplicationDocumentsDirectory();
              final syncDownloadsPath = path.join(downloadsDir.path, 'folder_sync_downloads');
              
              var downloaded = await p2pInterface.downloadFile(
                file.info.id,
                syncDownloadsPath,
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
        return Row(
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
        );
      default:
        return Icon(Icons.error, color: Colors.red.shade600);
    }
  }

  Future<void> _viewDownloadedFile(ReceivableFileInfo file) async {
    try {
      final downloadsDir = await getApplicationDocumentsDirectory();
      final syncDownloadsPath = path.join(downloadsDir.path, 'folder_sync_downloads');
      final filePath = path.join(syncDownloadsPath, file.info.name);
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
}

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final Function(String ssid, String password) onScanned;

  const QRScannerScreen({super.key, required this.onScanned});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Point camera at QR code to connect',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Expected format: SSID|PASSWORD',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        final parts = scanData.code!.split('|');
        if (parts.length == 2) {
          controller.pauseCamera();
          widget.onScanned(parts[0], parts[1]);
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code format. Expected: SSID|PASSWORD'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
} 
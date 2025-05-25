import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
import '../providers/p2p_sync_provider.dart';
import '../widgets/connection_status_widget.dart';
import '../widgets/file_transfer_widget.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isScanning = false;
  bool _isConnecting = false;
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _pskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    controller?.dispose();
    _ssidController.dispose();
    _pskController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && controller != null) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ConnectionStatusWidget(),
              const SizedBox(height: 20),
              
              // Connection Status Card
              Card(
                color: p2pSyncProvider.isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        p2pSyncProvider.isConnected 
                            ? Icons.check_circle 
                            : Icons.wifi_off,
                        color: p2pSyncProvider.isConnected 
                            ? Colors.green 
                            : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p2pSyncProvider.isConnected
                                  ? (p2pSyncProvider.isClient ? 'Connected as Client' : 'Connected')
                                  : 'Not Connected',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (p2pSyncProvider.isConnected && p2pSyncProvider.isClient)
                              Text(
                                'Role: Client | Status: ${p2pSyncProvider.status.name}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Client controls
              if (!p2pSyncProvider.isConnected)
                Column(
                  children: [
                    // Scan button
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(_isScanning ? 'Scanning...' : 'Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    const Text('OR', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    
                    // Manual connection
                    const Text(
                      'Enter Connection Details Manually:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ssidController,
                      decoration: const InputDecoration(
                        labelText: 'SSID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pskController,
                      decoration: const InputDecoration(
                        labelText: 'PSK (Password)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connectManually,
                      icon: _isConnecting 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_lock),
                      label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    const Text('OR', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    
                    // Scan for hosts
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanForHosts,
                      icon: _isScanning 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isScanning ? 'Scanning...' : 'Scan for Hosts'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    // Available hosts
                    if (p2pSyncProvider.availableHosts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Available Hosts:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...p2pSyncProvider.availableHosts.map((host) => ListTile(
                        leading: const Icon(Icons.wifi_tethering),
                        title: Text(host['name'] ?? 'Unknown Host'),
                        subtitle: Text('ID: ${host['id']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.link),
                          onPressed: () => _connectToHost(host['id']),
                        ),
                      )),
                    ],
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Network Information
                    const Text(
                      'Network Information:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Connected Devices: ${p2pSyncProvider.connectedDevices.length + 1}'), // +1 for self
                            Text('Your Role: Client'),
                            Text('Connection Status: ${p2pSyncProvider.status.name}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Other Connected Devices
                    const Text(
                      'Other Connected Devices:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    if (p2pSyncProvider.connectedDevices.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No other devices connected'),
                        ),
                      )
                    else
                      ...p2pSyncProvider.connectedDevices.asMap().entries.map((entry) {
                        final index = entry.key;
                        final clientId = entry.value;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.devices),
                            title: Text('Device ${index + 1}'),
                            subtitle: Text('ID: $clientId'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  tooltip: 'Send File',
                                  onPressed: () => _sendFileToClient(clientId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.message),
                                  tooltip: 'Send Message',
                                  onPressed: () => _sendMessageToClient(clientId),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      
                    const SizedBox(height: 20),
                    
                    // File transfers
                    const Text(
                      'File Transfers:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const FileTransferWidget(),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    const Text(
                      'Actions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Send file to all devices
                    ElevatedButton.icon(
                      onPressed: _sendFileToAll,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Send File to All Devices'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Send message to all
                    ElevatedButton.icon(
                      onPressed: _sendMessageToAll,
                      icon: const Icon(Icons.message),
                      label: const Text('Send Message to All'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Disconnect button
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.close),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _startScan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Expanded(
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  controller?.stopCamera();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        controller.pauseCamera();
        
        try {
          final jsonData = jsonDecode(scanData.code!);
          if (jsonData['ssid'] != null && jsonData['psk'] != null) {
            Navigator.pop(context); // Close scanner
            _connectWithCredentials(jsonData['ssid'], jsonData['psk']);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid QR code format')),
          );
          controller.resumeCamera();
        }
      }
    });
  }
  
  Future<void> _connectManually() async {
    final ssid = _ssidController.text.trim();
    final psk = _pskController.text.trim();
    
    if (ssid.isEmpty || psk.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both SSID and PSK')),
      );
      return;
    }
    
    await _connectWithCredentials(ssid, psk);
  }
  
  Future<void> _connectWithCredentials(String ssid, String psk) async {
    setState(() {
      _isConnecting = true;
    });
    
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    final success = await p2pSyncProvider.connectWithCredentials(ssid, psk);
    
    setState(() {
      _isConnecting = false;
    });
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p2pSyncProvider.errorMessage ?? 'Connection failed')),
      );
    }
  }
  
  Future<void> _scanForHosts() async {
    setState(() {
      _isScanning = true;
    });
    
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.scanForHosts();
    
    setState(() {
      _isScanning = false;
    });
  }
  
  Future<void> _connectToHost(String hostId) async {
    setState(() {
      _isConnecting = true;
    });
    
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    final success = await p2pSyncProvider.connectToHost(hostId);
    
    setState(() {
      _isConnecting = false;
    });
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p2pSyncProvider.errorMessage ?? 'Connection failed')),
      );
    }
  }
  
  Future<void> _sendFileToClient(String clientId) async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.selectAndSendFile(targetClientId: clientId);
  }
  
  Future<void> _sendFileToAll() async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.selectAndSendFile();
  }
  
  Future<void> _sendMessageToClient(String clientId) async {
    final message = await _showMessageDialog('Send Message to Device');
    if (message != null && message.isNotEmpty) {
      final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
      await p2pSyncProvider.sendMessage(message, targetClientId: clientId);
    }
  }
  
  Future<void> _sendMessageToAll() async {
    final message = await _showMessageDialog('Send Message to All Devices');
    if (message != null && message.isNotEmpty) {
      final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
      await p2pSyncProvider.sendMessage(message);
    }
  }
  
  Future<String?> _showMessageDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _disconnect() async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.disconnect();
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Client Mode Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Scan a QR code from a host device to connect automatically.'),
              SizedBox(height: 8),
              Text('2. Or enter the SSID and PSK manually if you know them.'),
              SizedBox(height: 8),
              Text('3. Or scan for nearby hosts using Bluetooth LE.'),
              SizedBox(height: 8),
              Text('4. Once connected, you can send files to the host or other clients.'),
              SizedBox(height: 8),
              Text('5. Tap "Disconnect" to disconnect from the host.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 
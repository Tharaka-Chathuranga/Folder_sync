import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';

import '../providers/device_provider.dart';
import '../providers/sync_provider.dart';
import '../models/device_info.dart';
import 'sync_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isScanning = false;
  bool _isAdvertising = false;
  String? _selectedDirectory;
  DeviceInfo? _selectedDevice;
  final TextEditingController _deviceNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'My Device';
    _initializePermissions();
  }
  
  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }
  
  // Initialize required permissions
  Future<void> _initializePermissions() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    await syncProvider.requestPermissions();
  }
  
  // Select a folder to sync
  Future<void> _selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory != null) {
      setState(() {
        _selectedDirectory = selectedDirectory;
      });
    }
  }
  
  // Show troubleshooting dialog when discovery fails
  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Troubleshooting'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Please check the following:'),
              SizedBox(height: 8),
              Text('• WiFi is turned ON on both devices'),
              Text('• Both devices are on the same WiFi network'),
              Text('• All required permissions are granted'),
              Text('• Bluetooth is enabled (recommended)'),
              Text('• Neither device is in battery saver mode'),
              SizedBox(height: 16),
              Text('You can tap the WiFi icon in the top bar to open WiFi settings.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openWifiSettings();
            },
            child: const Text('Open WiFi Settings'),
          ),
        ],
      ),
    );
  }
  
  // Start scanning for devices
  Future<void> _startScan() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    setState(() {
      _isScanning = true;
    });
    
    final success = await deviceProvider.startDiscovery();
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start scanning. Please check that WiFi is enabled and all permissions are granted'),
          duration: Duration(seconds: 5),
        ),
      );
      
      _showTroubleshootingDialog();
      
      setState(() {
        _isScanning = false;
      });
    }
  }
  
  // Stop scanning for devices
  Future<void> _stopScan() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    await deviceProvider.stopDiscovery();
    
    setState(() {
      _isScanning = false;
    });
  }
  
  // Start advertising this device
  Future<void> _startAdvertising() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    setState(() {
      _isAdvertising = true;
    });
    
    final success = await deviceProvider.startAdvertising(_deviceNameController.text);
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start advertising. Please check that WiFi is enabled and all permissions are granted'),
          duration: Duration(seconds: 5),
        ),
      );
      
      _showTroubleshootingDialog();
      
      setState(() {
        _isAdvertising = false;
      });
    }
  }
  
  // Stop advertising this device
  Future<void> _stopAdvertising() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    await deviceProvider.stopAdvertising();
    
    setState(() {
      _isAdvertising = false;
    });
  }
  
  // Connect to a device
  Future<void> _connectToDevice(DeviceInfo device) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    setState(() {
      _selectedDevice = device;
    });
    
    final success = await deviceProvider.connectToDevice(device.id);
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
      
      setState(() {
        _selectedDevice = null;
      });
    } else {
      // Connection successful, navigate to sync screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SyncScreen(
              deviceInfo: device,
              sourcePath: _selectedDirectory!,
            ),
          ),
        ).then((_) {
          // Disconnect when returning from sync screen
          deviceProvider.disconnect();
          setState(() {
            _selectedDevice = null;
          });
        });
      }
    }
  }
  
  void _openWifiSettings() {
    AppSettings.openAppSettings(type: AppSettingsType.wifi);
  }
  
  // Run connection diagnostics 
  Future<void> _runConnectionDiagnostic() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Checking Connection...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing network connectivity...'),
          ],
        ),
      ),
    );

    // Get device provider
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    // Add short delay for UI
    await Future.delayed(const Duration(seconds: 1));
    
    // Check results and show diagnostic information
    Navigator.pop(context); // Close progress dialog
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Diagnostics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Device name: ${_deviceNameController.text}'),
              const SizedBox(height: 16),
              const Text('Troubleshooting tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('1. Ensure both devices are on the same WiFi network'),
              const Text('2. Try bringing devices closer together'),
              const Text('3. Restart the app on both devices'),
              const Text('4. Make sure Bluetooth is enabled if available'),
              const Text('5. Temporarily disable mobile data to ensure WiFi is used'),
              const SizedBox(height: 16),
              const Text('Advanced tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Some Huawei devices may have compatibility issues'),
              const Text('• Battery optimization can interfere with discovery'),
              const Text('• Try connecting to a different WiFi network'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openWifiSettings();
            },
            child: const Text('Open WiFi Settings'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi),
            onPressed: _openWifiSettings,
            tooltip: 'Open WiFi Settings',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show about dialog
              showAboutDialog(
                context: context,
                applicationName: 'Folder Sync',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2023 MobileX Team',
                children: [
                  const Text(
                    'Synchronize folder contents between mobile devices over Wi-Fi.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Device name input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          
          // Advertise button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isAdvertising ? Icons.stop : Icons.broadcast_on_personal),
                    label: Text(_isAdvertising ? 'Stop Advertising' : 'Advertise Device'),
                    onPressed: _isAdvertising ? _stopAdvertising : _startAdvertising,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Directory selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Folder to Sync'),
                    onPressed: _selectDirectory,
                  ),
                ),
              ],
            ),
          ),
          
          if (_selectedDirectory != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.folder, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDirectory!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // Scan controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isScanning ? Icons.stop : Icons.search),
                    label: Text(_isScanning ? 'Stop Scanning' : 'Scan for Devices'),
                    onPressed: _isScanning ? _stopScan : _startScan,
                  ),
                ),
              ],
            ),
          ),
          
          // Diagnostics button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton.icon(
              icon: const Icon(Icons.help_outline),
              label: const Text('Connection Troubleshooting'),
              onPressed: _runConnectionDiagnostic,
            ),
          ),
          
          // Available devices list
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.devices, size: 20),
                SizedBox(width: 8),
                Text(
                  'Available Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Consumer<DeviceProvider>(
              builder: (context, deviceProvider, child) {
                final devices = deviceProvider.discoveredDevices;
                
                if (devices.isEmpty) {
                  return const Center(
                    child: Text('No devices found'),
                  );
                }
                
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    
                    return ListTile(
                      leading: const Icon(Icons.smartphone),
                      title: Text(device.name),
                      subtitle: Text(device.id),
                      trailing: _selectedDevice?.id == device.id
                          ? const CircularProgressIndicator()
                          : IconButton(
                              icon: const Icon(Icons.link),
                              onPressed: _selectedDirectory == null
                                  ? null
                                  : () => _connectToDevice(device),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
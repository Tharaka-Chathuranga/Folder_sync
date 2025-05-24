import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/wifi_direct_provider.dart';
import '../services/wifi_direct_service.dart';
import 'file_transfer_screen.dart';

class WifiDirectScreen extends StatefulWidget {
  const WifiDirectScreen({super.key});

  @override
  State<WifiDirectScreen> createState() => _WifiDirectScreenState();
}

class _WifiDirectScreenState extends State<WifiDirectScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  bool _isWifiEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'My Device';
    _initializeWifiDirect();
  }

  Future<void> _initializeWifiDirect() async {
    final provider = Provider.of<WifiDirectProvider>(context, listen: false);
    final permissionsGranted = await provider.requestPermissions();
    
    if (!permissionsGranted) {
      setState(() {
        _errorMessage = 'Required permissions not granted. Please grant all permissions.';
      });
    }
    
    // Get device name
    final deviceName = await provider.getDeviceName();
    if (deviceName != null) {
      _deviceNameController.text = deviceName;
    }
    
    // Listen for Wi-Fi state changes
    provider.wifiStateStream.listen((isEnabled) {
      if (mounted) {
        setState(() {
          _isWifiEnabled = isEnabled;
          if (!isEnabled) {
            _errorMessage = 'Wi-Fi is not enabled. Please enable Wi-Fi.';
          } else {
            _errorMessage = null;
          }
        });
      }
    });
  }

  void _openWifiSettings() {
    AppSettings.openAppSettings(type: AppSettingsType.wifi);
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Direct'),
        actions: [
          IconButton(
            icon: Icon(_isWifiEnabled ? Icons.wifi : Icons.wifi_off),
            onPressed: _openWifiSettings,
          ),
        ],
      ),
      body: Consumer<WifiDirectProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: _openWifiSettings,
                        tooltip: 'Open Settings',
                      ),
                    ],
                  ),
                ),
              
              _buildDeviceNameSection(provider),
              _buildActionButtons(provider),
              _buildDeviceList(provider),
              _buildConnectionInfo(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceNameSection(WifiDirectProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _deviceNameController,
        decoration: const InputDecoration(
          labelText: 'Device Name',
          border: OutlineInputBorder(),
        ),
        readOnly: true, // Device name is read-only in this implementation
      ),
    );
  }

  Widget _buildActionButtons(WifiDirectProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: Text(provider.isScanning ? 'Stop Scanning' : 'Scan for Devices'),
            onPressed: () async {
              if (provider.isScanning) {
                await provider.stopDiscovery();
              } else {
                setState(() {
                  _errorMessage = null; // Clear previous errors
                });
                
                final success = await provider.startDiscovery();
                
                if (!success && mounted) {
                  setState(() {
                    _errorMessage = 'Failed to discover devices. Make sure Wi-Fi is enabled and permissions are granted.';
                  });
                }
              }
            },
          ),
          if (provider.connectionInfo?.isConnected == true)
            ElevatedButton.icon(
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
              onPressed: () {
                provider.disconnect();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(WifiDirectProvider provider) {
    final devices = provider.discoveredDevices;
    
    if (provider.isScanning && devices.isEmpty) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning for devices...'),
            ],
          ),
        ),
      );
    }
    
    if (devices.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('No devices found. Tap Scan to discover devices.'),
        ),
      );
    }
    
    return Expanded(
      child: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final isSelected = device.address == provider.selectedDeviceAddress;
          final isConnecting = isSelected && provider.isConnecting;
          
          return ListTile(
            title: Text(device.name),
            subtitle: Text('Status: ${device.statusString}'),
            trailing: isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Colors.green : null,
                  ),
            onTap: () {
              if (!isSelected && device.isAvailable) {
                provider.connectToDevice(device.address);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildConnectionInfo(WifiDirectProvider provider) {
    final connectionInfo = provider.connectionInfo;
    
    if (connectionInfo == null || !connectionInfo.isConnected) {
      return const SizedBox.shrink();
    }
    
    final selectedDevice = provider.getSelectedDevice();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.green.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connected to: ${selectedDevice?.name ?? "Unknown Device"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Role: ${connectionInfo.isGroupOwner ? "Group Owner" : "Client"}'),
          if (connectionInfo.groupOwnerAddress != null)
            Text('Address: ${connectionInfo.groupOwnerAddress}'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (selectedDevice != null) {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => FileTransferScreen(
                      connectedDevice: selectedDevice,
                    ),
                  ),
                );
              }
            },
            child: const Text('Start File Transfer'),
          ),
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import '../providers/device_provider.dart';
import '../providers/sync_provider.dart';
import '../models/device_info.dart';
import 'sync_screen.dart';
import 'wifi_direct_screen.dart';
import '../providers/p2p_sync_provider.dart';
import 'host_screen.dart';
import 'client_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check critical permissions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCriticalPermissions(context);
    });
    
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Sync'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Info',
            onPressed: () => _showDebugDialog(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Folder Sync',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sync files between devices using Wi-Fi Direct',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 50),
              _buildConnectionOption(
                context,
                'Start as Host',
                'Create a Wi-Fi Direct group and allow other devices to connect',
                Icons.wifi_tethering,
                Colors.blue,
                () async {
                  if (context.mounted) {
                    await _startAsHost(context, p2pSyncProvider);
                  }
                },
              ),
              const SizedBox(height: 20),
              _buildConnectionOption(
                context,
                'Connect as Client',
                'Scan for and connect to a host device',
                Icons.wifi_find,
                Colors.green,
                () async {
                  await p2pSyncProvider.initialize();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ClientScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildConnectionOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAsHost(BuildContext context, P2PSyncProvider p2pSyncProvider) async {
    try {
      // Step 1: Check if location services are enabled
      final locationServiceStatus = await Permission.location.serviceStatus;
      if (!locationServiceStatus.isEnabled) {
        if (context.mounted) {
          _showLocationRequiredDialog(context);
        }
        return;
      }

      // Step 2: Request location permission
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Location permission is required for Wi-Fi Direct');
        }
        return;
      }

      // Step 3: Request nearby WiFi devices permission (Android 13+)
      final nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
      if (nearbyWifiStatus.isDenied && nearbyWifiStatus != PermissionStatus.denied) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Nearby WiFi devices permission is required for Android 13+');
        }
        return;
      }

      // Step 4: Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Starting hotspot...'),
              ],
            ),
          ),
        );
      }

      // Step 5: Initialize P2P service and start as host
      await p2pSyncProvider.initialize();
      final ok = await p2pSyncProvider.startAsHost();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (ok) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HostScreen()),
          );
        }
      } else {
        if (context.mounted) {
          _showHostFailedDialog(context);
        }
      }
    } catch (e) {
      // Close loading dialog if it's showing
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        
        _showHostFailedDialog(context, error: e.toString());
      }
    }
  }

  void _showLocationRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text(
          'Wi-Fi Direct requires location services to be enabled. Please enable location services in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppSettings.openAppSettings(type: AppSettingsType.location);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showHostFailedDialog(BuildContext context, {String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Failed to Start Hotspot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not start the Wi-Fi Direct hotspot. This might be due to:'),
            const SizedBox(height: 10),
            const Text('• Another hotspot is already running'),
            const Text('• Wi-Fi Direct is not supported on this device'),
            const Text('• System restrictions on hotspot creation'),
            const Text('• Network hardware is busy'),
            if (error != null) ...[
              const SizedBox(height: 10),
              const Text('Technical details:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(error, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
            const SizedBox(height: 10),
            const Text('Try:'),
            const Text('• Turning off any existing hotspot or VPN'),
            const Text('• Restarting Wi-Fi on your device'),
            const Text('• Closing and reopening the app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WiFi Direct Debug Info'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Use this to diagnose WiFi Direct issues:'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _runDiagnostics(context),
                  child: const Text('Run Full Diagnostics'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _checkPermissions(context),
                  child: const Text('Check Permissions'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _checkWiFiStatus(context),
                  child: const Text('Check WiFi Status'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _checkBluetoothStatus(context),
                  child: const Text('Check Bluetooth Status'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _fixCommonIssues(context),
                  child: const Text('Fix Common Issues'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('1. Run diagnostics to see detailed logs'),
                const Text('2. Check your device\'s debug console'),
                const Text('3. Look for error messages starting with ==='),
                const Text('4. Share the log output for support'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostics(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Running diagnostics...'),
            ],
          ),
        ),
      );

      final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
      
      debugPrint('=== STARTING FULL DIAGNOSTICS ===');
      debugPrint('Timestamp: ${DateTime.now()}');
      
      // Initialize P2P service to run diagnostics
      await p2pSyncProvider.initialize();
      
      // This will trigger all the detailed logging we added
      debugPrint('=== DIAGNOSTIC: Attempting to start as host (will fail, but logs are useful) ===');
      await p2pSyncProvider.startAsHost();
      
      // Stop the host attempt
      await p2pSyncProvider.disconnect();
      
      debugPrint('=== DIAGNOSTICS COMPLETED ===');
      debugPrint('Check the debug console for detailed information');

      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics completed. Check debug console for details.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      debugPrint('Error running diagnostics: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnostics error: $e')),
      );
    }
  }

  Future<void> _checkPermissions(BuildContext context) async {
    try {
      debugPrint('=== MANUAL PERMISSION CHECK ===');
      
      final statuses = await [
        Permission.location,
        Permission.storage,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ].request();
      
      debugPrint('Permission check completed - see debug console');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission check completed')),
      );
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission check error: $e')),
      );
    }
  }

  Future<void> _checkWiFiStatus(BuildContext context) async {
    try {
      debugPrint('=== MANUAL WIFI STATUS CHECK ===');
      
      final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
      final wifiStatus = await p2pSyncProvider.getWiFiStatus();
      
      debugPrint('WiFi status: $wifiStatus');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi status check completed')),
      );
    } catch (e) {
      debugPrint('Error checking WiFi status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi status error: $e')),
      );
    }
  }

  Future<void> _checkBluetoothStatus(BuildContext context) async {
    try {
      debugPrint('=== MANUAL BLUETOOTH STATUS CHECK ===');
      
      final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
      final bluetoothStatus = await p2pSyncProvider.getBluetoothStatus();
      
      debugPrint('Bluetooth status: $bluetoothStatus');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth status check completed')),
      );
    } catch (e) {
      debugPrint('Error checking Bluetooth status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth status error: $e')),
      );
    }
  }

  Future<void> _fixCommonIssues(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Common WiFi Direct Issues'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Based on your logs, here are the issues found:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                const Text('❌ Missing "Nearby WiFi Devices" permission'),
                const Text('⚠️ Bluetooth may be disabled'),
                const Text('⚠️ WiFi Direct host IP issues'),
                
                const SizedBox(height: 16),
                const Text(
                  'Solutions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _requestNearbyWifiPermission(context);
                  },
                  child: const Text('1. Fix Nearby WiFi Permission'),
                ),
                
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showBluetoothFixDialog(context);
                  },
                  child: const Text('2. Fix Bluetooth Issues'),
                ),
                
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('3. Open App Settings'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBluetoothFixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Bluetooth Issues'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WiFi Direct discovery requires Bluetooth to be enabled:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Manual steps:'),
            SizedBox(height: 8),
            Text('1. Open your device Settings'),
            Text('2. Go to Bluetooth settings'),
            Text('3. Turn on Bluetooth'),
            Text('4. Return to this app'),
            SizedBox(height: 12),
            Text(
              'Note: You don\'t need to pair devices - just enable Bluetooth.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
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

  void _checkCriticalPermissions(BuildContext context) async {
    try {
      debugPrint('=== CRITICAL PERMISSION CHECK ===');
      
      // Check the critical nearbyWifiDevices permission
      bool nearbyWifiGranted = false;
      PermissionStatus nearbyWifiStatus = PermissionStatus.denied;
      
      try {
        nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
        nearbyWifiGranted = nearbyWifiStatus.isGranted;
        debugPrint('nearbyWifiDevices permission: ${nearbyWifiStatus.name}');
      } catch (e) {
        debugPrint('nearbyWifiDevices permission check failed: $e');
        debugPrint('This is normal on Android versions below 13');
        
        // On older Android versions, check location permission instead
        final locationStatus = await Permission.location.status;
        nearbyWifiGranted = locationStatus.isGranted;
        debugPrint('Using location permission as fallback: ${locationStatus.name}');
      }
      
      if (!nearbyWifiGranted) {
        if (nearbyWifiStatus.isPermanentlyDenied) {
          _showPermissionPermanentlyDeniedDialog(context);
        } else {
          _showNearbyWifiPermissionDialog(context);
        }
      }
      
      // Also check if Bluetooth is enabled
      final bluetoothStatus = await Permission.bluetooth.status;
      debugPrint('Bluetooth permission: ${bluetoothStatus.name}');
      
    } catch (e) {
      debugPrint('Error checking critical permissions: $e');
      // Show a generic permission error dialog
      _showGenericPermissionErrorDialog(context);
    }
  }

  void _showNearbyWifiPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Critical Permission Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WiFi Direct requires the "Nearby WiFi Devices" permission for Android 13+.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('This permission is essential for:'),
            SizedBox(height: 8),
            Text('• Discovering nearby devices'),
            Text('• Creating WiFi Direct connections'),
            Text('• Transferring files between devices'),
            SizedBox(height: 12),
            Text(
              'The app cannot function without this permission.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestNearbyWifiPermission(context);
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The "Nearby WiFi Devices" permission has been permanently denied.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('To enable WiFi Direct functionality:'),
            SizedBox(height: 8),
            Text('1. Go to Settings > Apps > Folder Sync'),
            Text('2. Tap "Permissions"'),
            Text('3. Find "Nearby devices" and enable it'),
            Text('4. Return to this app'),
            SizedBox(height: 12),
            Text(
              'Without this permission, WiFi Direct will not work.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showGenericPermissionErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Error'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'There was an issue checking permissions for this app.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('This might be due to:'),
            SizedBox(height: 8),
            Text('• Android version compatibility'),
            Text('• App configuration issues'),
            Text('• System-level restrictions'),
            SizedBox(height: 12),
            Text(
              'Try granting permissions manually in Settings.',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNearbyWifiPermission(BuildContext context) async {
    try {
      debugPrint('Requesting nearbyWifiDevices permission...');
      
      final status = await Permission.nearbyWifiDevices.request();
      
      debugPrint('nearbyWifiDevices permission result: ${status.name}');
      
      // Check if the widget is still mounted before using context
      if (!context.mounted) return;
      
      if (status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Permission granted! WiFi Direct should now work.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status.isPermanentlyDenied) {
        _showPermissionPermanentlyDeniedDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Permission denied. WiFi Direct may not work properly.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting nearbyWifiDevices permission: $e');
      // Check if mounted before using context
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permission: $e')),
        );
      }
    }
  }
} 
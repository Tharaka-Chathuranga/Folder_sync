import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Sync'),
        centerTitle: true,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClientScreen()),
                  );
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

      // Step 4: Initialize P2P service
      await p2pSyncProvider.initialize();

      // Step 5: Start as host
      final ok = await p2pSyncProvider.startAsHost();
      if (ok) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HostScreen()),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start host. Please check permissions and try again.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting host: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
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
} 
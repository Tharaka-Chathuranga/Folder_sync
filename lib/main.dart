import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/device_info.dart';
import 'providers/device_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/wifi_direct_provider.dart';
import 'screens/home_screen.dart';
import 'screens/wifi_direct_screen.dart';
import 'services/device_discovery_service.dart';
import 'services/file_service.dart';
import 'services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create services
    final fileService = FileService();
    final deviceService = DeviceDiscoveryService();
    final syncService = SyncService(deviceService, fileService);
    
    return MultiProvider(
      providers: [
        // Device provider
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(deviceService),
        ),
        // Sync provider
        ChangeNotifierProvider(
          create: (_) => SyncProvider(syncService, fileService),
        ),
        // Wi-Fi Direct provider
        ChangeNotifierProvider(
          create: (_) => WifiDirectProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Folder Sync',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routes: {
          '/': (context) => const HomeScreen(),
          '/wifi_direct': (context) => const WifiDirectScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}

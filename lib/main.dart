import 'package:flutter/material.dart';
import 'package:folder_sync/screens/demo_home_screen.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'providers/p2p_sync_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => P2PSyncProvider(),
      child: MaterialApp(
        title: 'Folder Sync',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const DemoHomeScreen(),
      ),
    );
  }
}

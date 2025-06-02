import 'package:flutter/material.dart';
import 'improved_host_screen.dart';
import 'improved_client_screen.dart';
import 'files_library_screen.dart';

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Sync - Improved P2P'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Header Section
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_shared,
                          size: 56,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Flutter P2P Connection',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share files directly between devices using Wi-Fi Direct',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // Key Features Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Key Features:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(Icons.wifi_tethering, 'Wi-Fi Direct Hotspot'),
                        _buildFeatureItem(Icons.qr_code, 'QR Code Connection'),
                        _buildFeatureItem(Icons.bluetooth, 'Bluetooth LE Discovery'),
                        _buildFeatureItem(Icons.file_copy, 'Real-time File Transfer'),
                        _buildFeatureItem(Icons.security, 'Built-in Permission Handling'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons Section
                Column(
                  children: [
                    // Host Button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ImprovedHostScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_tethering, size: 28),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'START AS HOST',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Create hotspot & share files',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Client Button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ImprovedClientScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_android, size: 28),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JOIN AS CLIENT',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Connect to host & receive files',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Files Library Button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FilesLibraryScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 28),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FILES LIBRARY',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'View & manage downloaded files',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Info Section
                // Card(
                //   elevation: 2,
                //   color: Colors.orange.shade50,
                //   child: Padding(
                //     padding: const EdgeInsets.all(16.0),
                //     child: Row(
                //       children: [
                //         Icon(Icons.info_outline, color: Colors.orange.shade700),
                //         const SizedBox(width: 12),
                //         Expanded(
                //           child: Text(
                //             'This version uses flutter_p2p_connection plugin directly to avoid permission issues.',
                //             style: TextStyle(
                //               color: Colors.orange.shade700,
                //               fontSize: 14,
                //             ),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                
                // const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
} 
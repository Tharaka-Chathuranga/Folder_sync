import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/p2p_sync_provider.dart';

class HostScreen extends StatelessWidget {
  const HostScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Stop Hosting',
            onPressed: () async {
              final provider = context.read<P2PSyncProvider>();
              await provider.disconnect();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Consumer<P2PSyncProvider>(
        builder: (context, p2p, _) {
          final ssid = p2p.hostSSID ?? 'Unknown';
          final psk = p2p.hostPSK ?? 'Unknown';
          final clients = p2p.connectedDevices;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Hotspot SSID'),
                  subtitle: Text(ssid),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(context, ssid, 'SSID'),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Hotspot Password'),
                  subtitle: Text(psk),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(context, psk, 'Password'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connected Clients',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (clients.isEmpty)
                const Text('No clients connected yet')
              else
                ...clients.map((id) => ListTile(
                      leading: const Icon(Icons.devices),
                      title: Text(id),
                    )),
            ],
          );
        },
      ),
    );
  }
} 
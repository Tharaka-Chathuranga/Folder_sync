import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/p2p_sync_provider.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
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
          final authorizedClients = p2p.connectedDevices; // Only authorized clients
          final allClientsInfo = p2p.getAllClientsInfo(); // All clients with status

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
              Row(
                children: [
                  const Text(
                    'Connected Devices',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text('${authorizedClients.length} authorized'),
                    backgroundColor: Colors.green.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (allClientsInfo.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('No clients connected yet'),
                    subtitle: Text('Share the SSID and password above for clients to connect'),
                    leading: Icon(Icons.info_outline),
                  ),
                )
              else
                ...allClientsInfo.map((clientInfo) => _buildClientTile(clientInfo)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClientTile(Map<String, dynamic> clientInfo) {
    final status = clientInfo['status'] ?? 'unknown';
    final clientId = clientInfo['id'] ?? 'Unknown';
    final appVersion = clientInfo['appVersion'];
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    Widget? trailing;
    
    switch (status) {
      case 'authorized':
        statusColor = Colors.green;
        statusIcon = Icons.verified_user;
        statusText = 'Authorized';
        if (appVersion != null) {
          statusText += ' (v$appVersion)';
        }
        trailing = IconButton(
          icon: const Icon(Icons.send),
          tooltip: 'Send File',
          onPressed: () => _sendFileToClient(clientId),
        );
        break;
      case 'pending_verification':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Verifying app...';
        trailing = IconButton(
          icon: const Icon(Icons.block),
          tooltip: 'Disconnect',
          onPressed: () => _disconnectClient(clientId),
        );
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.block;
        statusText = 'Rejected: ${clientInfo['reason'] ?? 'Unknown app'}';
        trailing = IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Remove',
          onPressed: () => _removeClient(clientId),
        );
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.device_unknown;
        statusText = 'Unknown status';
    }
    
    return Card(
      child: ListTile(
        leading: Icon(
          statusIcon,
          color: statusColor,
        ),
        title: Text(clientId),
        subtitle: Text(statusText),
        trailing: trailing,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _sendFileToClient(String clientId) async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.selectAndSendFile(targetClientId: clientId);
  }

  Future<void> _disconnectClient(String clientId) async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.disconnectClient(clientId);
  }

  Future<void> _removeClient(String clientId) async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    await p2pSyncProvider.removeClient(clientId);
  }
} 
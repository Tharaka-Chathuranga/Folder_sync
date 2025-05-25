import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/p2p_sync_provider.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context);
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (p2pSyncProvider.status) {
      case SyncStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = p2pSyncProvider.isHost 
            ? 'Host Active' 
            : 'Connected to Host';
        break;
      case SyncStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Connecting...';
        break;
      case SyncStatus.scanning:
        statusColor = Colors.blue;
        statusIcon = Icons.search;
        statusText = 'Scanning...';
        break;
      case SyncStatus.sending:
        statusColor = Colors.blue;
        statusIcon = Icons.upload;
        statusText = 'Sending File...';
        break;
      case SyncStatus.receiving:
        statusColor = Colors.blue;
        statusIcon = Icons.download;
        statusText = 'Receiving File...';
        break;
      case SyncStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = p2pSyncProvider.errorMessage ?? 'Error';
        break;
      case SyncStatus.disconnected:
        statusColor = Colors.grey;
        statusIcon = Icons.link_off;
        statusText = 'Disconnected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
        statusText = 'Ready';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 
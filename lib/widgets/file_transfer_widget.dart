import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/p2p_sync_provider.dart';

class FileTransferWidget extends StatelessWidget {
  const FileTransferWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context);
    
    // Display received files
    if (p2pSyncProvider.receivedFiles.isEmpty) {
      return const Center(
        child: Text('No file transfers'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'File Transfers:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: p2pSyncProvider.receivedFiles.length,
          itemBuilder: (context, index) {
            final fileData = p2pSyncProvider.receivedFiles[index];
            final fileId = fileData['fileId'];
            final fileName = fileData['fileName'] ?? 'Unknown file';
            final fileSize = fileData['fileSize'] ?? 0;
            final senderId = fileData['senderId'] ?? 'Unknown';
            final progress = p2pSyncProvider.transferProgress[fileId] ?? 0.0;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatFileSize(fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: $senderId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearPercentIndicator(
                      lineHeight: 10.0,
                      percent: progress,
                      backgroundColor: Colors.grey[300],
                      progressColor: Colors.blue,
                      barRadius: const Radius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (progress < 1.0)
                          TextButton(
                            onPressed: () => _downloadFile(context, fileId, fileName),
                            child: const Text('Download'),
                          )
                        else
                          const Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  Future<void> _downloadFile(BuildContext context, String fileId, String fileName) async {
    final p2pSyncProvider = Provider.of<P2PSyncProvider>(context, listen: false);
    
    try {
      final file = await p2pSyncProvider.downloadFile(fileId);
      
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download $fileName: $e')),
      );
    }
  }
} 
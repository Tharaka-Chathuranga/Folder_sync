import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../models/device_info.dart';
import '../models/file_item.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  final DeviceInfo deviceInfo;
  final String sourcePath;

  const SyncScreen({
    super.key,
    required this.deviceInfo,
    required this.sourcePath,
  });

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isTwoWaySync = false;
  bool _showOnlySelected = false;
  List<FileItem> _files = [];
  bool _filesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // Load files from the selected directory
  Future<void> _loadFiles() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final files = await syncProvider.getFilesInDirectory(widget.sourcePath);

    setState(() {
      _files = files;
      _filesLoaded = true;
    });
  }

  // Start synchronization
  Future<void> _startSync() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    
    // Filter out unselected files
    final selectedFiles = _files.where((file) => file.selected).toList();
    
    // Update files in the provider
    syncProvider.updateFilesToSync(selectedFiles);
    
    // Start sync
    final success = await syncProvider.startSync(widget.sourcePath, _isTwoWaySync);
    
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start synchronization')),
        );
      }
    }
  }

  // Pause synchronization
  Future<void> _pauseSync() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    await syncProvider.pauseSync();
  }

  // Resume synchronization
  Future<void> _resumeSync() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    await syncProvider.resumeSync();
  }

  // Cancel synchronization
  Future<void> _cancelSync() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    await syncProvider.cancelSync();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Toggle selection for all files
  void _toggleSelectAll(bool? value) {
    setState(() {
      for (var file in _files) {
        file.selected = value ?? false;
      }
    });
  }

  // Build the file item UI
  Widget _buildFileItem(FileItem file) {
    return ListTile(
      leading: Icon(
        _getIconForFileType(file.mimeType),
        color: _getColorForFileType(file.mimeType),
      ),
      title: Text(
        file.path,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text('${_formatFileSize(file.size)} • '),
          Text(_formatDate(file.lastModified)),
        ],
      ),
      trailing: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          // If sync is in progress, show progress indicator
          if (syncProvider.status == SyncStatus.syncing && 
              syncProvider.getCurrentFileProgress(file.path) != null) {
            return SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: syncProvider.getCurrentFileProgress(file.path),
              ),
            );
          }
          
          // Otherwise show checkbox for selection
          return Checkbox(
            value: file.selected,
            onChanged: (syncProvider.status == SyncStatus.idle ||
                    syncProvider.status == SyncStatus.scanning)
                ? (bool? value) {
                    setState(() {
                      file.selected = value ?? false;
                    });
                  }
                : null,
          );
        },
      ),
    );
  }

  // Get an icon based on file type
  IconData _getIconForFileType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.startsWith('video/')) {
      return Icons.video_file;
    } else if (mimeType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (mimeType.startsWith('text/')) {
      return Icons.text_snippet;
    } else if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else {
      return Icons.insert_drive_file;
    }
  }
  
  // Get a color based on file type
  Color _getColorForFileType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Colors.blue;
    } else if (mimeType.startsWith('video/')) {
      return Colors.red;
    } else if (mimeType.startsWith('audio/')) {
      return Colors.purple;
    } else if (mimeType.startsWith('text/')) {
      return Colors.green;
    } else if (mimeType.contains('pdf')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
  
  // Format file size to human-readable format
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
  
  // Format date to human-readable format
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showOnlySelected = !_showOnlySelected;
              });
            },
            tooltip: 'Filter selected files',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connected device info
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.smartphone, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to: ${widget.deviceInfo.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Syncing from: ${widget.sourcePath}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sync options
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Two-way Sync'),
                    subtitle: const Text('Sync files in both directions'),
                    value: _isTwoWaySync,
                    onChanged: (bool? value) {
                      setState(() {
                        _isTwoWaySync = value ?? false;
                      });
                    },
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Select All'),
                    value: _files.isNotEmpty && _files.every((file) => file.selected),
                    onChanged: _toggleSelectAll,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
          
          // Sync status and controls
          Consumer<SyncProvider>(
            builder: (context, syncProvider, child) {
              final status = syncProvider.status;
              final progress = syncProvider.progress;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    if (status != SyncStatus.idle && status != SyncStatus.scanning)
                      Column(
                        children: [
                          LinearPercentIndicator(
                            lineHeight: 20.0,
                            percent: progress,
                            center: Text(
                              '${(progress * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                              ),
                            ),
                            progressColor: _getProgressColor(status),
                            backgroundColor: Colors.grey[200],
                            barRadius: const Radius.circular(10),
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              color: _getProgressColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Start/Resume button
                        if (status == SyncStatus.idle || 
                            status == SyncStatus.scanning || 
                            status == SyncStatus.paused)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(status == SyncStatus.paused 
                                  ? Icons.play_arrow
                                  : Icons.sync),
                              label: Text(status == SyncStatus.paused 
                                  ? 'Resume'
                                  : 'Start Sync'),
                              onPressed: status == SyncStatus.paused
                                  ? _resumeSync
                                  : _startSync,
                            ),
                          ),
                        
                        const SizedBox(width: 8),
                        
                        // Pause button
                        if (status == SyncStatus.syncing)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                              onPressed: _pauseSync,
                            ),
                          ),
                        
                        const SizedBox(width: 8),
                        
                        // Cancel button
                        if (status != SyncStatus.idle && 
                            status != SyncStatus.scanning)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _cancelSync,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          // File list
          Expanded(
            child: _filesLoaded
                ? _files.isEmpty
                    ? const Center(
                        child: Text('No files found in the selected directory'),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          
                          // Filter out unselected files if needed
                          if (_showOnlySelected && !file.selected) {
                            return Container();
                          }
                          
                          return _buildFileItem(file);
                        },
                      )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
        ],
      ),
    );
  }
  
  // Get color based on sync status
  Color _getProgressColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.preparing:
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.paused:
        return Colors.orange;
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
      case SyncStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Get status text
  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.scanning:
        return 'Scanning files...';
      case SyncStatus.preparing:
        return 'Preparing to sync...';
      case SyncStatus.syncing:
        return 'Syncing files...';
      case SyncStatus.paused:
        return 'Sync paused';
      case SyncStatus.completed:
        return 'Sync completed';
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.cancelled:
        return 'Sync cancelled';
      default:
        return 'Ready to sync';
    }
  }
} 
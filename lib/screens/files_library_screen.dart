import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import 'file_viewer_screen.dart';

class FilesLibraryScreen extends StatefulWidget {
  const FilesLibraryScreen({super.key});

  @override
  State<FilesLibraryScreen> createState() => _FilesLibraryScreenState();
}

class _FilesLibraryScreenState extends State<FilesLibraryScreen> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy = 'name'; // 'name', 'date', 'size'
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final downloadsDir = await getApplicationDocumentsDirectory();
      final syncDownloadsPath = path.join(downloadsDir.path, 'folder_sync_downloads');
      final syncDownloadsDir = Directory(syncDownloadsPath);

      if (await syncDownloadsDir.exists()) {
        final files = await syncDownloadsDir.list().where((entity) => 
          entity is File
        ).toList();
        
        _sortFiles(files);
        
        setState(() {
          _files = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  void _sortFiles(List<FileSystemEntity> files) {
    files.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = path.basename(a.path).toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase());
          break;
        case 'date':
          final aStat = a.statSync();
          final bStat = b.statSync();
          comparison = aStat.modified.compareTo(bStat.modified);
          break;
        case 'size':
          final aStat = a.statSync();
          final bStat = b.statSync();
          comparison = aStat.size.compareTo(bStat.size);
          break;
      }
      
      return _ascending ? comparison : -comparison;
    });
  }

  void _changeSortOrder(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _ascending = !_ascending;
      } else {
        _sortBy = sortBy;
        _ascending = true;
      }
    });
    _sortFiles(_files);
  }

  IconData _getFileIcon(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    final mimeType = lookupMimeType(filePath);

    if (extension == '.pdf' || mimeType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (_isImageFile(extension, mimeType)) {
      return Icons.image;
    } else if (_isVideoFile(extension, mimeType)) {
      return Icons.video_file;
    } else if (_isTextFile(extension, mimeType)) {
      return Icons.text_snippet;
    }

    switch (extension) {
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.archive;
      case '.mp3':
      case '.wav':
      case '.flac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool _isImageFile(String extension, String? mimeType) {
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    return imageExtensions.contains(extension) || 
           (mimeType?.startsWith('image/') ?? false);
  }

  bool _isVideoFile(String extension, String? mimeType) {
    const videoExtensions = ['.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm'];
    return videoExtensions.contains(extension) || 
           (mimeType?.startsWith('video/') ?? false);
  }

  bool _isTextFile(String extension, String? mimeType) {
    const textExtensions = ['.txt', '.md', '.log', '.json', '.xml', '.csv'];
    return textExtensions.contains(extension) || 
           (mimeType?.startsWith('text/') ?? false);
  }

  Color _getFileColor(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    final mimeType = lookupMimeType(filePath);

    if (extension == '.pdf') return Colors.red;
    if (_isImageFile(extension, mimeType)) return Colors.green;
    if (_isVideoFile(extension, mimeType)) return Colors.blue;
    if (_isTextFile(extension, mimeType)) return Colors.orange;
    return Colors.grey;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing file: ${path.basename(file.path)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share file: $e')),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${path.basename(file.path)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        _loadFiles(); // Refresh the file list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File deleted: ${path.basename(file.path)}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: $e')),
        );
      }
    }
  }

  void _viewFile(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileViewerScreen(
          file: file,
          fileName: path.basename(file.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Files Library'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _changeSortOrder,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, 
                         color: _sortBy == 'name' ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    Text('Sort by Name'),
                    if (_sortBy == 'name')
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.access_time, 
                         color: _sortBy == 'date' ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    Text('Sort by Date'),
                    if (_sortBy == 'date')
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'size',
                child: Row(
                  children: [
                    Icon(Icons.data_usage, 
                         color: _sortBy == 'size' ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    Text('Sort by Size'),
                    if (_sortBy == 'size')
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading files...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No files found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Files received from P2P connections will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index] as File;
          final fileName = path.basename(file.path);
          final stat = file.statSync();
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getFileColor(file.path).withOpacity(0.1),
                child: Icon(
                  _getFileIcon(file.path),
                  color: _getFileColor(file.path),
                ),
              ),
              title: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('${_formatFileSize(stat.size)} • ${_formatDate(stat.modified)}'),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'view':
                      _viewFile(file);
                      break;
                    case 'share':
                      _shareFile(file);
                      break;
                    case 'delete':
                      _deleteFile(file);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _viewFile(file),
            ),
          );
        },
      ),
    );
  }
} 
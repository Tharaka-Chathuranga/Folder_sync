import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class FileViewerScreen extends StatefulWidget {
  final File file;
  final String? fileName;
  final bool showDownloadOption;
  final VoidCallback? onDownload;

  const FileViewerScreen({
    super.key,
    required this.file,
    this.fileName,
    this.showDownloadOption = false,
    this.onDownload,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  String get fileName => widget.fileName ?? path.basename(widget.file.path);
  String get fileExtension => path.extension(widget.file.path).toLowerCase();
  String? get mimeType => lookupMimeType(widget.file.path);
  
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFile();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeFile() async {
    if (_isVideoFile()) {
      await _initializeVideo();
    }
  }

  bool _isImageFile() {
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    return imageExtensions.contains(fileExtension) || 
           (mimeType?.startsWith('image/') ?? false);
  }

  bool _isPdfFile() {
    return fileExtension == '.pdf' || mimeType == 'application/pdf';
  }

  bool _isVideoFile() {
    const videoExtensions = ['.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm'];
    return videoExtensions.contains(fileExtension) || 
           (mimeType?.startsWith('video/') ?? false);
  }

  bool _isTextFile() {
    const textExtensions = ['.txt', '.md', '.log', '.json', '.xml', '.csv'];
    return textExtensions.contains(fileExtension) || 
           (mimeType?.startsWith('text/') ?? false);
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(widget.file);
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );
      
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openWithExternalApp,
          ),
          if (widget.showDownloadOption && widget.onDownload != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: widget.onDownload,
            ),
        ],
      ),
      body: _buildFileViewer(),
      bottomNavigationBar: _buildBottomInfo(),
    );
  }

  Widget _buildFileViewer() {
    if (_isPdfFile()) {
      return _buildPdfViewer();
    } else if (_isImageFile()) {
      return _buildImageViewer();
    } else if (_isVideoFile()) {
      return _buildVideoViewer();
    } else if (_isTextFile()) {
      return _buildTextViewer();
    } else {
      return _buildUnsupportedFileViewer();
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      widget.file,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      // canShowNavigationToolbar: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF: ${details.error}')),
        );
      },
    );
  }

  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: FileImage(widget.file),
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2.0,
      enableRotation: true,
      heroAttributes: PhotoViewHeroAttributes(tag: widget.file.path),
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(
            value: event == null ? 0 : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load image: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoViewer() {
    if (!_isVideoInitialized || _chewieController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading video...'),
          ],
        ),
      );
    }

    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildTextViewer() {
    return FutureBuilder<String>(
      future: widget.file.readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to load file: ${snapshot.error}'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            snapshot.data ?? 'No content',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  Widget _buildUnsupportedFileViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(),
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 24),
          Text(
            'Preview not available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'File type: ${fileExtension.isEmpty ? 'Unknown' : fileExtension.substring(1).toUpperCase()}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openWithExternalApp,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with External App'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _shareFile,
            icon: const Icon(Icons.share),
            label: const Text('Share File'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    if (_isPdfFile()) return Icons.picture_as_pdf;
    if (_isImageFile()) return Icons.image;
    if (_isVideoFile()) return Icons.video_file;
    if (_isTextFile()) return Icons.text_snippet;
    
    switch (fileExtension) {
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

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FutureBuilder<FileStat>(
                  future: widget.file.stat(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final stat = snapshot.data!;
                      return Text(
                        '${_formatFileSize(stat.size)} • ${_formatDate(stat.modified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          if (widget.showDownloadOption && widget.onDownload != null)
            ElevatedButton.icon(
              onPressed: widget.onDownload,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _shareFile() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.file.path)],
        text: 'Sharing file: $fileName',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share file: $e')),
      );
    }
  }

  Future<void> _openWithExternalApp() async {
    try {
      final result = await OpenFilex.open(widget.file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No app found to open this file type')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file: $e')),
      );
    }
  }
} 
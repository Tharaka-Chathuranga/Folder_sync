import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../models/sync_session.dart';
import '../services/file_service.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;
  final FileService _fileService;
  
  // File transfer progress tracking
  final Map<String, double> _fileProgress = {};
  
  SyncProvider(this._syncService, this._fileService) {
    _setupListeners();
  }
  
  // Getters
  SyncStatus get status => _syncService.status;
  SyncSession? get currentSession => _syncService.currentSession;
  double get progress => _syncService.progress;
  double get bytesProgress => _syncService.bytesProgress;
  
  // Set up event listeners
  void _setupListeners() {
    _syncService.onStatusChanged = (status) {
      notifyListeners();
    };
    
    _syncService.onProgressChanged = (progress) {
      notifyListeners();
    };
    
    _syncService.onFileTransferStarted = (file) {
      _fileProgress[file.path] = 0.0;
      notifyListeners();
    };
    
    _syncService.onFileTransferCompleted = (file, success) {
      _fileProgress[file.path] = success ? 1.0 : 0.0;
      notifyListeners();
    };
    
    _syncService.onConflictDetected = (path, sourceFile, targetFile) {
      // Handle conflict notification (could show a dialog)
      // For now, we'll just use "keep newest" strategy
      resolveConflict(path, 'keep_newest');
    };
    
    _syncService.onError = (message) {
      // Handle error notification (could show a snackbar)
      print('Sync error: $message');
    };
  }
  
  // Get progress for a specific file
  double? getCurrentFileProgress(String filePath) {
    return _fileProgress[filePath];
  }
  
  // Request necessary permissions
  Future<bool> requestPermissions() async {
    return await _fileService.requestPermissions();
  }
  
  // Get files in a directory
  Future<List<FileItem>> getFilesInDirectory(String directoryPath) async {
    return await _fileService.getFilesInDirectory(directoryPath);
  }
  
  // Update files to sync
  void updateFilesToSync(List<FileItem> files) {
    if (currentSession != null) {
      currentSession!.files = files;
    }
  }
  
  // Start a new sync session
  Future<bool> startSync(String sourceFolderPath, bool twoWaySync) async {
    final result = await _syncService.startSync(sourceFolderPath, twoWaySync);
    notifyListeners();
    return result;
  }
  
  // Pause the current sync
  Future<bool> pauseSync() async {
    final result = await _syncService.pauseSync();
    notifyListeners();
    return result;
  }
  
  // Resume the current sync
  Future<bool> resumeSync() async {
    final result = await _syncService.resumeSync();
    notifyListeners();
    return result;
  }
  
  // Cancel the current sync
  Future<bool> cancelSync() async {
    _fileProgress.clear();
    final result = await _syncService.cancelSync();
    notifyListeners();
    return result;
  }
  
  // Resolve a file conflict
  Future<bool> resolveConflict(String filePath, String resolution) async {
    return await _syncService.resolveConflict(filePath, resolution);
  }
} 
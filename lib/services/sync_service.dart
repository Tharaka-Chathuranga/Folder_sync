import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/device_info.dart';
import '../models/file_item.dart';
import '../models/sync_session.dart';
import 'device_discovery_service.dart';
import 'file_service.dart';

enum SyncStatus {
  idle,
  scanning,
  preparing,
  syncing,
  paused,
  completed,
  failed,
  cancelled,
}

class SyncService {
  final DeviceDiscoveryService _deviceService;
  final FileService _fileService;
  
  // Current sync state
  SyncStatus _status = SyncStatus.idle;
  SyncSession? _currentSession;
  
  // Progress tracking
  int _totalFiles = 0;
  int _processedFiles = 0;
  int _totalBytes = 0;
  int _transferredBytes = 0;
  
  // Conflict resolution
  final Map<String, String> _conflictResolutions = {};
  
  // Callbacks
  Function(SyncStatus)? onStatusChanged;
  Function(double)? onProgressChanged;
  Function(FileItem)? onFileTransferStarted;
  Function(FileItem, bool)? onFileTransferCompleted;
  Function(String, FileItem, FileItem)? onConflictDetected;
  Function(String)? onError;
  
  SyncService(this._deviceService, this._fileService) {
    _setupListeners();
  }
  
  // Getters
  SyncStatus get status => _status;
  SyncSession? get currentSession => _currentSession;
  double get progress => _totalFiles > 0 ? _processedFiles / _totalFiles : 0.0;
  double get bytesProgress => _totalBytes > 0 ? _transferredBytes / _totalBytes : 0.0;
  
  // Set up listeners for device discovery service
  void _setupListeners() {
    _deviceService.onDataReceived = _handleReceivedData;
    _deviceService.onDeviceDisconnected = _handleDeviceDisconnected;
  }
  
  // Start a new sync session with a connected device
  Future<bool> startSync(String sourceFolderPath, bool twoWaySync) async {
    if (_deviceService.connectionState != ConnectionState.connected) {
      _notifyError('No device connected');
      return false;
    }
    
    if (_status == SyncStatus.syncing || _status == SyncStatus.preparing) {
      _notifyError('Sync already in progress');
      return false;
    }
    
    _setStatus(SyncStatus.scanning);
    
    try {
      // Get list of files in source folder
      final sourceFiles = await _fileService.getFilesInDirectory(sourceFolderPath);
      if (sourceFiles.isEmpty) {
        _notifyError('No files to sync');
        _setStatus(SyncStatus.idle);
        return false;
      }
      
      // Create a new sync session
      _currentSession = SyncSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceId: _deviceService.connectedDevice!.id,
        deviceName: _deviceService.connectedDevice!.name,
        sourcePath: sourceFolderPath,
        targetPath: (await _fileService.getSyncDirectory()).path,
        isActive: true,
        startTime: DateTime.now(),
        endTime: null,
        twoWaySync: twoWaySync,
        files: sourceFiles,
      );
      
      _setStatus(SyncStatus.preparing);
      
      // Send sync request to connected device
      final syncRequestMessage = {
        'type': 'sync_request',
        'session_id': _currentSession!.id,
        'source_path': _currentSession!.sourcePath,
        'two_way_sync': twoWaySync,
        'files': sourceFiles.map((file) => file.toJson()).toList(),
      };
      
      final success = await _deviceService.sendMessage(
        _deviceService.connectedDevice!.id,
        syncRequestMessage,
      );
      
      if (!success) {
        _notifyError('Failed to send sync request');
        _setStatus(SyncStatus.idle);
        _currentSession = null;
        return false;
      }
      
      // Start tracking progress
      _totalFiles = sourceFiles.length;
      _processedFiles = 0;
      _totalBytes = sourceFiles.fold(0, (sum, file) => sum + file.size);
      _transferredBytes = 0;
      
      return true;
    } catch (e) {
      _notifyError('Error starting sync: $e');
      _setStatus(SyncStatus.idle);
      _currentSession = null;
      return false;
    }
  }
  
  // Accept a sync request received from another device
  Future<bool> acceptSyncRequest(String sessionId, List<FileItem> files, String sourcePath, bool twoWaySync) async {
    if (_status == SyncStatus.syncing || _status == SyncStatus.preparing) {
      _notifyError('Sync already in progress');
      return false;
    }
    
    _setStatus(SyncStatus.preparing);
    
    try {
      // Get the target directory
      final targetDir = await _fileService.getSyncDirectory();
      
      // Create a new sync session
      _currentSession = SyncSession(
        id: sessionId,
        deviceId: _deviceService.connectedDevice!.id,
        deviceName: _deviceService.connectedDevice!.name,
        sourcePath: sourcePath,
        targetPath: targetDir.path,
        isActive: true,
        startTime: DateTime.now(),
        endTime: null,
        twoWaySync: twoWaySync,
        files: files,
      );
      
      // If two-way sync is enabled, also send our files
      if (twoWaySync) {
        // Implement later
      }
      
      // Send sync acceptance
      final acceptMessage = {
        'type': 'sync_accepted',
        'session_id': sessionId,
      };
      
      final success = await _deviceService.sendMessage(
        _deviceService.connectedDevice!.id,
        acceptMessage,
      );
      
      if (!success) {
        _notifyError('Failed to send sync acceptance');
        _setStatus(SyncStatus.idle);
        _currentSession = null;
        return false;
      }
      
      // Start tracking progress
      _totalFiles = files.length;
      _processedFiles = 0;
      _totalBytes = files.fold(0, (sum, file) => sum + file.size);
      _transferredBytes = 0;
      
      _setStatus(SyncStatus.syncing);
      return true;
    } catch (e) {
      _notifyError('Error accepting sync: $e');
      _setStatus(SyncStatus.idle);
      _currentSession = null;
      return false;
    }
  }
  
  // Pause the current sync
  Future<bool> pauseSync() async {
    if (_status != SyncStatus.syncing) {
      return false;
    }
    
    _setStatus(SyncStatus.paused);
    
    // Send pause message to connected device
    final pauseMessage = {
      'type': 'sync_paused',
      'session_id': _currentSession!.id,
    };
    
    return await _deviceService.sendMessage(
      _deviceService.connectedDevice!.id,
      pauseMessage,
    );
  }
  
  // Resume the current sync
  Future<bool> resumeSync() async {
    if (_status != SyncStatus.paused) {
      return false;
    }
    
    _setStatus(SyncStatus.syncing);
    
    // Send resume message to connected device
    final resumeMessage = {
      'type': 'sync_resumed',
      'session_id': _currentSession!.id,
    };
    
    return await _deviceService.sendMessage(
      _deviceService.connectedDevice!.id,
      resumeMessage,
    );
  }
  
  // Cancel the current sync
  Future<bool> cancelSync() async {
    if (_status != SyncStatus.syncing && _status != SyncStatus.paused) {
      return false;
    }
    
    // Send cancel message to connected device
    final cancelMessage = {
      'type': 'sync_cancelled',
      'session_id': _currentSession!.id,
    };
    
    final success = await _deviceService.sendMessage(
      _deviceService.connectedDevice!.id,
      cancelMessage,
    );
    
    _setStatus(SyncStatus.cancelled);
    _currentSession = null;
    
    return success;
  }
  
  // Resolve a file conflict
  Future<bool> resolveConflict(String filePath, String resolution) async {
    if (_status != SyncStatus.syncing && _status != SyncStatus.paused) {
      return false;
    }
    
    _conflictResolutions[filePath] = resolution;
    
    // Send conflict resolution to connected device
    final resolutionMessage = {
      'type': 'conflict_resolution',
      'session_id': _currentSession!.id,
      'file_path': filePath,
      'resolution': resolution,
    };
    
    return await _deviceService.sendMessage(
      _deviceService.connectedDevice!.id,
      resolutionMessage,
    );
  }
  
  // Handle received data from connected device
  void _handleReceivedData(DeviceInfo device, Uint8List data, bool isFile) async {
    if (!isFile) {
      // Handle control messages
      try {
        final message = jsonDecode(utf8.decode(data));
        final messageType = message['type'];
        
        switch (messageType) {
          case 'sync_request':
            _handleSyncRequest(message);
            break;
          case 'sync_accepted':
            _handleSyncAccepted(message);
            break;
          case 'sync_paused':
            _handleSyncPaused(message);
            break;
          case 'sync_resumed':
            _handleSyncResumed(message);
            break;
          case 'sync_cancelled':
            _handleSyncCancelled(message);
            break;
          case 'conflict_detected':
            _handleConflictDetected(message);
            break;
          case 'conflict_resolution':
            _handleConflictResolution(message);
            break;
          case 'file_transfer_start':
            _handleFileTransferStart(message);
            break;
          case 'file_transfer_complete':
            _handleFileTransferComplete(message);
            break;
          default:
            print('Unknown message type: $messageType');
        }
      } catch (e) {
        print('Error handling message: $e');
      }
    } else {
      // Handle received file
      // This is handled by the Nearby Connections library
    }
  }
  
  // Handle device disconnection
  void _handleDeviceDisconnected(DeviceInfo device) {
    if (_status == SyncStatus.syncing || _status == SyncStatus.paused) {
      _setStatus(SyncStatus.failed);
      _notifyError('Device disconnected during sync');
      _currentSession = null;
    }
  }
  
  // Handle sync request from another device
  void _handleSyncRequest(Map<String, dynamic> message) async {
    final sessionId = message['session_id'];
    final sourcePath = message['source_path'];
    final twoWaySync = message['two_way_sync'];
    final files = (message['files'] as List)
        .map((fileJson) => FileItem.fromJson(fileJson))
        .toList();
    
    // Notify UI and ask user to accept sync
    // For now, auto-accept
    acceptSyncRequest(sessionId, files, sourcePath, twoWaySync);
  }
  
  // Handle sync accepted by the other device
  void _handleSyncAccepted(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    _setStatus(SyncStatus.syncing);
    
    // Start sending files
    _startFileTransfer();
  }
  
  // Start transferring files
  void _startFileTransfer() async {
    if (_currentSession == null) return;
    
    for (var file in _currentSession!.files) {
      if (_status != SyncStatus.syncing) {
        // Sync was paused, cancelled, or failed
        break;
      }
      
      if (!file.selected) {
        // Skip unselected files
        continue;
      }
      
      try {
        // Notify start of file transfer
        if (onFileTransferStarted != null) {
          onFileTransferStarted!(file);
        }
        
        // Send file transfer start message
        final startMessage = {
          'type': 'file_transfer_start',
          'session_id': _currentSession!.id,
          'file_path': file.path,
          'file_size': file.size,
        };
        
        await _deviceService.sendMessage(
          _deviceService.connectedDevice!.id,
          startMessage,
        );
        
        // Send the file
        final success = await _deviceService.sendFile(
          _deviceService.connectedDevice!.id,
          file.absolutePath,
        );
        
        // Send file transfer complete message
        final completeMessage = {
          'type': 'file_transfer_complete',
          'session_id': _currentSession!.id,
          'file_path': file.path,
          'success': success,
        };
        
        await _deviceService.sendMessage(
          _deviceService.connectedDevice!.id,
          completeMessage,
        );
        
        // Update progress
        _processedFiles++;
        _transferredBytes += file.size;
        
        // Notify file transfer completion
        if (onFileTransferCompleted != null) {
          onFileTransferCompleted!(file, success);
        }
        
        // Notify progress change
        if (onProgressChanged != null) {
          onProgressChanged!(progress);
        }
      } catch (e) {
        print('Error transferring file: $e');
      }
    }
    
    // Sync completed
    if (_status == SyncStatus.syncing) {
      _setStatus(SyncStatus.completed);
      _currentSession = _currentSession?.copyWith(
        isActive: false,
        endTime: DateTime.now(),
      );
    }
  }
  
  // Handle sync paused by the other device
  void _handleSyncPaused(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    _setStatus(SyncStatus.paused);
  }
  
  // Handle sync resumed by the other device
  void _handleSyncResumed(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    _setStatus(SyncStatus.syncing);
  }
  
  // Handle sync cancelled by the other device
  void _handleSyncCancelled(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    _setStatus(SyncStatus.cancelled);
    _currentSession = null;
  }
  
  // Handle conflict detected
  void _handleConflictDetected(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    final filePath = message['file_path'];
    final sourceFile = FileItem.fromJson(message['source_file']);
    final targetFile = FileItem.fromJson(message['target_file']);
    
    if (onConflictDetected != null) {
      onConflictDetected!(filePath, sourceFile, targetFile);
    }
  }
  
  // Handle conflict resolution
  void _handleConflictResolution(Map<String, dynamic> message) {
    if (_currentSession == null) return;
    
    final sessionId = message['session_id'];
    if (sessionId != _currentSession!.id) return;
    
    final filePath = message['file_path'];
    final resolution = message['resolution'];
    
    _conflictResolutions[filePath] = resolution;
  }
  
  // Handle file transfer start
  void _handleFileTransferStart(Map<String, dynamic> message) {
    // Prepare to receive a file
  }
  
  // Handle file transfer complete
  void _handleFileTransferComplete(Map<String, dynamic> message) {
    // Update progress for received file
    _processedFiles++;
    
    // Notify progress change
    if (onProgressChanged != null) {
      onProgressChanged!(progress);
    }
  }
  
  // Update status and notify
  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    if (onStatusChanged != null) {
      onStatusChanged!(_status);
    }
  }
  
  // Notify error
  void _notifyError(String message) {
    if (onError != null) {
      onError!(message);
    }
  }
} 
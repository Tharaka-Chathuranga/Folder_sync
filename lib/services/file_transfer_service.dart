import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import './wifi_direct_service.dart';

class FileTransferService {
  final WifiDirectService _wifiDirectService;
  
  // File transfer status
  bool _isTransferring = false;
  double _progress = 0.0;
  
  // Callbacks
  Function(double)? onProgressChanged;
  Function(String)? onTransferComplete;
  Function(String)? onTransferError;
  
  // Getters
  bool get isTransferring => _isTransferring;
  double get progress => _progress;
  
  FileTransferService(this._wifiDirectService);
  
  // Get the directory to save received files
  Future<Directory> _getTransferDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final transferDir = Directory('${appDir.path}/transfers');
    
    if (!await transferDir.exists()) {
      await transferDir.create(recursive: true);
    }
    
    return transferDir;
  }
  
  // Send a file to the connected device
  Future<bool> sendFile(String filePath) async {
    final connectionInfo = _wifiDirectService.connectionInfo;
    if (connectionInfo == null || !connectionInfo.isConnected) {
      if (onTransferError != null) {
        onTransferError!('No device connected');
      }
      return false;
    }
    
    final file = File(filePath);
    if (!await file.exists()) {
      if (onTransferError != null) {
        onTransferError!('File does not exist: $filePath');
      }
      return false;
    }
    
    _isTransferring = true;
    _progress = 0.0;
    
    try {
      // Get connection info
      final targetAddress = connectionInfo.groupOwnerAddress;
      
      if (targetAddress == null) {
        if (onTransferError != null) {
          onTransferError!('Could not determine target address');
        }
        _isTransferring = false;
        return false;
      }
      
      // Create socket connection
      final socket = await Socket.connect(targetAddress, 8888, timeout: Duration(seconds: 10));
      
      // Get file info
      final fileSize = await file.length();
      final fileName = path.basename(filePath);
      
      // Send file metadata
      final metadataMap = {
        'fileName': fileName,
        'fileSize': fileSize,
      };
      
      // Send the file data
      final fileStream = file.openRead();
      int bytesSent = 0;
      
      await for (var data in fileStream) {
        socket.add(data);
        bytesSent += data.length;
        
        _progress = bytesSent / fileSize;
        if (onProgressChanged != null) {
          onProgressChanged!(_progress);
        }
      }
      
      await socket.flush();
      await socket.close();
      
      _isTransferring = false;
      
      if (onTransferComplete != null) {
        onTransferComplete!(filePath);
      }
      
      return true;
    } catch (e) {
      _isTransferring = false;
      if (onTransferError != null) {
        onTransferError!('Error sending file: $e');
      }
      return false;
    }
  }
  
  // Start listening for incoming files
  Future<void> startReceiving() async {
    final connectionInfo = _wifiDirectService.connectionInfo;
    if (connectionInfo == null || !connectionInfo.isConnected) {
      if (onTransferError != null) {
        onTransferError!('No device connected');
      }
      return;
    }
    
    try {
      // Only the group owner can receive files in this implementation
      if (!connectionInfo.isGroupOwner) {
        if (onTransferError != null) {
          onTransferError!('Only the group owner can receive files');
        }
        return;
      }
      
      // Create server socket
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
      
      // Listen for connections
      server.listen((socket) async {
        try {
          final transferDir = await _getTransferDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${transferDir.path}/received_$timestamp';
          
          final file = File(filePath);
          final sink = file.openWrite();
          
          _isTransferring = true;
          _progress = 0.0;
          
          // Read data from socket
          await socket.listen((data) {
            sink.add(data);
            
            if (onProgressChanged != null) {
              // Note: We don't know the total size, so progress is indeterminate
              onProgressChanged!(-1);
            }
          }).asFuture();
          
          await sink.flush();
          await sink.close();
          
          _isTransferring = false;
          
          if (onTransferComplete != null) {
            onTransferComplete!(filePath);
          }
        } catch (e) {
          _isTransferring = false;
          if (onTransferError != null) {
            onTransferError!('Error receiving file: $e');
          }
        }
      });
    } catch (e) {
      if (onTransferError != null) {
        onTransferError!('Error setting up file receiver: $e');
      }
    }
  }
} 
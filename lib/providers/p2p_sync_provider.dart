import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import '../services/p2p_service.dart';

enum SyncStatus {
  idle,
  connecting,
  connected,
  disconnected,
  scanning,
  sending,
  receiving,
  error
}

class P2PSyncProvider with ChangeNotifier {
  final P2PService _p2pService = P2PService();
  
  // State variables
  SyncStatus _status = SyncStatus.idle;
  String? _errorMessage;
  List<String> _connectedDevices = [];
  List<Map<String, dynamic>> _availableHosts = [];
  final List<Map<String, dynamic>> _receivedFiles = [];
  final List<Map<String, dynamic>> _sentFiles = [];
  final Map<String, double> _transferProgress = {};
  
  // Getters
  SyncStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<String> get connectedDevices => _connectedDevices;
  List<Map<String, dynamic>> get availableHosts => _availableHosts;
  List<Map<String, dynamic>> get receivedFiles => _receivedFiles;
  List<Map<String, dynamic>> get sentFiles => _sentFiles;
  Map<String, double> get transferProgress => _transferProgress;
  bool get isHost => _p2pService.role == ConnectionRole.host;
  bool get isClient => _p2pService.role == ConnectionRole.client;
  bool get isConnected => _status == SyncStatus.connected;
  String? get hostSSID => _p2pService.hostSSID;
  String? get hostPSK => _p2pService.hostPSK;
  
  // Stream subscriptions
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _clientListSubscription;
  StreamSubscription? _receivedTextSubscription;
  StreamSubscription? _receivedFilesSubscription;
  StreamSubscription? _transferProgressSubscription;
  
  // Initialize the provider
  Future<void> initialize() async {
    _setStatus(SyncStatus.idle);
    
    try {
      await _p2pService.initialize();
      
      // Set up listeners
      _connectionStateSubscription = _p2pService.connectionState.listen((isConnected) {
        if (isConnected) {
          _setStatus(SyncStatus.connected);
        } else {
          _setStatus(SyncStatus.disconnected);
        }
      });
      
      _clientListSubscription = _p2pService.clientList.listen((clients) {
        _connectedDevices = clients;
        notifyListeners();
      });
      
      _receivedTextSubscription = _p2pService.receivedText.listen((textData) {
        // Handle received text messages
        debugPrint('Received message: ${textData['message']} from ${textData['senderId']}');
      });
      
      _receivedFilesSubscription = _p2pService.receivedFiles.listen((fileData) {
        _receivedFiles.add(fileData);
        notifyListeners();
      });
      
      _transferProgressSubscription = _p2pService.transferProgress.listen((progressData) {
        _transferProgress[progressData['fileId']] = progressData['progress'];
        notifyListeners();
      });
      
    } catch (e) {
      _setError('Failed to initialize P2P service: $e');
    }
  }
  
  // Start as host
  Future<bool> startAsHost() async {
    _setStatus(SyncStatus.connecting);
    
    try {
      final result = await _p2pService.startAsHost(advertise: true);
      if (result) {
        _setStatus(SyncStatus.connected);
        return true;
      } else {
        _setStatus(SyncStatus.disconnected);
        return false;
      }
    } catch (e) {
      _setError('Failed to start as host: $e');
      return false;
    }
  }
  
  // Start scanning for hosts
  Future<void> scanForHosts() async {
    _setStatus(SyncStatus.scanning);
    _availableHosts.clear();
    
    try {
      // For now, we'll simulate finding hosts since we can't directly access BleDiscoveredDevice properties
      // In a real implementation, you would use the actual devices returned by _p2pService.scanForHosts()
      await Future.delayed(const Duration(seconds: 2)); // Simulate scanning time
      
      // Add some mock discovered hosts
      _availableHosts = [
        {'id': 'device1', 'name': 'Host Device 1'},
        {'id': 'device2', 'name': 'Host Device 2'},
      ];
      
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setError('Failed to scan for hosts: $e');
    }
  }
  
  // Connect to a host
  Future<bool> connectToHost(String deviceId) async {
    _setStatus(SyncStatus.connecting);
    
    try {
      final device = _availableHosts.firstWhere((host) => host['id'] == deviceId);
      
      // This is a simplified version - in real implementation, you'd pass the BleDiscoveredDevice object
      // For now, we'll just simulate success
      await Future.delayed(const Duration(seconds: 2)); // Simulate connection time
      _setStatus(SyncStatus.connected);
      return true;
      
    } catch (e) {
      _setError('Failed to connect to host: $e');
      return false;
    }
  }
  
  // Connect using credentials
  Future<bool> connectWithCredentials(String ssid, String psk) async {
    _setStatus(SyncStatus.connecting);
    
    try {
      final result = await _p2pService.connectWithCredentials(ssid, psk);
      if (result) {
        _setStatus(SyncStatus.connected);
        notifyListeners();
        return true;
      } else {
        _setStatus(SyncStatus.disconnected);
        return false;
      }
    } catch (e) {
      _setError('Failed to connect with credentials: $e');
      return false;
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    try {
      await _p2pService.stopConnection();
      _setStatus(SyncStatus.disconnected);
    } catch (e) {
      _setError('Failed to disconnect: $e');
    }
  }
  
  // Send a message
  Future<bool> sendMessage(String message, {String? targetClientId}) async {
    if (!isConnected) {
      _setError('Not connected');
      return false;
    }
    
    try {
      return await _p2pService.sendText(message, targetClientId: targetClientId);
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }
  
  // Select and send a file
  Future<bool> selectAndSendFile({String? targetClientId}) async {
    if (!isConnected) {
      _setError('Not connected');
      return false;
    }
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        _setStatus(SyncStatus.sending);
        
        bool success = await _p2pService.sendFile(file, targetClientId: targetClientId);
        
        _setStatus(SyncStatus.connected);
        return success;
      } else {
        // User canceled the picker
        return false;
      }
    } catch (e) {
      _setError('Failed to send file: $e');
      return false;
    }
  }
  
  // Download a file
  Future<File?> downloadFile(String fileId, {String? customFileName}) async {
    if (!isConnected) {
      _setError('Not connected');
      return null;
    }
    
    try {
      _setStatus(SyncStatus.receiving);
      
      final file = await _p2pService.downloadFile(
        fileId,
        customFileName: customFileName,
        onProgress: (progress) {
          _transferProgress[fileId] = progress;
          notifyListeners();
        },
      );
      
      _setStatus(SyncStatus.connected);
      return file;
    } catch (e) {
      _setError('Failed to download file: $e');
      return null;
    }
  }
  
  // Helper methods
  void _setStatus(SyncStatus status) {
    _status = status;
    _errorMessage = null;
    notifyListeners();
  }
  
  void _setError(String message) {
    _errorMessage = message;
    _status = SyncStatus.error;
    notifyListeners();
  }
  
  // Dispose
  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _clientListSubscription?.cancel();
    _receivedTextSubscription?.cancel();
    _receivedFilesSubscription?.cancel();
    _transferProgressSubscription?.cancel();
    _p2pService.dispose();
    super.dispose();
  }
} 
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum ConnectionRole {
  none,
  host,
  client
}

class P2PService {
  // Singleton instance
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  // Connection instances
  FlutterP2pHost? _host;
  FlutterP2pClient? _client;
  
  // Connection state
  ConnectionRole _role = ConnectionRole.none;
  ConnectionRole get role => _role;
  
  // Stream controllers
  final _connectionStateController = StreamController<bool>.broadcast();
  final _clientListController = StreamController<List<String>>.broadcast();
  final _receivedTextController = StreamController<Map<String, dynamic>>.broadcast();
  final _receivedFilesController = StreamController<Map<String, dynamic>>.broadcast();
  final _transferProgressController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Streams
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<List<String>> get clientList => _clientListController.stream;
  Stream<Map<String, dynamic>> get receivedText => _receivedTextController.stream;
  Stream<Map<String, dynamic>> get receivedFiles => _receivedFilesController.stream;
  Stream<Map<String, dynamic>> get transferProgress => _transferProgressController.stream;
  
  // Connection info
  String? _hostSSID;
  String? _hostPSK;
  String? _hostIP;
  List<String> _connectedClients = [];
  
  // Getters
  String? get hostSSID => _hostSSID;
  String? get hostPSK => _hostPSK;
  String? get hostIP => _hostIP;
  List<String> get connectedClients => _connectedClients;
  
  // Initialize P2P service
  Future<void> initialize() async {
    await _checkPermissions();
    
    // Initialize host and client instances
    _host = FlutterP2pHost();
    _client = FlutterP2pClient();
    
    // IMPORTANT: Initialize native components before use
    await _host?.initialize();
    await _client?.initialize();
    
    // Set up host state listener
    _host?.streamHotspotState().listen((state) {
      if (state.isActive) {
        _hostSSID = state.ssid;
        _hostPSK = state.preSharedKey;
        _hostIP = state.hostIpAddress;
        _connectionStateController.add(true);
      } else {
        _connectionStateController.add(false);
        if (_role == ConnectionRole.host) {
          _role = ConnectionRole.none;
        }
      }
    });
    
    // Set up client state listener
    _client?.streamHotspotState().listen((state) {
      if (state.isActive) {
        _connectionStateController.add(true);
      } else {
        _connectionStateController.add(false);
        if (_role == ConnectionRole.client) {
          _role = ConnectionRole.none;
        }
      }
    });
    
    // Set up client list listener for host
    _host?.streamClientList().listen((clients) {
      _connectedClients = clients.map((client) => client.id).toList();
      _clientListController.add(_connectedClients);
    });
    
    // Set up client list listener for client
    _client?.streamClientList().listen((clients) {
      _connectedClients = clients.map((client) => client.id).toList();
      _clientListController.add(_connectedClients);
    });
    
    // Set up text message listener for host
    _host?.streamReceivedTexts().listen((message) {
      _receivedTextController.add({
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
    
    // Set up text message listener for client
    _client?.streamReceivedTexts().listen((message) {
      _receivedTextController.add({
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
    
    // Set up file info listener for host
    _host?.streamReceivedFilesInfo().listen((fileInfoList) {
      for (var fileInfo in fileInfoList) {
        _receivedFilesController.add({
          'fileId': fileInfo.info.id,
          'fileName': fileInfo.info.name,
          'fileSize': fileInfo.info.size,
          'senderId': fileInfo.info.senderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
    
    // Set up file info listener for client
    _client?.streamReceivedFilesInfo().listen((fileInfoList) {
      for (var fileInfo in fileInfoList) {
        _receivedFilesController.add({
          'fileId': fileInfo.info.id,
          'fileName': fileInfo.info.name,
          'fileSize': fileInfo.info.size,
          'senderId': fileInfo.info.senderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }
  
  // Check and request necessary permissions
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
    
    // Check if any permission was denied
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        debugPrint('Permission $permission is ${status.name}');
      }
    });
  }
  
  // Start as host
  Future<bool> startAsHost({bool advertise = true}) async {
    if (_role != ConnectionRole.none) {
      await stopConnection();
    }
    
    try {
      final hostState = await _host?.createGroup(
        advertise: advertise,
        timeout: const Duration(seconds: 30),
      );

      if (hostState != null && hostState.isActive) {
        _role = ConnectionRole.host;
        // Store credentials for convenience
        _hostSSID = hostState.ssid;
        _hostPSK = hostState.preSharedKey;
        _hostIP  = hostState.hostIpAddress;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error starting as host: $e');
      return false;
    }
  }
  
  // Start scanning for hosts
  Future<List<BleDiscoveredDevice>> scanForHosts({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_role != ConnectionRole.none) {
      await stopConnection();
    }
    
    final completer = Completer<List<BleDiscoveredDevice>>();
    final discoveredDevices = <BleDiscoveredDevice>[];
    
    _client?.startScan(
      (devices) {
        discoveredDevices.clear();
        discoveredDevices.addAll(devices);
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(discoveredDevices);
        }
      },
      timeout: timeout,
    );
    
    return completer.future;
  }
  
  // Connect to a host using discovered device
  Future<bool> connectToHost(BleDiscoveredDevice device) async {
    if (_role != ConnectionRole.none) {
      await stopConnection();
    }
    
    try {
      await _client?.connectWithDevice(
        device,
        timeout: const Duration(seconds: 30),
      );
      
      _role = ConnectionRole.client;
      return true;
    } catch (e) {
      debugPrint('Error connecting to host: $e');
      return false;
    }
  }
  
  // Connect to a host using credentials (SSID and PSK)
  Future<bool> connectWithCredentials(String ssid, String psk) async {
    if (_role != ConnectionRole.none) {
      await stopConnection();
    }
    
    try {
      await _client?.connectWithCredentials(
        ssid,
        psk,
        timeout: const Duration(seconds: 30),
      );
      
      _role = ConnectionRole.client;
      return true;
    } catch (e) {
      debugPrint('Error connecting with credentials: $e');
      return false;
    }
  }
  
  // Stop scanning for hosts
  void stopScan() {
    _client?.stopScan();
  }
  
  // Stop connection
  Future<void> stopConnection() async {
    if (_role == ConnectionRole.host) {
      await _host?.removeGroup();
    } else if (_role == ConnectionRole.client) {
      await _client?.disconnect();
    }
    _role = ConnectionRole.none;
  }
  
  // Send text message
  Future<bool> sendText(String message, {String? targetClientId}) async {
    try {
      if (_role == ConnectionRole.host) {
        if (targetClientId != null) {
          await _host?.sendTextToClient(message, targetClientId);
        } else {
          await _host?.broadcastText(message);
        }
        return true;
      } else if (_role == ConnectionRole.client) {
        if (targetClientId != null) {
          await _client?.sendTextToClient(message, targetClientId);
        } else {
          await _client?.broadcastText(message);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending text: $e');
      return false;
    }
  }
  
  // Send file
  Future<bool> sendFile(File file, {String? targetClientId}) async {
    try {
      if (_role == ConnectionRole.host) {
        if (targetClientId != null) {
          await _host?.sendFileToClient(file, targetClientId);
        } else {
          await _host?.broadcastFile(file);
        }
        return true;
      } else if (_role == ConnectionRole.client) {
        if (targetClientId != null) {
          await _client?.sendFileToClient(file, targetClientId);
        } else {
          await _client?.broadcastFile(file);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending file: $e');
      return false;
    }
  }
  
  // Download file
  Future<File?> downloadFile(String fileId, {
    String? customFileName,
    Function(double)? onProgress,
  }) async {
    try {
      final downloadsDir = await getApplicationDocumentsDirectory();
      final savePath = path.join(downloadsDir.path, 'folder_sync_downloads');
      
      // Create directory if it doesn't exist
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      bool downloadSuccess = false;
      
      if (_role == ConnectionRole.host) {
        downloadSuccess = await _host?.downloadFile(
          fileId,
          savePath,
          customFileName: customFileName,
          onProgress: (update) {
            if (onProgress != null) {
              onProgress(update.progressPercent);
            }
            
            _transferProgressController.add({
              'fileId': fileId,
              'fileName': update.savePath.split('/').last,
              'progress': update.progressPercent,
              'bytesTransferred': update.bytesDownloaded,
              'totalBytes': update.totalSize,
            });
          },
        ) ?? false;
      } else if (_role == ConnectionRole.client) {
        downloadSuccess = await _client?.downloadFile(
          fileId,
          savePath,
          customFileName: customFileName,
          onProgress: (update) {
            if (onProgress != null) {
              onProgress(update.progressPercent);
            }
            
            _transferProgressController.add({
              'fileId': fileId,
              'fileName': update.savePath.split('/').last,
              'progress': update.progressPercent,
              'bytesTransferred': update.bytesDownloaded,
              'totalBytes': update.totalSize,
            });
          },
        ) ?? false;
      }
      
      if (downloadSuccess) {
        final fileName = customFileName ?? fileId;
        final filePath = path.join(savePath, fileName);
        return File(filePath);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }
  
  // Dispose resources
  void dispose() {
    stopConnection();
    _host?.dispose();
    _client?.dispose();
    _connectionStateController.close();
    _clientListController.close();
    _receivedTextController.close();
    _receivedFilesController.close();
    _transferProgressController.close();
  }
}

// Removed obsolete String extension which masked real plugin API 
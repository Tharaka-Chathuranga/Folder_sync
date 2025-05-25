import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';

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

enum ConnectionRole {
  none,
  host,
  client
}

class P2PSyncProvider with ChangeNotifier {
  // P2P instances
  FlutterP2pHost? _host;
  FlutterP2pClient? _client;
  
  // Connection state
  ConnectionRole _role = ConnectionRole.none;
  SyncStatus _status = SyncStatus.idle;
  String? _errorMessage;
  
  // Connection info
  HotspotClientState? _currentClientState;
  HotspotHostState? _currentHostState;
  List<BleDiscoveredDevice> _discoveredHosts = [];
  List<P2pClientInfo> _connectedClients = [];
  bool _isDiscovering = false;
  
  // File transfer tracking
  final List<Map<String, dynamic>> _receivedFiles = [];
  final List<Map<String, dynamic>> _sentFiles = [];
  final Map<String, double> _transferProgress = {};
  
  // Stream subscriptions
  StreamSubscription<List<BleDiscoveredDevice>>? _discoverySubscription;
  StreamSubscription<HotspotClientState>? _clientStateSubscription;
  StreamSubscription<HotspotHostState>? _hostStateSubscription;
  StreamSubscription<List<P2pClientInfo>>? _participantsSubscription;
  StreamSubscription<String>? _receivedTextSubscription;
  StreamSubscription<List<HostedFileInfo>>? _sentFilesSubscription;
  StreamSubscription<List<ReceivableFileInfo>>? _receivableFilesSubscription;
  
  // Getters
  SyncStatus get status => _status;
  String? get errorMessage => _errorMessage;
  ConnectionRole get role => _role;
  List<String> get connectedDevices => _connectedClients.map((client) => client.id).toList();
  List<Map<String, dynamic>> get availableHosts => _discoveredHosts.map((device) => {
    'id': device.deviceName,
    'name': device.deviceName ?? 'Unknown Device',
    'device': device,
  }).toList();
  List<Map<String, dynamic>> get receivedFiles => _receivedFiles;
  List<Map<String, dynamic>> get sentFiles => _sentFiles;
  Map<String, double> get transferProgress => _transferProgress;
  bool get isHost => _role == ConnectionRole.host;
  bool get isClient => _role == ConnectionRole.client;
  bool get isConnected => _status == SyncStatus.connected;
  String? get hostSSID => _currentHostState?.ssid ?? _currentClientState?.hostSsid;
  String? get hostPSK => _currentHostState?.preSharedKey;
  bool get isDiscovering => _isDiscovering;
  
  // Initialize the provider
  Future<void> initialize() async {
    _setStatus(SyncStatus.idle);
    
    try {
      debugPrint('Initializing P2P Sync Provider...');
      
      // Check and request permissions first
      await checkAndRequestPermissions();
      await checkAndEnableServices();
      
      // Initialize P2P instances
      _host = FlutterP2pHost();
      _client = FlutterP2pClient();
      
      // Initialize native components
      await _host!.initialize();
      await _client!.initialize();
      
      await _setupListeners();
      
      debugPrint('P2P Sync Provider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize P2P service: $e');
    }
  }
  
  // Check and Request Permissions
  Future<void> checkAndRequestPermissions() async {
    final p2pInterface = _host ?? FlutterP2pHost();
    
    // Storage (for file transfer)
    if (!await p2pInterface.checkStoragePermission()) {
      final status = await p2pInterface.askStoragePermission();
      debugPrint("Storage permission status: $status");
    }
    
    // P2P (Wi-Fi Direct related permissions for creating/connecting to groups)
    if (!await p2pInterface.checkP2pPermissions()) {
      final status = await p2pInterface.askP2pPermissions();
      debugPrint("P2P permission status: $status");
    }
    
    // Bluetooth (for BLE discovery and connection)
    if (!await p2pInterface.checkBluetoothPermissions()) {
      final status = await p2pInterface.askBluetoothPermissions();
      debugPrint("Bluetooth permission status: $status");
    }
  }
  
  // Check and Enable Services
  Future<void> checkAndEnableServices() async {
    final p2pInterface = _host ?? FlutterP2pHost();
    
    try {
      // Wi-Fi - Check and enable with retry
      bool wifiEnabled = await p2pInterface.checkWifiEnabled();
      if (!wifiEnabled) {
        debugPrint("WiFi not enabled, attempting to enable...");
        final status = await p2pInterface.enableWifiServices();
        debugPrint("Wi-Fi enable attempt result: $status");
        
        // Wait and check again
        await Future.delayed(const Duration(seconds: 2));
        wifiEnabled = await p2pInterface.checkWifiEnabled();
        if (!wifiEnabled) {
          debugPrint("WARNING: WiFi still not enabled after enable attempt");
        }
      }
      
      // Location (often needed for scanning)
      bool locationEnabled = await p2pInterface.checkLocationEnabled();
      if (!locationEnabled) {
        debugPrint("Location not enabled, attempting to enable...");
        final status = await p2pInterface.enableLocationServices();
        debugPrint("Location enable attempt result: $status");
        
        // Wait and check again
        await Future.delayed(const Duration(seconds: 1));
        locationEnabled = await p2pInterface.checkLocationEnabled();
        if (!locationEnabled) {
          debugPrint("WARNING: Location still not enabled after enable attempt");
        }
      }
      
      // Bluetooth (if using BLE features)
      bool bluetoothEnabled = await p2pInterface.checkBluetoothEnabled();
      if (!bluetoothEnabled) {
        debugPrint("Bluetooth not enabled, attempting to enable...");
        final status = await p2pInterface.enableBluetoothServices();
        debugPrint("Bluetooth enable attempt result: $status");
        
        // Wait and check again
        await Future.delayed(const Duration(seconds: 1));
        bluetoothEnabled = await p2pInterface.checkBluetoothEnabled();
        if (!bluetoothEnabled) {
          debugPrint("WARNING: Bluetooth still not enabled after enable attempt");
        }
      }
      
      debugPrint("Services status - WiFi: $wifiEnabled, Location: $locationEnabled, Bluetooth: $bluetoothEnabled");
    } catch (e) {
      debugPrint("Error checking/enabling services: $e");
      throw Exception("Failed to enable required services: $e");
    }
  }
  
  // Setup stream listeners
  Future<void> _setupListeners() async {
    // Host state listener
    _hostStateSubscription = _host!.streamHotspotState().listen((state) {
      _currentHostState = state;
      if (state.isActive) {
        _setStatus(SyncStatus.connected);
        _role = ConnectionRole.host;
        debugPrint("Host active: SSID: ${state.ssid}, PSK: ${state.preSharedKey}");
      } else {
        if (_role == ConnectionRole.host) {
          _setStatus(SyncStatus.disconnected);
          _role = ConnectionRole.none;
        }
        debugPrint("Host disconnected");
      }
      notifyListeners();
    });
    
    // Client state listener
    _clientStateSubscription = _client!.streamHotspotState().listen((state) {
      _currentClientState = state;
      if (state.isActive) {
        _setStatus(SyncStatus.connected);
        _role = ConnectionRole.client;
        debugPrint("Client connected to Host: ${state.hostSsid}, Gateway IP: ${state.hostGatewayIpAddress}, My P2P IP: ${state.hostIpAddress}");
      } else {
        if (_role == ConnectionRole.client) {
          _setStatus(SyncStatus.disconnected);
          _role = ConnectionRole.none;
        }
        debugPrint("Client disconnected from host");
      }
      notifyListeners();
    });
    
    // Participants listener (works for both host and client)
    _participantsSubscription = _client!.streamClientList().listen((participants) {
      _connectedClients = participants;
      debugPrint("Participants in group: ${participants.map((p) => '${p.username}(Host: ${p.isHost})').toList()}");
      notifyListeners();
    });
    
    // Host participants listener
    _host!.streamClientList().listen((participants) {
      _connectedClients = participants;
      debugPrint("Host - participants in group: ${participants.map((p) => '${p.username}(Host: ${p.isHost})').toList()}");
      notifyListeners();
    });
    
    // Received text messages
    _receivedTextSubscription = _client!.streamReceivedTexts().listen((text) {
      debugPrint("Received text: $text");
      // Handle received messages here
    });
    
    _host!.streamReceivedTexts().listen((text) {
      debugPrint("Host received text: $text");
      // Handle received messages here
    });
    
    // Sent files tracking for client
    _sentFilesSubscription = _client!.streamSentFilesInfo().listen((files) {
      _sentFiles.clear();
      for (var hostedFile in files) {
        _sentFiles.add({
          'id': hostedFile.info.id,
          'name': hostedFile.info.name,
          'size': hostedFile.info.size,
          'receiverIds': hostedFile.receiverIds,
        });
        
        for (var receiverId in hostedFile.receiverIds) {
          _transferProgress['${hostedFile.info.id}_$receiverId'] = 
              hostedFile.getProgressPercent(receiverId);
        }
      }
      notifyListeners();
    });
    
    // Sent files tracking for host
    _host!.streamSentFilesInfo().listen((files) {
      _sentFiles.clear();
      for (var hostedFile in files) {
        _sentFiles.add({
          'id': hostedFile.info.id,
          'name': hostedFile.info.name,
          'size': hostedFile.info.size,
          'receiverIds': hostedFile.receiverIds,
        });
        
        for (var receiverId in hostedFile.receiverIds) {
          _transferProgress['${hostedFile.info.id}_$receiverId'] = 
              hostedFile.getProgressPercent(receiverId);
        }
      }
      notifyListeners();
    });
    
    // Receivable files tracking for client
    _receivableFilesSubscription = _client!.streamReceivedFilesInfo().listen((files) {
      _receivedFiles.clear();
      for (var receivableFile in files) {
        _receivedFiles.add({
          'id': receivableFile.info.id,
          'name': receivableFile.info.name,
          'size': receivableFile.info.size,
          'senderId': receivableFile.info.senderId,
          'state': receivableFile.state.toString(),
          'downloadProgress': receivableFile.downloadProgressPercent,
        });
      }
      notifyListeners();
    });
    
    // Receivable files tracking for host
    _host!.streamReceivedFilesInfo().listen((files) {
      _receivedFiles.clear();
      for (var receivableFile in files) {
        _receivedFiles.add({
          'id': receivableFile.info.id,
          'name': receivableFile.info.name,
          'size': receivableFile.info.size,
          'senderId': receivableFile.info.senderId,
          'state': receivableFile.state.toString(),
          'downloadProgress': receivableFile.downloadProgressPercent,
        });
      }
      notifyListeners();
    });
  }
  
  // Start hosting
  Future<bool> startAsHost() async {
    if (_currentHostState?.isActive == true) {
      debugPrint("Already hosting");
      return true;
    }
    
    _setStatus(SyncStatus.connecting);
    
    try {
      // Ensure permissions and services are ready
      await checkAndRequestPermissions();
      await checkAndEnableServices();
      
      await _host!.createGroup(advertise: true);
      debugPrint("Host startup initiated");
      return true;
    } catch (e) {
      _setError('Failed to start as host: $e');
      return false;
    }
  }
  
  // Start scanning for hosts
  Future<void> scanForHosts() async {
    if (_isDiscovering) {
      debugPrint("Already discovering");
      return;
    }
    
    _setStatus(SyncStatus.scanning);
    
    try {
      // Ensure permissions and services are ready
      await checkAndRequestPermissions();
      await checkAndEnableServices();
      
      _isDiscovering = true;
      _discoveredHosts.clear();
      notifyListeners();
      
      _discoverySubscription = await _client!.startScan(
        (devices) {
          _discoveredHosts = devices;
          debugPrint("Discovered hosts: ${devices.map((d) => d.deviceName).toList()}");
          notifyListeners();
        },
        onError: (error) {
          debugPrint("BLE Discovery error: $error");
          _setError("Discovery error: $error");
          _isDiscovering = false;
          notifyListeners();
        },
        onDone: () {
          debugPrint("BLE Discovery finished or timed out");
          _isDiscovering = false;
          _setStatus(SyncStatus.idle);
          notifyListeners();
        },
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      _setError('Failed to scan for hosts: $e');
      _isDiscovering = false;
      notifyListeners();
    }
  }
  
  // Stop scanning
  Future<void> stopDiscovery() async {
    try {
      await _client!.stopScan();
      _isDiscovering = false;
      _setStatus(SyncStatus.idle);
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping discovery: $e");
    }
  }
  
  // Connect to a host by device
  Future<bool> connectToHost(String deviceId) async {
    if (_currentClientState?.isActive == true) {
      debugPrint("Already connected");
      return true;
    }
    
    _setStatus(SyncStatus.connecting);
    
    try {
      final device = _discoveredHosts.firstWhere((host) => host.deviceName == deviceId);
      
      await _client!.connectWithDevice(device);
      debugPrint("Connection attempt to ${device.deviceName} successful");
      
      // Stop discovery once connection is attempted
      await stopDiscovery();
      return true;
    } catch (e) {
      _setError('Failed to connect to host: $e');
      return false;
    }
  }
  
  // Connect using credentials
  Future<bool> connectWithCredentials(String ssid, String psk) async {
    if (_currentClientState?.isActive == true) {
      debugPrint("Already connected");
      return true;
    }
    
    _setStatus(SyncStatus.connecting);
    
    try {
      // Ensure permissions and services are ready
      await checkAndRequestPermissions();
      await checkAndEnableServices();
      
      debugPrint("Attempting connection to $ssid with increased timeout...");
      
      // Increase timeout and add more detailed error handling
      await _client!.connectWithCredentials(
        ssid, 
        psk,
        timeout: const Duration(minutes: 2), // Increase from 30s to 2 minutes
      );
      
      debugPrint("Connection attempt with credentials to $ssid successful");
      return true;
    } on TimeoutException catch (e) {
      _setError('Connection timeout: Failed to connect to $ssid within 2 minutes. Please check if the host is nearby and broadcasting.');
      return false;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.toLowerCase().contains('timeout')) {
        _setError('Connection timeout: Please ensure the host device is nearby and the credentials are correct.');
      } else if (errorMsg.toLowerCase().contains('wifi') || errorMsg.toLowerCase().contains('network')) {
        _setError('WiFi connection failed: Please enable WiFi and ensure you are in range of the host device.');
      } else {
        _setError('Failed to connect with credentials: $e');
      }
      return false;
    }
  }
  
  // Connect using credentials with retry logic
  Future<bool> connectWithCredentialsRetry(String ssid, String psk, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint("Connection attempt $attempt/$maxRetries to $ssid");
      
      final success = await connectWithCredentials(ssid, psk);
      if (success) {
        return true;
      }
      
      if (attempt < maxRetries) {
        debugPrint("Connection attempt $attempt failed, waiting before retry...");
        _setStatus(SyncStatus.idle);
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    _setError('Failed to connect to $ssid after $maxRetries attempts. Please check host availability and credentials.');
    return false;
  }
  
  // Disconnect
  Future<void> disconnect() async {
    try {
      if (_role == ConnectionRole.host) {
        await _host!.removeGroup();
      } else if (_role == ConnectionRole.client) {
        await _client!.disconnect();
      }
      
      _role = ConnectionRole.none;
      _setStatus(SyncStatus.disconnected);
      debugPrint("Disconnected successfully");
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
      if (_role == ConnectionRole.host) {
        if (targetClientId != null) {
          await _host!.sendTextToClient(message, targetClientId);
        } else {
          await _host!.broadcastText(message);
        }
      } else if (_role == ConnectionRole.client) {
        await _client!.broadcastText(message);
      }
      
      debugPrint("Message sent: $message");
      return true;
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
        
        P2pFileInfo? fileInfo;
        if (_role == ConnectionRole.host) {
          if (targetClientId != null) {
            fileInfo = await _host!.sendFileToClient(file, targetClientId);
          } else {
            fileInfo = await _host!.broadcastFile(file);
          }
        } else if (_role == ConnectionRole.client) {
          fileInfo = await _client!.broadcastFile(file);
        }
        
        if (fileInfo != null) {
          debugPrint("File sharing initiated: ${fileInfo.name} (ID: ${fileInfo.id})");
          _setStatus(SyncStatus.connected);
          return true;
        } else {
          _setError("File sharing failed to initiate");
          _setStatus(SyncStatus.connected);
          return false;
        }
      } else {
        // User canceled the picker
        return false;
      }
    } catch (e) {
      _setError('Failed to send file: $e');
      _setStatus(SyncStatus.connected);
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
      
      final downloadsDir = await getApplicationDocumentsDirectory();
      final savePath = path.join(downloadsDir.path, 'folder_sync_downloads');
      
      // Create directory if it doesn't exist
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      bool downloadSuccess = false;
      
      if (_role == ConnectionRole.host) {
        downloadSuccess = await _host!.downloadFile(
          fileId,
          savePath,
          customFileName: customFileName,
          onProgress: (update) {
            _transferProgress[fileId] = update.progressPercent;
            notifyListeners();
          },
        ) ?? false;
      } else if (_role == ConnectionRole.client) {
        downloadSuccess = await _client!.downloadFile(
          fileId,
          savePath,
          customFileName: customFileName,
          onProgress: (update) {
            _transferProgress[fileId] = update.progressPercent;
            notifyListeners();
          },
        ) ?? false;
      }
      
      _setStatus(SyncStatus.connected);
      
      if (downloadSuccess) {
        final fileName = customFileName ?? fileId;
        final filePath = path.join(savePath, fileName);
        return File(filePath);
      }
      
      return null;
    } catch (e) {
      _setError('Failed to download file: $e');
      _setStatus(SyncStatus.connected);
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
  
  // Client management methods
  
  /// Get detailed information about all connected clients
  List<Map<String, dynamic>> getAllClientsInfo() {
    return _connectedClients.map((client) => {
      'id': client.id,
      'username': client.username,
      'isHost': client.isHost,
    }).toList();
  }
  
  /// Disconnect a specific client (only for hosts)
  Future<bool> disconnectClient(String clientId) async {
    if (!isHost) {
      _setError('Only hosts can disconnect clients');
      return false;
    }
    
    try {
      // Note: The flutter_p2p_connection package doesn't expose individual client disconnection
      // This would need to be implemented at the native level
      debugPrint('Individual client disconnection not supported by flutter_p2p_connection package');
      return false;
    } catch (e) {
      _setError('Failed to disconnect client: $e');
      return false;
    }
  }
  
  /// Remove a client from tracking
  Future<bool> removeClient(String clientId) async {
    if (!isHost) {
      _setError('Only hosts can remove clients');
      return false;
    }
    
    try {
      // Remove from local tracking
      _connectedClients.removeWhere((client) => client.id == clientId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove client: $e');
      return false;
    }
  }
  
  // WiFi status methods
  
  /// Check if WiFi is currently enabled and connected
  Future<bool> isWiFiEnabled() async {
    final p2pInterface = _host ?? _client ?? FlutterP2pHost();
    return await p2pInterface.checkWifiEnabled();
  }
  
  /// Get detailed WiFi status information
  Future<Map<String, dynamic>> getWiFiStatus() async {
    final p2pInterface = _host ?? _client ?? FlutterP2pHost();
    return {
      'wifiEnabled': await p2pInterface.checkWifiEnabled(),
      'locationEnabled': await p2pInterface.checkLocationEnabled(),
      'bluetoothEnabled': await p2pInterface.checkBluetoothEnabled(),
    };
  }
  
  /// Check if device can connect to WiFi networks
  Future<bool> canConnectToWiFi() async {
    return await isWiFiEnabled();
  }
  
  /// Check Bluetooth status and availability
  Future<Map<String, dynamic>> getBluetoothStatus() async {
    try {
      final p2pInterface = _host ?? _client ?? FlutterP2pHost();
      final bluetoothEnabled = await p2pInterface.checkBluetoothEnabled();
      final bluetoothPermissions = await p2pInterface.checkBluetoothPermissions();
      
      return {
        'bluetoothEnabled': bluetoothEnabled,
        'bluetoothPermissions': bluetoothPermissions,
        'allBluetoothReady': bluetoothEnabled && bluetoothPermissions,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  // Dispose
  @override
  void dispose() {
    debugPrint('Disposing P2P Sync Provider...');
    
    // Cancel all subscriptions
    _discoverySubscription?.cancel();
    _clientStateSubscription?.cancel();
    _hostStateSubscription?.cancel();
    _participantsSubscription?.cancel();
    _receivedTextSubscription?.cancel();
    _sentFilesSubscription?.cancel();
    _receivableFilesSubscription?.cancel();
    
    // Dispose P2P instances
    _host?.dispose();
    _client?.dispose();
    
    super.dispose();
  }
} 
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionRole {
  none,
  host,
  client
}

// App-specific UUID for identifying our app's hostspots
const String APP_SERVICE_UUID = "12345678-1234-5678-9abc-123456789012";
const String APP_NAME = "FolderSync";
const String APP_VERSION = "1.0.0"; // Add version for better compatibility

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
  
  // Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Operation state management
  bool _isOperationInProgress = false;
  DateTime? _lastOperationTime;
  static const Duration _operationDebounceDelay = Duration(milliseconds: 500);
  static const Duration _cleanupDelay = Duration(milliseconds: 1000);
  static const Duration _socketReleaseDelay = Duration(milliseconds: 2000);
  
  // Stream controllers
  final _connectionStateController = StreamController<bool>.broadcast();
  final _clientListController = StreamController<List<String>>.broadcast();
  final _receivedTextController = StreamController<Map<String, dynamic>>.broadcast();
  final _receivedFilesController = StreamController<Map<String, dynamic>>.broadcast();
  final _transferProgressController = StreamController<Map<String, dynamic>>.broadcast();
  final _clientConnectionController = StreamController<Map<String, dynamic>>.broadcast();
  final _folderShareController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Streams
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<List<String>> get clientList => _clientListController.stream;
  Stream<Map<String, dynamic>> get receivedText => _receivedTextController.stream;
  Stream<Map<String, dynamic>> get receivedFiles => _receivedFilesController.stream;
  Stream<Map<String, dynamic>> get transferProgress => _transferProgressController.stream;
  Stream<Map<String, dynamic>> get clientConnections => _clientConnectionController.stream;
  Stream<Map<String, dynamic>> get folderShares => _folderShareController.stream;
  
  // Connection info
  String? _hostSSID;
  String? _hostPSK;
  String? _hostIP;
  List<String> _connectedClients = [];
  List<String> _authorizedClients = []; // Track only app-verified clients
  Map<String, Map<String, dynamic>> _clientInfo = {}; // Store client details
  List<Map<String, dynamic>> _availableFolders = [];
  
  // Getters
  String? get hostSSID => _hostSSID;
  String? get hostPSK => _hostPSK;
  String? get hostIP => _hostIP;
  List<String> get connectedClients => _authorizedClients; // Return only authorized clients
  List<Map<String, dynamic>> get availableFolders => _availableFolders;
  Map<String, Map<String, dynamic>> get clientInfo => _clientInfo;
  
  // Initialize P2P service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('P2P service already initialized');
      return;
    }
    
    debugPrint('=== P2P SERVICE INITIALIZATION START ===');
    debugPrint('Initializing P2P service...');
    
    try {
      debugPrint('Checking permissions...');
      await _checkPermissions();
      debugPrint('Permissions check completed');
      
      // Ensure clean state
      debugPrint('Resetting plugin instances...');
      await _resetPluginInstances();
      debugPrint('Plugin instances reset completed');
      
      // Initialize host and client instances
      debugPrint('Creating host and client instances...');
      _host = FlutterP2pHost();
      _client = FlutterP2pClient();
      debugPrint('Host and client instances created');
      
      // IMPORTANT: Initialize native components before use
      try {
        debugPrint('Initializing host plugin...');
        await _host?.initialize();
        debugPrint('Host plugin initialized successfully');
        
        debugPrint('Initializing client plugin...');
        await _client?.initialize();
        debugPrint('Client plugin initialized successfully');
        
        debugPrint('Plugin instances initialized successfully');
      } catch (e) {
        debugPrint('ERROR initializing plugin instances: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
        throw Exception('Failed to initialize P2P plugins: $e');
      }
      
      // Set up host state listener
      _host?.streamHotspotState().listen((state) {
        if (state.isActive) {
          _hostSSID = state.ssid;
          _hostPSK = state.preSharedKey;
          _hostIP = state.hostIpAddress;
          _connectionStateController.add(true);
          
          // Send app identification via Bluetooth LE advertising
          _advertiseAppService();
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
          
          // Notify host about client connection
          _notifyHostAboutConnection();
        } else {
          _connectionStateController.add(false);
          if (_role == ConnectionRole.client) {
            _role = ConnectionRole.none;
          }
        }
      });
      
      // Set up client list listener for host
      _host?.streamClientList().listen((clients) {
        final previousClients = Set.from(_connectedClients);
        _connectedClients = clients.map((client) => client.id).toList();
        final currentClients = Set.from(_connectedClients);
        
        // Detect new client connections
        final newClients = currentClients.difference(previousClients);
        for (final clientId in newClients) {
          // Start app verification process for new clients
          _initiateClientVerification(clientId);
          
          _clientConnectionController.add({
            'action': 'connected',
            'clientId': clientId,
            'status': 'pending_verification',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        // Detect client disconnections
        final disconnectedClients = previousClients.difference(currentClients);
        for (final clientId in disconnectedClients) {
          // Remove from authorized list and client info
          _authorizedClients.remove(clientId);
          _clientInfo.remove(clientId);
          
          _clientConnectionController.add({
            'action': 'disconnected',
            'clientId': clientId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        _clientListController.add(_authorizedClients); // Only send authorized clients
      });
      
      // Set up client list listener for client
      _client?.streamClientList().listen((clients) {
        _connectedClients = clients.map((client) => client.id).toList();
        _clientListController.add(_connectedClients);
      });
      
      // Set up text message listener for host
      _host?.streamReceivedTexts().listen((message) {
        // Handle app-specific messages
        if (message.startsWith('APP_ID:$APP_NAME')) {
          // Extract client ID and app details from the message
          final parts = message.split(':');
          if (parts.length >= 4) {
            final clientId = parts[3]; // Assuming client sends its ID
            final appVersion = parts.length > 4 ? parts[4] : 'unknown';
            
            // Verify this is our app
            if (parts[1] == APP_NAME && parts[2] == APP_SERVICE_UUID) {
              _authorizeClient(clientId, appVersion);
            } else {
              _rejectClient(clientId, 'Invalid app credentials');
            }
          }
          return;
        }
        
        if (message.startsWith('FOLDER_REQUEST:')) {
          // Client is requesting folder list - only process if authorized
          final clientId = message.split(':')[1];
          if (_authorizedClients.contains(clientId)) {
            _sendFolderListToClient(clientId);
          } else {
            debugPrint('Unauthorized client $clientId requesting folders');
          }
          return;
        }
        
        // Extract sender ID from message (simplified approach)
        final senderId = _extractSenderIdFromMessage(message);
        
        // Only process messages from authorized clients
        if (senderId != null && _authorizedClients.contains(senderId)) {
          _receivedTextController.add({
            'message': message,
            'senderId': senderId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          debugPrint('Ignoring message from unauthorized client: $senderId');
        }
      });
      
      // Set up text message listener for client
      _client?.streamReceivedTexts().listen((message) {
        // Handle app verification requests from host
        if (message.startsWith('VERIFY_APP:')) {
          final parts = message.split(':');
          if (parts.length >= 3 && parts[1] == APP_NAME && parts[2] == APP_SERVICE_UUID) {
            // Respond with our app identification
            _notifyHostAboutConnection();
          }
          return;
        }
        
        // Handle disconnect messages from host
        if (message.startsWith('DISCONNECT:')) {
          final reason = message.split(':')[1];
          debugPrint('Host disconnected us: $reason');
          _connectionStateController.add(false);
          return;
        }
        
        // Handle folder sharing messages
        if (message.startsWith('FOLDER_LIST:')) {
          final folderData = message.substring(12); // Remove 'FOLDER_LIST:' prefix
          _processFolderList(folderData);
          return;
        }
        
        _receivedTextController.add({
          'message': message,
          'senderId': 'host',
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
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing P2P service: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      _isInitialized = false;
    }
  }
  
  // Check and request necessary permissions
  Future<void> _checkPermissions() async {
    debugPrint('=== CHECKING PERMISSIONS ===');
    
    final permissionsToCheck = [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ];
    
    debugPrint('Requesting ${permissionsToCheck.length} permissions...');
    
    Map<Permission, PermissionStatus> statuses = await permissionsToCheck.request();
    
    // Detailed permission analysis
    bool hasAllRequired = true;
    List<String> missingPermissions = [];
    
    statuses.forEach((permission, status) {
      final permissionName = permission.toString().split('.').last;
      debugPrint('$permissionName: ${status.name}');
      
      if (!status.isGranted) {
        hasAllRequired = false;
        missingPermissions.add(permissionName);
        
        if (status.isDenied) {
          debugPrint('  -> $permissionName is DENIED');
        } else if (status.isPermanentlyDenied) {
          debugPrint('  -> $permissionName is PERMANENTLY DENIED (needs settings)');
        } else if (status.isRestricted) {
          debugPrint('  -> $permissionName is RESTRICTED (parental controls?)');
        }
      } else {
        debugPrint('  -> $permissionName is GRANTED ✓');
      }
    });
    
    debugPrint('=== PERMISSION SUMMARY ===');
    debugPrint('All required permissions granted: $hasAllRequired');
    
    if (!hasAllRequired) {
      debugPrint('Missing permissions: ${missingPermissions.join(", ")}');
      debugPrint('WiFi Direct may not work properly without these permissions');
    }
    
    // Special check for location services (required for WiFi Direct)
    final locationServiceStatus = await Permission.location.serviceStatus;
    debugPrint('Location service enabled: ${locationServiceStatus.isEnabled}');
    
    if (!locationServiceStatus.isEnabled) {
      debugPrint('WARNING: Location services are disabled - WiFi Direct requires location services');
    }
  }
  
  // WiFi state management methods
  
  /// Check if WiFi is enabled and connected
  Future<bool> isWiFiEnabled() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      return connectivityResults.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('Error checking WiFi state: $e');
      return false;
    }
  }
  
  /// Get current WiFi connection info (simplified without network_info_plus)
  Future<Map<String, dynamic>> getWiFiInfo() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      final hasWiFi = connectivityResults.contains(ConnectivityResult.wifi);
      
      return {
        'ssid': hasWiFi ? 'Connected' : null, // Simplified - can't get exact SSID without additional permissions
        'bssid': null,
        'ip': null,
        'isConnected': hasWiFi,
      };
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
      return {
        'ssid': null,
        'bssid': null,
        'ip': null,
        'isConnected': false,
      };
    }
  }
  
  /// Check if device can connect to WiFi networks
  Future<bool> canConnectToWiFi() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      
      // Device has network capability if it has any kind of connection
      return connectivityResults.isNotEmpty && 
             !connectivityResults.every((result) => result == ConnectivityResult.none);
    } catch (e) {
      debugPrint('Error checking WiFi capability: $e');
      return true; // Assume WiFi is available if we can't check
    }
  }
  
  /// Check WiFi connectivity status for connection attempts
  Future<Map<String, dynamic>> checkWiFiStatus() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      final wifiInfo = await getWiFiInfo();
      final hasWiFi = connectivityResults.contains(ConnectivityResult.wifi);
      final hasConnection = !connectivityResults.every((result) => result == ConnectivityResult.none);
      
      return {
        'hasWiFi': hasWiFi,
        'hasConnection': hasConnection,
        'currentSSID': wifiInfo['ssid'],
        'canAttemptConnection': true, // Always allow attempt, let system handle WiFi
        'status': connectivityResults.map((r) => r.name).join(', '),
        'needsWiFiEnable': !hasWiFi && !hasConnection,
      };
    } catch (e) {
      debugPrint('Error checking WiFi status: $e');
      return {
        'hasWiFi': false,
        'hasConnection': false,
        'currentSSID': null,
        'canAttemptConnection': true,
        'status': 'unknown',
        'needsWiFiEnable': true,
      };
    }
  }
  
  // Start as host
  Future<bool> startAsHost({bool advertise = true}) async {
    debugPrint('=== START AS HOST REQUEST ===');
    debugPrint('Advertise: $advertise');
    debugPrint('Current role: $_role');
    debugPrint('Is initialized: $_isInitialized');
    debugPrint('Is operation in progress: $_isOperationInProgress');
    
    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastOperationTime != null && 
        now.difference(_lastOperationTime!) < _operationDebounceDelay) {
      debugPrint('Operation debounced - too soon after last operation');
      return false;
    }
    
    if (_isOperationInProgress) {
      debugPrint('Another operation is already in progress');
      return false;
    }
    
    if (!_isInitialized) {
      debugPrint('P2P service not initialized, initializing now...');
      try {
        await initialize();
        debugPrint('P2P service initialization completed');
      } catch (e) {
        debugPrint('CRITICAL: Failed to initialize P2P service: $e');
        return false;
      }
    }
    
    _isOperationInProgress = true;
    _lastOperationTime = now;
    
    try {
      debugPrint('=== PRE-HOST SETUP ===');
      
      // Check WiFi Direct capability
      debugPrint('Checking device WiFi Direct capability...');
      final wifiStatus = await checkWiFiStatus();
      debugPrint('WiFi status: $wifiStatus');
      
      // Ensure clean state before starting
      if (_role != ConnectionRole.none) {
        debugPrint('Stopping existing connection before starting host...');
        await _stopConnectionWithEnhancedCleanup();
        debugPrint('Existing connection stopped');
      }
      
      // Extra delay for socket release (handles socket binding conflicts)
      debugPrint('Waiting for socket release...');
      await Future.delayed(_socketReleaseDelay);
      debugPrint('Socket release delay completed');
      
      // Ensure host instance is ready
      if (_host == null) {
        debugPrint('Host instance is null, re-initializing...');
        await _resetPluginInstances();
        _host = FlutterP2pHost();
        await _host?.initialize();
        debugPrint('Host instance re-initialized');
      }
      
      debugPrint('=== CREATING WIFI DIRECT GROUP ===');
      debugPrint('Starting host with advertise: $advertise');
      
      // Create group with proper parameters
      final hostState = await _host?.createGroup(
        advertise: advertise,
        timeout: const Duration(seconds: 30),
      );

      debugPrint('=== HOST STATE RESULT ===');
      debugPrint('Host state received: ${hostState != null}');
      
      if (hostState != null) {
        debugPrint('Host state active: ${hostState.isActive}');
        debugPrint('Host SSID: ${hostState.ssid}');
        debugPrint('Host PSK length: ${hostState.preSharedKey?.length ?? 0}');
        debugPrint('Host IP: ${hostState.hostIpAddress}');
        
        if (hostState.isActive) {
          _role = ConnectionRole.host;
          // Store credentials for convenience
          _hostSSID = hostState.ssid;
          _hostPSK = hostState.preSharedKey;
          _hostIP  = hostState.hostIpAddress;
          
          debugPrint('=== HOST STARTED SUCCESSFULLY ===');
          debugPrint('SSID: $_hostSSID');
          debugPrint('PSK: ${_hostPSK?.isNotEmpty == true ? "***PROVIDED***" : "EMPTY"}');
          debugPrint('Host IP: $_hostIP');
          
          return true;
        } else {
          debugPrint('ERROR: Host state is not active');
          debugPrint('Host state details: $hostState');
          return false;
        }
      } else {
        debugPrint('CRITICAL ERROR: Host creation failed - hostState is null');
        return false;
      }
    } catch (e) {
      debugPrint('=== HOST CREATION ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      
      // Reset role on failure
      _role = ConnectionRole.none;
      
      // Enhanced error analysis
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('bind') || errorMessage.contains('socket')) {
        debugPrint('SOCKET BINDING ERROR detected');
        debugPrint('This usually means:');
        debugPrint('1. Another app is using WiFi Direct');
        debugPrint('2. Previous connection was not properly closed');
        debugPrint('3. System WiFi Direct is in inconsistent state');
        debugPrint('Attempting plugin reset...');
        await _resetPluginInstances();
        _isInitialized = false;
      } else if (errorMessage.contains('permission')) {
        debugPrint('PERMISSION ERROR detected');
        debugPrint('Checking current permissions...');
        await _checkPermissions();
      } else if (errorMessage.contains('wifi') || errorMessage.contains('network')) {
        debugPrint('WIFI/NETWORK ERROR detected');
        debugPrint('Device WiFi state may be incompatible with WiFi Direct');
      } else {
        debugPrint('UNKNOWN ERROR type - this may be a device/system limitation');
      }
      
      return false;
    } finally {
      _isOperationInProgress = false;
      debugPrint('=== HOST OPERATION COMPLETED ===');
      debugPrint('Final role: $_role');
      debugPrint('Operation in progress: $_isOperationInProgress');
    }
  }
  
  // Start scanning for hosts
  Future<List<BleDiscoveredDevice>> scanForHosts({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastOperationTime != null && 
        now.difference(_lastOperationTime!) < _operationDebounceDelay) {
      debugPrint('Scan operation debounced - too soon after last operation');
      return [];
    }
    
    if (_isOperationInProgress) {
      debugPrint('Cannot start scan - another operation is in progress');
      return [];
    }
    
    _isOperationInProgress = true;
    _lastOperationTime = now;
    
    try {
      if (_role != ConnectionRole.none) {
        debugPrint('Stopping existing connection before scanning...');
        await _stopConnectionWithEnhancedCleanup();
        await Future.delayed(Duration(milliseconds: 300));
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
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error scanning for hosts: $e');
      return [];
    } finally {
      _isOperationInProgress = false;
    }
  }
  
  // Connect to a host using discovered device
  Future<bool> connectToHost(BleDiscoveredDevice device) async {
    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastOperationTime != null && 
        now.difference(_lastOperationTime!) < _operationDebounceDelay) {
      debugPrint('Connect operation debounced - too soon after last operation');
      return false;
    }
    
    if (_isOperationInProgress) {
      debugPrint('Cannot connect - another operation is in progress');
      return false;
    }
    
    _isOperationInProgress = true;
    _lastOperationTime = now;
    
    try {
      if (_role != ConnectionRole.none) {
        debugPrint('Stopping existing connection before connecting...');
        await _stopConnectionWithEnhancedCleanup();
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      debugPrint('Connecting to host device: ${device.deviceName}');
      
      await _client?.connectWithDevice(
        device,
        timeout: const Duration(seconds: 30),
      );
      
      _role = ConnectionRole.client;
      debugPrint('Successfully connected to host');
      return true;
    } catch (e) {
      debugPrint('Error connecting to host: $e');
      _role = ConnectionRole.none;
      return false;
    } finally {
      _isOperationInProgress = false;
    }
  }
  
  // Check device WiFi Direct capabilities and system state
  Future<Map<String, dynamic>> checkDeviceCapabilities() async {
    debugPrint('=== CHECKING DEVICE CAPABILITIES ===');
    
    try {
      final wifiStatus = await checkWiFiStatus();
      final locationServiceStatus = await Permission.location.serviceStatus;
      final locationPermission = await Permission.location.status;
      final nearbyWifiPermission = await Permission.nearbyWifiDevices.status;
      
      final capabilities = {
        'wifiEnabled': wifiStatus['hasWiFi'] ?? false,
        'networkAvailable': wifiStatus['hasConnection'] ?? false,
        'locationServiceEnabled': locationServiceStatus.isEnabled,
        'locationPermissionGranted': locationPermission.isGranted,
        'nearbyWifiPermissionGranted': nearbyWifiPermission.isGranted,
        'p2pServiceInitialized': _isInitialized,
        'currentRole': _role.name,
        'systemInfo': {
          'wifiStatus': wifiStatus['status'],
          'needsWiFiEnable': wifiStatus['needsWiFiEnable'],
        }
      };
      
      debugPrint('Device capabilities: $capabilities');
      
      // Analyze readiness for WiFi Direct
      final isReady = capabilities['locationServiceEnabled'] == true &&
                     capabilities['locationPermissionGranted'] == true &&
                     capabilities['p2pServiceInitialized'] == true;
      
      debugPrint('WiFi Direct ready: $isReady');
      
      if (!isReady) {
        final issues = <String>[];
        if (capabilities['locationServiceEnabled'] != true) {
          issues.add('Location services disabled');
        }
        if (capabilities['locationPermissionGranted'] != true) {
          issues.add('Location permission not granted');
        }
        if (capabilities['p2pServiceInitialized'] != true) {
          issues.add('P2P service not initialized');
        }
        debugPrint('Issues preventing WiFi Direct: ${issues.join(", ")}');
      }
      
      return capabilities;
    } catch (e) {
      debugPrint('Error checking device capabilities: $e');
      return {'error': e.toString()};
    }
  }

  // Connect to a host using credentials (SSID and PSK)
  Future<bool> connectWithCredentials(String ssid, String psk) async {
    debugPrint('=== CLIENT CONNECTION REQUEST ===');
    debugPrint('Target SSID: $ssid');
    debugPrint('PSK provided: ${psk.isNotEmpty}');
    debugPrint('Current role: $_role');
    debugPrint('Is initialized: $_isInitialized');
    
    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastOperationTime != null && 
        now.difference(_lastOperationTime!) < _operationDebounceDelay) {
      debugPrint('Connect operation debounced - too soon after last operation');
      return false;
    }
    
    if (_isOperationInProgress) {
      debugPrint('Cannot connect - another operation is in progress');
      return false;
    }
    
    _isOperationInProgress = true;
    _lastOperationTime = now;
    
    try {
      // Check device capabilities first
      debugPrint('=== PRE-CONNECTION CHECKS ===');
      final capabilities = await checkDeviceCapabilities();
      debugPrint('Device capability check completed');
      
      // Check WiFi status before attempting connection
      debugPrint('Checking WiFi status before connection...');
      final wifiStatus = await checkWiFiStatus();
      
      if (wifiStatus['needsWiFiEnable'] == true) {
        debugPrint('WARNING: Device may need WiFi enabled for connection');
        debugPrint('Current status: ${wifiStatus['status']}');
        // Continue anyway - let the system handle WiFi connection
      }
      
      if (wifiStatus['hasWiFi'] == true) {
        debugPrint('Already connected to WiFi: ${wifiStatus['currentSSID']}');
        debugPrint('Will switch to target network: $ssid');
      }
      
      if (_role != ConnectionRole.none) {
        debugPrint('Stopping existing connection before connecting with credentials...');
        await _stopConnectionWithEnhancedCleanup();
        await Future.delayed(Duration(milliseconds: 300));
        debugPrint('Existing connection stopped');
      }
      
      // Ensure client instance is ready
      if (_client == null) {
        debugPrint('Client instance is null, re-initializing...');
        await _resetPluginInstances();
        _client = FlutterP2pClient();
        await _client?.initialize();
        debugPrint('Client instance re-initialized');
      }
      
      debugPrint('=== ATTEMPTING CONNECTION ===');
      debugPrint('Connecting with credentials - SSID: $ssid');
      
      await _client?.connectWithCredentials(
        ssid,
        psk,
        timeout: const Duration(seconds: 30),
      );
      
      _role = ConnectionRole.client;
      debugPrint('=== CLIENT CONNECTION SUCCESSFUL ===');
      debugPrint('Role changed to: ${_role.name}');
      return true;
    } catch (e) {
      debugPrint('=== CLIENT CONNECTION ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      
      // Enhanced error analysis for client connections
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('wifi') || errorMessage.contains('network')) {
        debugPrint('NETWORK-RELATED ERROR detected');
        debugPrint('This usually means:');
        debugPrint('1. WiFi is disabled on your device');
        debugPrint('2. The target network is not in range');
        debugPrint('3. Incorrect SSID or password');
        debugPrint('4. Host device is not broadcasting the network');
      } else if (errorMessage.contains('timeout')) {
        debugPrint('CONNECTION TIMEOUT detected');
        debugPrint('1. Host device may be too far away');
        debugPrint('2. Network credentials may be incorrect');
        debugPrint('3. Host may not be accepting connections');
      } else if (errorMessage.contains('permission')) {
        debugPrint('PERMISSION ERROR detected');
        debugPrint('Re-checking permissions...');
        await _checkPermissions();
      } else {
        debugPrint('UNKNOWN CLIENT ERROR - may be device/system specific');
      }
      
      _role = ConnectionRole.none;
      return false;
    } finally {
      _isOperationInProgress = false;
      debugPrint('=== CLIENT CONNECTION OPERATION COMPLETED ===');
      debugPrint('Final role: $_role');
      debugPrint('Operation in progress: $_isOperationInProgress');
    }
  }
  
  // Stop scanning for hosts
  void stopScan() {
    _client?.stopScan();
  }
  
  // Helper method to reset connection state and clean up resources
  Future<void> _stopConnectionWithEnhancedCleanup() async {
    debugPrint('Stopping connection with enhanced cleanup...');
    
    try {
      // Reset connection role
      _role = ConnectionRole.none;
      
      // Clear connection info
      _hostSSID = null;
      _hostPSK = null;
      _hostIP = null;
      _connectedClients = [];
      _authorizedClients = [];
      _clientInfo = {};
      _availableFolders = [];
      
      if (_host != null) {
        debugPrint('Removing host group...');
        await _host?.removeGroup();
        // Additional wait for native cleanup
        await Future.delayed(Duration(milliseconds: 500));
      } else if (_client != null) {
        debugPrint('Disconnecting client...');
        await _client?.disconnect();
        // Additional wait for native cleanup
        await Future.delayed(Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('Error during enhanced cleanup: $e');
    }
    
    _role = ConnectionRole.none;
    debugPrint('Enhanced cleanup completed');
  }
  
  // Stop connection
  Future<void> stopConnection() async {
    if (_isOperationInProgress) {
      debugPrint('Cannot stop connection - operation in progress');
      return;
    }
    
    await _stopConnectionWithEnhancedCleanup();
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
  
  // Public method to reset the entire P2P service
  Future<void> reset() async {
    debugPrint('Resetting P2P service...');
    _isInitialized = false;
    _isOperationInProgress = false;
    _lastOperationTime = null;
    
    await _resetPluginInstances();
    debugPrint('P2P service reset completed');
  }
  
  // Dispose resources
  void dispose() {
    debugPrint('Disposing P2P service...');
    _stopConnectionWithEnhancedCleanup();
    _host?.dispose();
    _client?.dispose();
    _host = null;
    _client = null;
    
    _connectionStateController.close();
    _clientListController.close();
    _receivedTextController.close();
    _receivedFilesController.close();
    _transferProgressController.close();
    _clientConnectionController.close();
    _folderShareController.close();
    
    _isInitialized = false;
    debugPrint('P2P service disposed');
  }
  
  // Helper methods for app-specific functionality
  
  // Advertise app service using app-specific identifier
  Future<void> _advertiseAppService() async {
    try {
      // Send app identification message to all connected clients
      await sendText('APP_ID:$APP_NAME:$APP_SERVICE_UUID');
      debugPrint('Advertising app service with UUID: $APP_SERVICE_UUID');
    } catch (e) {
      debugPrint('Error advertising app service: $e');
    }
  }
  
  // Notify host about client connection
  Future<void> _notifyHostAboutConnection() async {
    try {
      // Generate a unique client ID for this session
      final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
      
      // Send identification to host with app credentials and client ID
      await sendText('APP_ID:$APP_NAME:$APP_SERVICE_UUID:$clientId:$APP_VERSION');
      
      // Request folder list from host
      await sendText('FOLDER_REQUEST:$clientId');
      debugPrint('Notified host about client connection with ID: $clientId');
    } catch (e) {
      debugPrint('Error notifying host: $e');
    }
  }
  
  // Share available folders with a specific client
  Future<void> _shareAvailableFoldersWithClient(String clientId) async {
    try {
      // Get available folders/files to share
      await _updateAvailableFolders();
      
      // Send folder list to specific client
      await _sendFolderListToClient(clientId);
      debugPrint('Shared folder list with client: $clientId');
    } catch (e) {
      debugPrint('Error sharing folders with client: $e');
    }
  }
  
  // Send folder list to a specific client
  Future<void> _sendFolderListToClient(String clientId) async {
    try {
      final folderListJson = _generateFolderListJson();
      await sendText('FOLDER_LIST:$folderListJson', targetClientId: clientId);
      debugPrint('Sent folder list to client: $clientId');
    } catch (e) {
      debugPrint('Error sending folder list: $e');
    }
  }
  
  // Process received folder list from host
  void _processFolderList(String folderData) {
    try {
      // Parse folder data and update available folders
      // This would normally parse JSON data
      final folders = folderData.split('|').map((folder) {
        final parts = folder.split(':');
        return {
          'id': parts[0],
          'name': parts.length > 1 ? parts[1] : 'Unknown',
          'type': parts.length > 2 ? parts[2] : 'folder',
          'size': parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0,
        };
      }).toList();
      
      _availableFolders = folders;
      
      _folderShareController.add({
        'action': 'folder_list_received',
        'folders': folders,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('Processed folder list: ${folders.length} items');
    } catch (e) {
      debugPrint('Error processing folder list: $e');
    }
  }
  
  // Update available folders by scanning device storage
  Future<void> _updateAvailableFolders() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folders = <Map<String, dynamic>>[];
      
      // Scan for shareable folders and files
      await for (final entity in directory.list(recursive: false)) {
        if (entity is Directory) {
          final stat = await entity.stat();
          folders.add({
            'id': entity.path.hashCode.toString(),
            'name': entity.path.split('/').last,
            'type': 'folder',
            'path': entity.path,
            'size': 0, // Could calculate folder size if needed
            'modified': stat.modified.millisecondsSinceEpoch,
          });
        } else if (entity is File) {
          final stat = await entity.stat();
          folders.add({
            'id': entity.path.hashCode.toString(),
            'name': entity.path.split('/').last,
            'type': 'file',
            'path': entity.path,
            'size': stat.size,
            'modified': stat.modified.millisecondsSinceEpoch,
          });
        }
      }
      
      _availableFolders = folders;
      debugPrint('Updated available folders: ${folders.length} items');
    } catch (e) {
      debugPrint('Error updating available folders: $e');
    }
  }
  
  // Generate folder list JSON for transmission
  String _generateFolderListJson() {
    return _availableFolders.map((folder) {
      return '${folder['id']}:${folder['name']}:${folder['type']}:${folder['size']}';
    }).join('|');
  }
  
  // Public method to share a folder with all clients
  Future<bool> shareFolder(String folderPath) async {
    if (_role != ConnectionRole.host) {
      debugPrint('Only hosts can share folders');
      return false;
    }
    
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        debugPrint('Folder does not exist: $folderPath');
        return false;
      }
      
      // Add folder to available folders
      final stat = await folder.stat();
      final folderInfo = {
        'id': folderPath.hashCode.toString(),
        'name': folderPath.split('/').last,
        'type': 'folder',
        'path': folderPath,
        'size': 0,
        'modified': stat.modified.millisecondsSinceEpoch,
      };
      
      _availableFolders.add(folderInfo);
      
      // Notify all clients about the new folder
      for (final clientId in _connectedClients) {
        await _sendFolderListToClient(clientId);
      }
      
      _folderShareController.add({
        'action': 'folder_shared',
        'folder': folderInfo,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error sharing folder: $e');
      return false;
    }
  }
  
  // Enhanced scanning for app-specific hosts only
  Future<List<Map<String, dynamic>>> scanForAppHosts({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastOperationTime != null && 
        now.difference(_lastOperationTime!) < _operationDebounceDelay) {
      debugPrint('App hosts scan debounced - too soon after last operation');
      return [];
    }
    
    if (_isOperationInProgress) {
      debugPrint('Cannot start app hosts scan - another operation is in progress');
      return [];
    }
    
    _isOperationInProgress = true;
    _lastOperationTime = now;
    
    try {
      if (_role != ConnectionRole.none) {
        debugPrint('Stopping existing connection before scanning for app hosts...');
        await _stopConnectionWithEnhancedCleanup();
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      final appHosts = <Map<String, dynamic>>[];
      final completer = Completer<List<Map<String, dynamic>>>();
      
      // Use the correct startScan method with proper callback
      _client?.startScan(
        (devices) {
          appHosts.clear();
          // Filter devices to only include our app's hosts
          for (final device in devices) {
            // Check if device advertises our app service UUID
            // Note: This is a simplified check - real implementation would 
            // need to examine the device's advertised services
            if (device.deviceName.contains(APP_NAME) == true) {
              appHosts.add({
                'id': device.deviceName ?? 'Unknown', // Use deviceName as fallback for ID
                'name': device.deviceName ?? 'Unknown $APP_NAME Host',
                'rssi': -50, // Default RSSI value as this property may not be available
                'device': device, // Store the actual device for connection
              });
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(appHosts);
          }
        },
        timeout: timeout,
      );
      
      final result = await completer.future;
      debugPrint('Found ${result.length} app-specific hosts');
      return result;
    } catch (e) {
      debugPrint('Error scanning for app hosts: $e');
      return [];
    } finally {
      _isOperationInProgress = false;
    }
  }
  
  // Reset plugin instances
  Future<void> _resetPluginInstances() async {
    await _stopConnectionWithEnhancedCleanup();
    
    // Dispose existing instances
    try {
      await _host?.dispose();
      await _client?.dispose();
    } catch (e) {
      debugPrint('Error disposing plugin instances: $e');
    }
    
    _host = null;
    _client = null;
    _hostSSID = null;
    _hostPSK = null;
    _hostIP = null;
    _connectedClients = [];
    _authorizedClients = [];
    _clientInfo = {};
    _availableFolders = [];
    
    // Reset stream states
    _connectionStateController.add(false);
    _clientListController.add([]);
  }

  // Client verification and authorization methods
  
  /// Initiate the verification process for a newly connected client
  Future<void> _initiateClientVerification(String clientId) async {
    try {
      debugPrint('Initiating verification for client: $clientId');
      
      // Set a timeout for client verification
      Timer(const Duration(seconds: 30), () {
        if (!_authorizedClients.contains(clientId) && _connectedClients.contains(clientId)) {
          _rejectClient(clientId, 'Verification timeout - app not recognized');
        }
      });
      
      // Send verification request to client
      await sendText('VERIFY_APP:$APP_NAME:$APP_SERVICE_UUID', targetClientId: clientId);
    } catch (e) {
      debugPrint('Error initiating client verification: $e');
    }
  }
  
  /// Authorize a client after successful app verification
  void _authorizeClient(String clientId, String appVersion) {
    if (!_authorizedClients.contains(clientId)) {
      _authorizedClients.add(clientId);
      _clientInfo[clientId] = {
        'id': clientId,
        'appName': APP_NAME,
        'appVersion': appVersion,
        'authorizedAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'authorized',
      };
      
      debugPrint('Client $clientId authorized (app version: $appVersion)');
      
      // Notify UI about authorized client
      _clientConnectionController.add({
        'action': 'authorized',
        'clientId': clientId,
        'clientInfo': _clientInfo[clientId],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Auto-share available folders with newly authorized client
      _shareAvailableFoldersWithClient(clientId);
      
      // Update client list
      _clientListController.add(_authorizedClients);
    }
  }
  
  /// Reject a client that failed app verification
  void _rejectClient(String clientId, String reason) {
    debugPrint('Rejecting client $clientId: $reason');
    
    _clientInfo[clientId] = {
      'id': clientId,
      'status': 'rejected',
      'reason': reason,
      'rejectedAt': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Notify UI about rejected client
    _clientConnectionController.add({
      'action': 'rejected',
      'clientId': clientId,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Optionally disconnect the client
    _disconnectClient(clientId);
  }
  
  /// Extract sender ID from a message (simplified implementation)
  String? _extractSenderIdFromMessage(String message) {
    // This is a simplified approach - in a real implementation,
    // you would need to modify the messaging protocol to include sender IDs
    // For now, we'll try to extract it from certain message patterns
    
    if (message.startsWith('CLIENT_MSG:')) {
      final parts = message.split(':');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    
    // If no sender ID found, return null (message will be ignored)
    return null;
  }
  
  /// Disconnect a specific client
  Future<void> _disconnectClient(String clientId) async {
    try {
      // Send disconnect message to client
      await sendText('DISCONNECT:unauthorized', targetClientId: clientId);
      
      // Remove from all tracking lists
      _connectedClients.remove(clientId);
      _authorizedClients.remove(clientId);
      _clientInfo.remove(clientId);
      
      debugPrint('Disconnected unauthorized client: $clientId');
    } catch (e) {
      debugPrint('Error disconnecting client $clientId: $e');
    }
  }
  
  /// Public method to disconnect a specific client (called by provider)
  Future<void> disconnectClient(String clientId) async {
    await _disconnectClient(clientId);
  }
  
  /// Public method to remove a client from tracking
  Future<void> removeClient(String clientId) async {
    try {
      // Remove from all tracking lists
      _connectedClients.remove(clientId);
      _authorizedClients.remove(clientId);
      _clientInfo.remove(clientId);
      
      // Update UI
      _clientListController.add(_authorizedClients);
      
      debugPrint('Removed client from tracking: $clientId');
    } catch (e) {
      debugPrint('Error removing client $clientId: $e');
    }
  }
  
  /// Get list of all clients (including unauthorized ones) for admin purposes
  List<Map<String, dynamic>> getAllClientsInfo() {
    final allClients = <Map<String, dynamic>>[];
    
    for (final clientId in _connectedClients) {
      if (_clientInfo.containsKey(clientId)) {
        allClients.add(_clientInfo[clientId]!);
      } else {
        allClients.add({
          'id': clientId,
          'status': 'pending_verification',
          'connectedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    
    return allClients;
  }
}

// Removed obsolete String extension which masked real plugin API 
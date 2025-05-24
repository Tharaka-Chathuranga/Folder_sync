import 'dart:async';
import 'package:flutter/services.dart';

class WifiDirectDevice {
  final String name;
  final String address;
  final int status;

  WifiDirectDevice({
    required this.name,
    required this.address,
    required this.status,
  });

  factory WifiDirectDevice.fromMap(Map<dynamic, dynamic> map) {
    return WifiDirectDevice(
      name: map['deviceName'] ?? 'Unknown Device',
      address: map['deviceAddress'] ?? '',
      status: map['status'] ?? 0,
    );
  }

  String get statusString {
    switch (status) {
      case 0:
        return 'Connected';
      case 1:
        return 'Invited';
      case 2:
        return 'Failed';
      case 3:
        return 'Available';
      case 4:
        return 'Unavailable';
      default:
        return 'Unknown';
    }
  }

  bool get isAvailable => status == 3;
}

class ConnectionInfo {
  final bool isConnected;
  final bool isGroupOwner;
  final String? groupOwnerAddress;

  ConnectionInfo({
    required this.isConnected,
    required this.isGroupOwner,
    this.groupOwnerAddress,
  });

  factory ConnectionInfo.fromMap(Map<dynamic, dynamic> map) {
    return ConnectionInfo(
      isConnected: map['isConnected'] ?? false,
      isGroupOwner: map['isGroupOwner'] ?? false,
      groupOwnerAddress: map['groupOwnerAddress'],
    );
  }
}

class WifiDirectService {
  static const MethodChannel _channel = MethodChannel('com.example.folder_sync/wifi_direct');
  static const EventChannel _eventChannel = EventChannel('com.example.folder_sync/wifi_direct_events');

  final StreamController<bool> _wifiStateController = StreamController.broadcast();
  final StreamController<List<WifiDirectDevice>> _peersController = StreamController.broadcast();
  final StreamController<ConnectionInfo> _connectionController = StreamController.broadcast();
  final StreamController<WifiDirectDevice> _deviceInfoController = StreamController.broadcast();

  Stream<bool> get wifiStateStream => _wifiStateController.stream;
  Stream<List<WifiDirectDevice>> get peersStream => _peersController.stream;
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;
  Stream<WifiDirectDevice> get deviceInfoStream => _deviceInfoController.stream;

  List<WifiDirectDevice> _peers = [];
  bool _isInitialized = false;
  ConnectionInfo? _connectionInfo;

  List<WifiDirectDevice> get peers => _peers;
  ConnectionInfo? get connectionInfo => _connectionInfo;

  WifiDirectService() {
    _setupEventChannel();
  }

  void _setupEventChannel() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final eventType = event['event'];
        
        switch (eventType) {
          case 'stateChanged':
            final isEnabled = event['isEnabled'] ?? false;
            _wifiStateController.add(isEnabled);
            break;
            
          case 'peersChanged':
            final devices = (event['devices'] as List?)?.map((device) => 
                WifiDirectDevice.fromMap(device)).toList() ?? [];
            _peers = devices;
            _peersController.add(devices);
            break;
            
          case 'connectionChanged':
            final connectionInfo = ConnectionInfo.fromMap(event);
            _connectionInfo = connectionInfo;
            _connectionController.add(connectionInfo);
            break;
            
          case 'deviceChanged':
            final device = WifiDirectDevice.fromMap(event);
            _deviceInfoController.add(device);
            break;
        }
      }
    });
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      final result = await _channel.invokeMethod('initialize');
      _isInitialized = result ?? false;
      return _isInitialized;
    } on PlatformException catch (e) {
      print('Failed to initialize Wi-Fi Direct: ${e.message}');
      return false;
    }
  }

  Future<bool> startDiscovery() async {
    try {
      final result = await _channel.invokeMethod('startDiscovery');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to start discovery: ${e.message}');
      
      // Check for specific error codes
      if (e.code == 'PERMISSION_DENIED') {
        print('Permission denied: ${e.message}');
        // You might want to request permissions again here
      } else if (e.code == 'P2P_UNSUPPORTED') {
        print('Wi-Fi Direct is not supported on this device');
      }
      
      return false;
    } catch (e) {
      print('Unknown error during discovery: $e');
      return false;
    }
  }

  Future<bool> stopDiscovery() async {
    try {
      final result = await _channel.invokeMethod('stopDiscovery');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to stop discovery: ${e.message}');
      return false;
    }
  }

  Future<bool> connectToDevice(String deviceAddress) async {
    try {
      final result = await _channel.invokeMethod('connectToDevice', {
        'deviceAddress': deviceAddress,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to connect to device: ${e.message}');
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to disconnect: ${e.message}');
      return false;
    }
  }

  Future<String?> getDeviceName() async {
    try {
      return await _channel.invokeMethod('getDeviceName');
    } on PlatformException catch (e) {
      print('Failed to get device name: ${e.message}');
      return null;
    }
  }

  void dispose() {
    _wifiStateController.close();
    _peersController.close();
    _connectionController.close();
    _deviceInfoController.close();
  }
} 
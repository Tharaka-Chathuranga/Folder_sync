import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/device_info.dart';
import '../services/device_discovery_service.dart';

class DeviceProvider extends ChangeNotifier {
  final DeviceDiscoveryService _deviceService;
  String? _lastError;
  
  DeviceProvider(this._deviceService) {
    _setupListeners();
  }
  
  // Get discovered devices
  List<DeviceInfo> get discoveredDevices => _deviceService.discoveredDevices;
  
  // Get connected device
  DeviceInfo? get connectedDevice => _deviceService.connectedDevice;
  
  // Get connection state
  ConnectionState get connectionState => _deviceService.connectionState;
  
  // Get last error
  String? get lastError => _lastError;
  
  // Set up event listeners
  void _setupListeners() {
    _deviceService.onDeviceDiscovered = (device) {
      notifyListeners();
    };
    
    _deviceService.onDeviceDisconnected = (device) {
      notifyListeners();
    };
    
    _deviceService.onDeviceConnected = (device) {
      notifyListeners();
    };
    
    _deviceService.onConnectionStateChanged = (state) {
      notifyListeners();
    };
  }
  
  // Start advertising this device
  Future<bool> startAdvertising(String deviceName) async {
    print('Starting advertising with device name: $deviceName');
    _lastError = null;
    
    try {
      final result = await _deviceService.startAdvertising(deviceName);
      print('Advertising result: $result');
      
      if (!result) {
        _lastError = 'Failed to start advertising. Check Wi-Fi and permissions.';
      }
      
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = 'Error during advertising: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Stop advertising
  Future<bool> stopAdvertising() async {
    final result = await _deviceService.stopAdvertising();
    notifyListeners();
    return result;
  }
  
  // Start discovering devices
  Future<bool> startDiscovery() async {
    print('Starting device discovery with retries');
    bool result = false;
    _lastError = null;
    
    // Try up to 3 times with a small delay between attempts
    for (int attempt = 1; attempt <= 3; attempt++) {
      print('Discovery attempt $attempt/3');
      
      try {
        result = await _deviceService.startDiscovery();
        
        if (result) {
          print('Discovery succeeded on attempt $attempt');
          break;
        } else {
          print('Discovery attempt $attempt failed');
          if (attempt == 3) {
            _lastError = 'Failed to discover devices after multiple attempts. Check Wi-Fi and permissions.';
          }
        }
      } on PlatformException catch (e) {
        print('Platform error during discovery: ${e.message}');
        
        if (e.code == 'PERMISSION_DENIED') {
          _lastError = 'Permission denied: ${e.message}';
          break; // Don't retry if permissions are denied
        } else if (e.code == 'P2P_UNSUPPORTED') {
          _lastError = 'Wi-Fi Direct is not supported on this device';
          break; // Don't retry if Wi-Fi Direct is not supported
        } else {
          _lastError = 'Error: ${e.message}';
        }
      } catch (e) {
        print('Error during discovery: $e');
        _lastError = 'Unexpected error: $e';
      }
      
      if (attempt < 3 && !result) {
        print('Waiting before retry...');
        await Future.delayed(Duration(seconds: 2));
      }
    }
    
    print('Final discovery result: $result');
    notifyListeners();
    return result;
  }
  
  // Stop discovering
  Future<bool> stopDiscovery() async {
    final result = await _deviceService.stopDiscovery();
    notifyListeners();
    return result;
  }
  
  // Connect to a device
  Future<bool> connectToDevice(String deviceId) async {
    _lastError = null;
    try {
      final result = await _deviceService.connectToDevice(deviceId);
      if (!result) {
        _lastError = 'Failed to connect to device';
      }
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = 'Error connecting to device: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Disconnect from current device
  Future<bool> disconnect() async {
    final result = await _deviceService.disconnect();
    notifyListeners();
    return result;
  }
  
  // Cleanup resources
  @override
  void dispose() {
    _deviceService.stopAllServices();
    super.dispose();
  }
} 
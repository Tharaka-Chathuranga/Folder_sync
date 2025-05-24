import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/wifi_direct_service.dart';

class WifiDirectProvider extends ChangeNotifier {
  final WifiDirectService _service = WifiDirectService();
  
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _selectedDeviceAddress;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  List<WifiDirectDevice> get discoveredDevices => _service.peers;
  ConnectionInfo? get connectionInfo => _service.connectionInfo;
  String? get selectedDeviceAddress => _selectedDeviceAddress;
  WifiDirectService get service => _service;
  
  // Stream getters
  Stream<bool> get wifiStateStream => _service.wifiStateStream;
  Stream<List<WifiDirectDevice>> get peersStream => _service.peersStream;
  Stream<ConnectionInfo> get connectionStream => _service.connectionStream;
  
  WifiDirectProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await requestPermissions();
    final result = await _service.initialize();
    _isInitialized = result;
    notifyListeners();
  }
  
  Future<bool> requestPermissions() async {
    // List all required permissions
    List<Permission> permissions = [];
    
    // Location permissions - essential for Wi-Fi Direct on all Android versions
    permissions.add(Permission.location);
    permissions.add(Permission.locationAlways);
    permissions.add(Permission.locationWhenInUse);
    
    // Storage permissions - for file access
    permissions.add(Permission.storage);
    
    // Wi-Fi and network permissions are handled in the manifest
    
    // Bluetooth permissions based on Android version
    if (Platform.isAndroid) {
      try {
        int androidVersion = int.parse(Platform.operatingSystemVersion.split(' ').last);
        if (androidVersion >= 12) {
          // For Android 12+ (API 31+)
          permissions.add(Permission.bluetoothScan);
          permissions.add(Permission.bluetoothConnect);
          permissions.add(Permission.bluetoothAdvertise);
        } else {
          // For older Android versions
          permissions.add(Permission.bluetooth);
        }
        
        // Try to add nearby devices permission for Android 13+
        if (androidVersion >= 13) {
          try {
            permissions.add(Permission.nearbyWifiDevices);
          } catch (e) {
            print('nearbyWifiDevices permission not available: $e');
          }
        }
      } catch (e) {
        // If we can't determine the version, add all Bluetooth permissions
        permissions.add(Permission.bluetooth);
        permissions.add(Permission.bluetoothScan);
        permissions.add(Permission.bluetoothConnect);
        permissions.add(Permission.bluetoothAdvertise);
        
        // Try to add nearby devices permission
        try {
          permissions.add(Permission.nearbyWifiDevices);
        } catch (e) {
          print('nearbyWifiDevices permission not available: $e');
        }
      }
    }
    
    // Request all permissions
    for (var permission in permissions) {
      try {
        final status = await permission.request();
        print('${permission.toString()}: ${status.toString()}');
      } catch (e) {
        print('Error requesting ${permission.toString()}: $e');
      }
    }
    
    // Check if critical permissions are granted
    final locationStatus = await Permission.location.status;
    final storageStatus = await Permission.storage.status;
    
    // Log all permission statuses
    print('Location permission: ${locationStatus.toString()}');
    print('Storage permission: ${storageStatus.toString()}');
    
    // Return true if critical permissions are granted
    return locationStatus.isGranted && storageStatus.isGranted;
  }
  
  Future<bool> startDiscovery() async {
    if (!_isInitialized) {
      await _initialize();
    }
    
    _isScanning = true;
    notifyListeners();
    
    final result = await _service.startDiscovery();
    
    if (!result) {
      _isScanning = false;
      notifyListeners();
    }
    
    return result;
  }
  
  Future<bool> stopDiscovery() async {
    final result = await _service.stopDiscovery();
    _isScanning = false;
    notifyListeners();
    return result;
  }
  
  Future<bool> connectToDevice(String deviceAddress) async {
    _isConnecting = true;
    _selectedDeviceAddress = deviceAddress;
    notifyListeners();
    
    final result = await _service.connectToDevice(deviceAddress);
    
    _isConnecting = false;
    if (!result) {
      _selectedDeviceAddress = null;
    }
    
    notifyListeners();
    return result;
  }
  
  Future<bool> disconnect() async {
    final result = await _service.disconnect();
    _selectedDeviceAddress = null;
    notifyListeners();
    return result;
  }
  
  Future<String?> getDeviceName() async {
    return await _service.getDeviceName();
  }
  
  WifiDirectDevice? getSelectedDevice() {
    if (_selectedDeviceAddress == null) return null;
    
    for (var device in discoveredDevices) {
      if (device.address == _selectedDeviceAddress) {
        return device;
      }
    }
    
    return null;
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
} 
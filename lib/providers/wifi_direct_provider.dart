import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Manual permission check using platform channel as fallback
  Future<bool> _checkNearbyWifiDevicesManually() async {
    if (!Platform.isAndroid) return true;
    
    try {
      const platform = MethodChannel('com.example.folder_sync/permissions');
      final bool granted = await platform.invokeMethod('checkNearbyWifiDevices');
      print('Manual nearbyWifiDevices check result: $granted');
      return granted;
    } catch (e) {
      print('Manual permission check failed: $e');
      // If manual check fails, assume it's granted (for older Android versions)
      return true;
    }
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
        // Try to add nearby devices permission for Android 13+
        try {
          print('Attempting to add nearbyWifiDevices permission...');
          final nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
          print('nearbyWifiDevices permission status check: ${nearbyWifiStatus.name}');
          permissions.add(Permission.nearbyWifiDevices);
          print('Successfully added nearbyWifiDevices permission to request list');
        } catch (e) {
          print('nearbyWifiDevices permission not available or error: $e');
          // On older versions or if permission is not available, ensure location permission is requested
          if (!permissions.contains(Permission.location)) {
            permissions.add(Permission.location);
          }
        }
        
        // Bluetooth permissions
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
      } catch (e) {
        // If we can't determine the version, add all Bluetooth permissions
        permissions.add(Permission.bluetooth);
        permissions.add(Permission.bluetoothScan);
        permissions.add(Permission.bluetoothConnect);
        permissions.add(Permission.bluetoothAdvertise);
        
        // Also ensure location permission for fallback
        if (!permissions.contains(Permission.location)) {
          permissions.add(Permission.location);
        }
      }
    }
    
    print('=== REQUESTING PERMISSIONS ===');
    print('Total permissions to request: ${permissions.length}');
    
    // Request permissions individually to better handle errors
    bool hasAllCritical = true;
    Map<Permission, PermissionStatus> results = {};
    
    for (var permission in permissions) {
      try {
        print('Requesting ${permission.toString()}...');
        final status = await permission.request();
        results[permission] = status;
        print('${permission.toString()}: ${status.toString()}');
        
        // Check if critical permissions are denied
        if (permission == Permission.location || 
            permission == Permission.nearbyWifiDevices) {
          if (!status.isGranted) {
            hasAllCritical = false;
            print('CRITICAL: ${permission.toString()} was denied');
          }
        }
      } catch (e) {
        print('Error requesting ${permission.toString()}: $e');
        results[permission] = PermissionStatus.denied;
        
        // If this is a critical permission, mark as failed
        if (permission == Permission.location || 
            permission == Permission.nearbyWifiDevices) {
          hasAllCritical = false;
        }
      }
    }
    
    // Special handling for nearbyWifiDevices permission
    bool nearbyWifiGranted = false;
    try {
      final nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
      nearbyWifiGranted = nearbyWifiStatus.isGranted;
      print('Final nearbyWifiDevices status: ${nearbyWifiStatus.name}');
    } catch (e) {
      print('Could not check nearbyWifiDevices final status: $e');
      // On older Android versions, this is expected
      nearbyWifiGranted = true; // Consider it "granted" if not available
    }
    
    // Check if critical permissions are granted
    final locationStatus = await Permission.location.status;
    final storageStatus = await Permission.storage.status;
    
    // Log all permission statuses
    print('=== FINAL PERMISSION STATUS ===');
    print('Location permission: ${locationStatus.toString()}');
    print('Storage permission: ${storageStatus.toString()}');
    print('Nearby WiFi devices: ${nearbyWifiGranted ? "granted" : "denied"}');
    
    // Return true if we have the minimum required permissions
    bool hasMinimumPermissions = locationStatus.isGranted && storageStatus.isGranted;
    
    print('Has minimum required permissions: $hasMinimumPermissions');
    print('Has all critical permissions: $hasAllCritical');
    
    return hasMinimumPermissions;
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
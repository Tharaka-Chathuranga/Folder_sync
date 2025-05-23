class DeviceInfo {
  final String id;
  final String name;
  final String deviceType;
  bool isAvailable;
  bool isConnected;
  bool isConnecting;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.deviceType,
    this.isAvailable = false,
    this.isConnected = false,
    this.isConnecting = false,
  });

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? deviceType,
    bool? isAvailable,
    bool? isConnected,
    bool? isConnecting,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      isAvailable: isAvailable ?? this.isAvailable,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }

  @override
  String toString() {
    return 'DeviceInfo{id: $id, name: $name, deviceType: $deviceType, isAvailable: $isAvailable, isConnected: $isConnected}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceType': deviceType,
      'isAvailable': isAvailable,
      'isConnected': isConnected,
      'isConnecting': isConnecting,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'],
      name: json['name'],
      deviceType: json['deviceType'],
      isAvailable: json['isAvailable'] ?? false,
      isConnected: json['isConnected'] ?? false,
      isConnecting: json['isConnecting'] ?? false,
    );
  }
} 
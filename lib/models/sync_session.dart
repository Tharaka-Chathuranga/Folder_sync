import 'file_item.dart';

class SyncSession {
  final String id;
  final String deviceId;
  final String deviceName;
  final String sourcePath;
  final String targetPath;
  final bool twoWaySync;
  bool isActive;
  final DateTime startTime;
  DateTime? endTime;
  List<FileItem> files;

  SyncSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.sourcePath,
    required this.targetPath,
    required this.isActive,
    required this.startTime,
    this.endTime,
    required this.twoWaySync,
    required this.files,
  });

  SyncSession copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? sourcePath,
    String? targetPath,
    bool? twoWaySync,
    bool? isActive,
    DateTime? startTime,
    DateTime? endTime,
    List<FileItem>? files,
  }) {
    return SyncSession(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      sourcePath: sourcePath ?? this.sourcePath,
      targetPath: targetPath ?? this.targetPath,
      twoWaySync: twoWaySync ?? this.twoWaySync,
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      files: files ?? this.files,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'sourcePath': sourcePath,
      'targetPath': targetPath,
      'twoWaySync': twoWaySync,
      'isActive': isActive,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'files': files.map((file) => file.toJson()).toList(),
    };
  }

  factory SyncSession.fromJson(Map<String, dynamic> json) {
    return SyncSession(
      id: json['id'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      sourcePath: json['sourcePath'],
      targetPath: json['targetPath'],
      twoWaySync: json['twoWaySync'],
      isActive: json['isActive'],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'])
          : null,
      files: (json['files'] as List)
          .map((fileJson) => FileItem.fromJson(fileJson))
          .toList(),
    );
  }
} 
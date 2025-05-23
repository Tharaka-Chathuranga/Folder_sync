class FileItem {
  final String path;
  final String absolutePath;
  final int size;
  final DateTime lastModified;
  final String mimeType;
  final String checksum;
  bool selected;
  double syncProgress;
  String status;

  FileItem({
    required this.path,
    required this.absolutePath,
    required this.size,
    required this.lastModified,
    required this.mimeType,
    this.checksum = '',
    this.selected = true,
    this.syncProgress = 0.0,
    this.status = 'pending',
  });

  FileItem copyWith({
    String? path,
    String? absolutePath,
    int? size,
    DateTime? lastModified,
    String? mimeType,
    String? checksum,
    bool? selected,
    double? syncProgress,
    String? status,
  }) {
    return FileItem(
      path: path ?? this.path,
      absolutePath: absolutePath ?? this.absolutePath,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      mimeType: mimeType ?? this.mimeType,
      checksum: checksum ?? this.checksum,
      selected: selected ?? this.selected,
      syncProgress: syncProgress ?? this.syncProgress,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'FileItem{path: $path, size: $size, lastModified: $lastModified}';
  }

  // For comparing files
  bool isSameContent(FileItem other) {
    if (checksum.isNotEmpty && other.checksum.isNotEmpty) {
      return checksum == other.checksum;
    }
    return size == other.size && lastModified == other.lastModified;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'absolutePath': absolutePath,
      'size': size,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'mimeType': mimeType,
      'checksum': checksum,
      'selected': selected,
      'syncProgress': syncProgress,
      'status': status,
    };
  }

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      path: json['path'],
      absolutePath: json['absolutePath'],
      size: json['size'],
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['lastModified']),
      mimeType: json['mimeType'],
      checksum: json['checksum'],
      selected: json['selected'] ?? true,
      syncProgress: json['syncProgress'] ?? 0.0,
      status: json['status'] ?? 'pending',
    );
  }
} 
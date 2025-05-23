import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_item.dart';

class FileService {
  /// Request storage permissions required for file operations
  Future<bool> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        // Also request manage external storage for Android 11+
        status = await Permission.manageExternalStorage.request();
      }
    }
    return status.isGranted;
  }

  /// Get app-specific directory for synced files
  Future<Directory> getSyncDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final syncDir = Directory('${appDocDir.path}/synced_files');
    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }
    return syncDir;
  }

  /// Get all files in a directory recursively
  Future<List<FileItem>> getFilesInDirectory(String directoryPath) async {
    final files = <FileItem>[];
    final directory = Directory(directoryPath);
    
    if (!await directory.exists()) {
      return files;
    }
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: directoryPath);
          final lastModified = await entity.lastModified();
          final size = await entity.length();
          final mimeType = lookupMimeType(entity.path) ?? 'application/octet-stream';
          
          files.add(FileItem(
            path: relativePath,
            absolutePath: entity.path,
            size: size,
            lastModified: lastModified,
            mimeType: mimeType,
            checksum: '', // We'll compute this on demand
          ));
        }
      }
    } catch (e) {
      print('Error reading directory: $e');
    }
    
    return files;
  }
  
  /// Calculate file checksum to determine if file has changed
  Future<String> calculateChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }
    
    try {
      final fileBytes = await file.readAsBytes();
      final digest = md5.convert(fileBytes);
      return digest.toString();
    } catch (e) {
      print('Error calculating checksum: $e');
      return '';
    }
  }
  
  /// Compare two file lists and identify changes (added, modified, deleted)
  Map<String, List<FileItem>> compareFileLists(
      List<FileItem> sourceFiles, List<FileItem> targetFiles) {
    final addedOrModified = <FileItem>[];
    final unchanged = <FileItem>[];
    final deleted = <FileItem>[];
    
    // Create map for quick lookup of target files
    final targetFileMap = {for (var file in targetFiles) file.path: file};
    final sourceFileMap = {for (var file in sourceFiles) file.path: file};
    
    // Find added or modified files
    for (var sourceFile in sourceFiles) {
      final targetFile = targetFileMap[sourceFile.path];
      
      if (targetFile == null) {
        // File doesn't exist in target, add it
        addedOrModified.add(sourceFile);
      } else if (targetFile.lastModified.isBefore(sourceFile.lastModified) || 
                 targetFile.size != sourceFile.size) {
        // File exists but is different (modification time or size), update it
        addedOrModified.add(sourceFile);
      } else {
        // File is the same
        unchanged.add(sourceFile);
      }
    }
    
    // Find deleted files (files in target that don't exist in source)
    for (var targetFile in targetFiles) {
      if (!sourceFileMap.containsKey(targetFile.path)) {
        deleted.add(targetFile);
      }
    }
    
    return {
      'added_modified': addedOrModified,
      'unchanged': unchanged,
      'deleted': deleted,
    };
  }
  
  /// Copy a file to the destination path
  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);
      
      // Create directory structure if it doesn't exist
      final destinationDir = path.dirname(destinationPath);
      await Directory(destinationDir).create(recursive: true);
      
      // Copy the file
      await sourceFile.copy(destinationPath);
      return true;
    } catch (e) {
      print('Error copying file: $e');
      return false;
    }
  }
  
  /// Delete a file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
} 
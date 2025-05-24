import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/wifi_direct_provider.dart';
import '../services/file_transfer_service.dart';
import '../services/wifi_direct_service.dart';

class FileTransferScreen extends StatefulWidget {
  final WifiDirectDevice connectedDevice;
  
  const FileTransferScreen({
    Key? key,
    required this.connectedDevice,
  }) : super(key: key);

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  late FileTransferService _fileTransferService;
  bool _isReceiving = false;
  bool _isSending = false;
  double _progress = 0.0;
  String? _statusMessage;
  String? _selectedFilePath;
  
  @override
  void initState() {
    super.initState();
    _initializeFileTransfer();
  }
  
  void _initializeFileTransfer() {
    final wifiDirectService = Provider.of<WifiDirectProvider>(context, listen: false).service;
    _fileTransferService = FileTransferService(wifiDirectService);
    
    // Set up callbacks
    _fileTransferService.onProgressChanged = (progress) {
      setState(() {
        _progress = progress;
      });
    };
    
    _fileTransferService.onTransferComplete = (filePath) {
      setState(() {
        _isSending = false;
        _isReceiving = false;
        _statusMessage = 'Transfer complete: $filePath';
      });
      
      _showSnackBar('Transfer complete!');
    };
    
    _fileTransferService.onTransferError = (error) {
      setState(() {
        _isSending = false;
        _isReceiving = false;
        _statusMessage = 'Error: $error';
      });
      
      _showSnackBar('Transfer error: $error');
    };
    
    // Start receiving files if we are the group owner
    final connectionInfo = wifiDirectService.connectionInfo;
    if (connectionInfo != null && connectionInfo.isGroupOwner) {
      _startReceiving();
    }
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  Future<void> _selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }
  
  Future<void> _sendFile() async {
    if (_selectedFilePath == null) {
      _showSnackBar('Please select a file first');
      return;
    }
    
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending file...';
      _progress = 0.0;
    });
    
    await _fileTransferService.sendFile(_selectedFilePath!);
  }
  
  Future<void> _startReceiving() async {
    setState(() {
      _isReceiving = true;
      _statusMessage = 'Waiting for files...';
    });
    
    await _fileTransferService.startReceiving();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connected device info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to: ${widget.connectedDevice.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${widget.connectedDevice.statusString}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Selected file info
            if (_selectedFilePath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected File:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFilePath!.split('/').last,
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        _selectedFilePath!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // File selection button
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Select File to Send'),
              onPressed: _isSending ? null : _selectFile,
            ),
            
            const SizedBox(height: 8),
            
            // Send button
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: (_isSending || _selectedFilePath == null) ? null : _sendFile,
            ),
            
            const SizedBox(height: 16),
            
            // Receive button (only for non-group owners)
            Consumer<WifiDirectProvider>(
              builder: (context, provider, child) {
                final connectionInfo = provider.service.connectionInfo;
                
                if (connectionInfo == null || connectionInfo.isGroupOwner) {
                  return const SizedBox.shrink();
                }
                
                return ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Start Receiving Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isReceiving ? null : _startReceiving,
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Status and progress
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 8),
            
            if (_isSending || _isReceiving)
              _progress >= 0
                  ? LinearProgressIndicator(value: _progress)
                  : const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
} 
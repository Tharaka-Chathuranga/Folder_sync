# App-Level Client Authentication System

## Overview

This document explains how the FolderSync app implements app-level authentication to ensure that only clients using the same FolderSync application can connect to a host, preventing other random devices from joining the Wi-Fi Direct network.

## How It Works

### 1. App Identification Constants

The system uses unique identifiers to distinguish FolderSync clients from other devices:

```dart
const String APP_SERVICE_UUID = "12345678-1234-5678-9abc-123456789012";
const String APP_NAME = "FolderSync";
const String APP_VERSION = "1.0.0";
```

### 2. Client Connection Flow

When a client connects to the host's Wi-Fi Direct network:

1. **Initial Connection**: Client connects to the Wi-Fi Direct hotspot using SSID/password
2. **App Verification**: Host initiates verification by sending `VERIFY_APP` message
3. **Client Response**: Client responds with app credentials: `APP_ID:FolderSync:UUID:ClientID:Version`
4. **Authorization Decision**: Host validates credentials and either authorizes or rejects the client
5. **Result**: Only authorized clients can access folders and file sharing features

### 3. Host-Side Implementation

#### Client State Tracking

The host maintains three lists:
- `_connectedClients`: All connected devices (including unauthorized)
- `_authorizedClients`: Only app-verified clients
- `_clientInfo`: Detailed information about each client's status

#### Verification Process

```dart
// When a new client connects
_initiateClientVerification(clientId);

// Client verification with timeout
Timer(const Duration(seconds: 30), () {
  if (!_authorizedClients.contains(clientId)) {
    _rejectClient(clientId, 'Verification timeout');
  }
});
```

#### Message Filtering

```dart
// Only process messages from authorized clients
if (senderId != null && _authorizedClients.contains(senderId)) {
  // Process message
} else {
  debugPrint('Ignoring message from unauthorized client: $senderId');
}
```

### 4. Client-Side Implementation

#### App Identification

```dart
// Send app credentials to host
await sendText('APP_ID:$APP_NAME:$APP_SERVICE_UUID:$clientId:$APP_VERSION');
```

#### Verification Response

```dart
// Respond to host verification requests
if (message.startsWith('VERIFY_APP:')) {
  final parts = message.split(':');
  if (parts[1] == APP_NAME && parts[2] == APP_SERVICE_UUID) {
    _notifyHostAboutConnection(); // Send credentials
  }
}
```

### 5. UI Integration

#### Host Screen Enhancements

The HostScreen now displays:
- **Authorized clients**: Green status with app version
- **Pending verification**: Orange status with "Verifying app..." message
- **Rejected clients**: Red status with rejection reason
- **Client management**: Disconnect/remove unauthorized clients

#### Client Status Indicators

```dart
Widget _buildClientTile(Map<String, dynamic> clientInfo) {
  final status = clientInfo['status'];
  switch (status) {
    case 'authorized':
      return ListTile(
        leading: Icon(Icons.verified_user, color: Colors.green),
        title: Text('Authorized'),
        // ... send file option
      );
    case 'pending_verification':
      return ListTile(
        leading: Icon(Icons.pending, color: Colors.orange),
        title: Text('Verifying app...'),
        // ... disconnect option
      );
    case 'rejected':
      return ListTile(
        leading: Icon(Icons.block, color: Colors.red),
        title: Text('Rejected: ${reason}'),
        // ... remove option
      );
  }
}
```

### 6. Security Features

#### Automatic Rejection

- **Timeout Protection**: Clients have 30 seconds to respond with valid credentials
- **Invalid Credentials**: Clients with wrong app name/UUID are automatically rejected
- **Version Tracking**: App version is stored for compatibility checking

#### Message Filtering

- **Host-side**: Only processes messages from authorized clients
- **Folder Sharing**: Only authorized clients receive folder lists
- **File Transfer**: Only authorized clients can send/receive files

#### Client Management

- **Disconnect**: Hosts can manually disconnect suspicious clients
- **Remove**: Hosts can remove rejected clients from the display
- **Status Tracking**: Real-time status updates for all connected devices

### 7. Implementation Benefits

1. **Security**: Prevents unauthorized devices from accessing shared folders
2. **User Experience**: Clear visual indication of client authorization status
3. **Compatibility**: Version tracking for future compatibility checks
4. **Management**: Host can control which devices have access
5. **Automated**: No manual approval required for legitimate app clients

### 8. Error Handling

#### Common Rejection Reasons

- `"Invalid app credentials"`: Wrong app name or UUID
- `"Verification timeout - app not recognized"`: Client didn't respond in time
- `"Unknown app"`: Generic rejection for unrecognized clients

#### Recovery Mechanisms

- **Auto-retry**: Clients can reconnect and retry verification
- **Manual removal**: Hosts can clear rejected clients and allow reconnection
- **Timeout reset**: Each new connection attempt gets a fresh verification window

### 9. Customization Options

To customize the authentication system:

1. **Change App Identifiers**: Modify `APP_SERVICE_UUID` and `APP_NAME` constants
2. **Adjust Timeout**: Change verification timeout duration
3. **Add Version Checks**: Implement minimum version requirements
4. **Enhanced Security**: Add encryption to app identification messages

### 10. Testing the System

To test app-level authentication:

1. **Start Host**: Use the "Start as Host" option
2. **Connect with App**: Use another device with the FolderSync app
3. **Connect with Other Device**: Try connecting a regular device to the Wi-Fi hotspot
4. **Observe Results**: Only the FolderSync app should be authorized

The regular device will connect to the Wi-Fi but won't appear in the authorized clients list and won't be able to access any app features.

## Conclusion

This app-level authentication system ensures that your FolderSync network remains secure and only allows connections from devices running the same application, preventing unauthorized access while maintaining ease of use for legitimate clients. 
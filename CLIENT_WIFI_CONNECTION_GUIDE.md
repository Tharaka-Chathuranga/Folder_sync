# Client WiFi Connection Guide

## How WiFi Connection Works in FolderSync

When you connect as a **Client** to a host device, your phone connects to the host's WiFi Direct network. This is similar to connecting to a regular WiFi hotspot, but it's created specifically for device-to-device communication.

## Connection Methods

### 1. QR Code Connection (Recommended)
1. Host device shows a QR code with network credentials
2. Scan the QR code with your camera
3. App automatically connects to the host's network

### 2. Manual Connection
1. Host provides SSID (network name) and password
2. Enter these credentials manually in the app
3. App connects to the host's network

### 3. Bluetooth LE Scanning
1. App scans for nearby host devices using Bluetooth
2. Select a host from the discovered list
3. App connects to the selected host

## WiFi Requirements

### Before Connecting:
- **WiFi must be enabled** on your device
- You should be within range of the host device (typically 10-30 meters)
- Location permissions must be granted (required for WiFi scanning)

### During Connection:
- Your device will **switch WiFi networks** to connect to the host
- You may temporarily lose internet access while connected to the host
- The connection creates a direct link between your device and the host

### After Connection:
- You can share files directly with the host and other connected clients
- All communication happens through the host's WiFi Direct network
- Only devices running the FolderSync app are authorized to access files

## Troubleshooting Common Issues

### "WiFi Needs to be Enabled" Warning

**Problem**: App shows a red warning that WiFi needs to be enabled.

**Solution**:
1. Open your device's Settings
2. Go to WiFi settings
3. Turn on WiFi
4. Return to the FolderSync app
5. Tap "Refresh" in the WiFi status card

### Connection Fails

**Problem**: App shows "Connection failed" error.

**Solutions**:
1. **Check WiFi**: Ensure WiFi is enabled on your device
2. **Check Range**: Move closer to the host device
3. **Verify Credentials**: Double-check the SSID and password
4. **Restart WiFi**: Turn WiFi off and on again
5. **Retry Connection**: Wait a few seconds and try connecting again

### "Network-related Error"

**Problem**: App shows detailed network troubleshooting dialog.

**Solutions**:
1. Follow the troubleshooting steps shown in the dialog
2. Use the "Refresh" button to check WiFi status again
3. Try connecting to the host's WiFi network manually first through device settings

## Understanding WiFi Status Indicators

### Green WiFi Icon ✅
- **WiFi Connected**: Your device is connected to a WiFi network
- Ready to connect to hosts or you may already be connected

### Red WiFi Icon ❌
- **WiFi Disabled**: WiFi is turned off on your device
- **Action Required**: Enable WiFi before attempting connections

### Orange WiFi Icon ⚠️
- **Network Available**: You have some network connectivity (like mobile data)
- WiFi may not be connected, but connections might still work

## Best Practices

### For Optimal Connection:
1. **Enable WiFi first** before opening the FolderSync app
2. **Stay close** to the host device during connection
3. **Avoid interference** from other WiFi networks when possible
4. **Keep the app open** during file transfers

### Security Notes:
- Only FolderSync apps can connect to each other
- Other devices connecting to the host's WiFi won't see your files
- All connections are authenticated at the app level

## Manual WiFi Connection (Alternative Method)

If the app connection fails, you can try connecting manually:

1. **Find the Network**:
   - Open WiFi settings on your device
   - Look for a network with the SSID provided by the host
   - It might appear as "DIRECT-xx-..." or similar

2. **Connect Manually**:
   - Tap on the host's network name
   - Enter the password provided by the host
   - Wait for connection to establish

3. **Return to App**:
   - Go back to the FolderSync app
   - The app should detect the connection automatically
   - Try the file sharing features

## Connection Status Messages

| Message | Meaning | Action |
|---------|---------|--------|
| "WiFi Connected" | ✅ Ready to connect | Proceed with connection |
| "WiFi Needs to be Enabled" | ❌ WiFi is off | Enable WiFi in settings |
| "Network Available" | ⚠️ Mobile data only | Enable WiFi for best results |
| "Connected as Client" | ✅ Successfully connected | Ready for file sharing |

Remember: The FolderSync app creates secure, app-level connections that only allow other FolderSync users to access your shared files! 
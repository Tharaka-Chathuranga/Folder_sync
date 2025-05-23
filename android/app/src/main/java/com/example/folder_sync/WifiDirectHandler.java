package com.example.folder_sync;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.NetworkInfo;
import android.net.wifi.p2p.WifiP2pConfig;
import android.net.wifi.p2p.WifiP2pDevice;
import android.net.wifi.p2p.WifiP2pDeviceList;
import android.net.wifi.p2p.WifiP2pInfo;
import android.net.wifi.p2p.WifiP2pManager;
import android.os.Build;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;

public class WifiDirectHandler implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "WifiDirectHandler";
    
    private final Context context;
    private WifiP2pManager manager;
    private WifiP2pManager.Channel channel;
    private BroadcastReceiver receiver;
    private final IntentFilter intentFilter = new IntentFilter();
    private List<WifiP2pDevice> peers = new ArrayList<>();
    private EventChannel.EventSink eventSink;
    
    public WifiDirectHandler(Context context) {
        this.context = context;
        
        // Initialize WifiP2pManager
        manager = (WifiP2pManager) context.getSystemService(Context.WIFI_P2P_SERVICE);
        channel = manager.initialize(context, Looper.getMainLooper(), null);
        
        // Set up intent filter for Wi-Fi P2P intents
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION);
        
        // Create and register broadcast receiver
        receiver = new WiFiDirectBroadcastReceiver();
    }
    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initialize":
                initialize(result);
                break;
            case "startDiscovery":
                startDiscovery(result);
                break;
            case "stopDiscovery":
                stopDiscovery(result);
                break;
            case "connectToDevice":
                String deviceAddress = call.argument("deviceAddress");
                connectToDevice(deviceAddress, result);
                break;
            case "disconnect":
                disconnect(result);
                break;
            case "getDeviceName":
                getDeviceName(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }
    
    private void initialize(Result result) {
        try {
            context.registerReceiver(receiver, intentFilter);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Failed to initialize Wi-Fi Direct: " + e.getMessage());
            result.error("INIT_FAILED", "Failed to initialize Wi-Fi Direct", e.getMessage());
        }
    }
    
    private void startDiscovery(Result result) {
        manager.discoverPeers(channel, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                Log.d(TAG, "Discovery started successfully");
                result.success(true);
            }
            
            @Override
            public void onFailure(int reason) {
                Log.e(TAG, "Discovery failed with reason: " + reason);
                result.error("DISCOVERY_FAILED", "Failed to start discovery", String.valueOf(reason));
            }
        });
    }
    
    private void stopDiscovery(Result result) {
        manager.stopPeerDiscovery(channel, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                result.success(true);
            }
            
            @Override
            public void onFailure(int reason) {
                result.error("STOP_DISCOVERY_FAILED", "Failed to stop discovery", String.valueOf(reason));
            }
        });
    }
    
    private void connectToDevice(String deviceAddress, Result result) {
        WifiP2pConfig config = new WifiP2pConfig();
        config.deviceAddress = deviceAddress;
        
        manager.connect(channel, config, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                result.success(true);
            }
            
            @Override
            public void onFailure(int reason) {
                result.error("CONNECTION_FAILED", "Failed to connect to device", String.valueOf(reason));
            }
        });
    }
    
    private void disconnect(Result result) {
        manager.removeGroup(channel, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                result.success(true);
            }
            
            @Override
            public void onFailure(int reason) {
                result.error("DISCONNECT_FAILED", "Failed to disconnect", String.valueOf(reason));
            }
        });
    }
    
    private void getDeviceName(Result result) {
        manager.requestDeviceInfo(channel, info -> {
            if (info != null) {
                result.success(info.deviceName);
            } else {
                result.error("DEVICE_INFO_FAILED", "Failed to get device info", null);
            }
        });
    }
    
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        this.eventSink = events;
    }
    
    @Override
    public void onCancel(Object arguments) {
        this.eventSink = null;
    }
    
    public void cleanup() {
        try {
            context.unregisterReceiver(receiver);
        } catch (Exception e) {
            Log.e(TAG, "Error unregistering receiver: " + e.getMessage());
        }
    }
    
    private class WiFiDirectBroadcastReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            
            if (eventSink == null) {
                return;
            }
            
            if (WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION.equals(action)) {
                int state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1);
                boolean isEnabled = state == WifiP2pManager.WIFI_P2P_STATE_ENABLED;
                
                Map<String, Object> stateMap = new HashMap<>();
                stateMap.put("event", "stateChanged");
                stateMap.put("isEnabled", isEnabled);
                eventSink.success(stateMap);
                
            } else if (WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION.equals(action)) {
                manager.requestPeers(channel, peerList -> {
                    peers.clear();
                    peers.addAll(peerList.getDeviceList());
                    
                    List<Map<String, Object>> devicesList = new ArrayList<>();
                    for (WifiP2pDevice device : peers) {
                        Map<String, Object> deviceMap = new HashMap<>();
                        deviceMap.put("deviceName", device.deviceName);
                        deviceMap.put("deviceAddress", device.deviceAddress);
                        deviceMap.put("status", device.status);
                        devicesList.add(deviceMap);
                    }
                    
                    Map<String, Object> peersMap = new HashMap<>();
                    peersMap.put("event", "peersChanged");
                    peersMap.put("devices", devicesList);
                    eventSink.success(peersMap);
                });
                
            } else if (WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION.equals(action)) {
                NetworkInfo networkInfo = intent.getParcelableExtra(WifiP2pManager.EXTRA_NETWORK_INFO);
                if (networkInfo != null && networkInfo.isConnected()) {
                    manager.requestConnectionInfo(channel, info -> {
                        Map<String, Object> connectionMap = new HashMap<>();
                        connectionMap.put("event", "connectionChanged");
                        connectionMap.put("isConnected", true);
                        connectionMap.put("isGroupOwner", info.isGroupOwner);
                        connectionMap.put("groupOwnerAddress", info.groupOwnerAddress != null ? 
                                info.groupOwnerAddress.getHostAddress() : null);
                        eventSink.success(connectionMap);
                    });
                } else {
                    Map<String, Object> connectionMap = new HashMap<>();
                    connectionMap.put("event", "connectionChanged");
                    connectionMap.put("isConnected", false);
                    eventSink.success(connectionMap);
                }
                
            } else if (WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION.equals(action)) {
                WifiP2pDevice device = intent.getParcelableExtra(WifiP2pManager.EXTRA_WIFI_P2P_DEVICE);
                if (device != null) {
                    Map<String, Object> deviceMap = new HashMap<>();
                    deviceMap.put("event", "deviceChanged");
                    deviceMap.put("deviceName", device.deviceName);
                    deviceMap.put("deviceAddress", device.deviceAddress);
                    deviceMap.put("status", device.status);
                    eventSink.success(deviceMap);
                }
            }
        }
    }
} 
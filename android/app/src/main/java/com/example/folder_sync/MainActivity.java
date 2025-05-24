package com.example.folder_sync;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String WIFI_DIRECT_CHANNEL = "com.example.folder_sync/wifi_direct";
    private static final String WIFI_DIRECT_EVENTS = "com.example.folder_sync/wifi_direct_events";
    
    private WifiDirectHandler wifiDirectHandler;
    
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Initialize Wi-Fi Direct handler
        wifiDirectHandler = new WifiDirectHandler(getApplicationContext());
        
        // Set up method channel for Wi-Fi Direct commands
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), WIFI_DIRECT_CHANNEL)
                .setMethodCallHandler(wifiDirectHandler);
        
        // Set up event channel for Wi-Fi Direct events
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), WIFI_DIRECT_EVENTS)
                .setStreamHandler(wifiDirectHandler);
    }
    
    @Override
    protected void onDestroy() {
        if (wifiDirectHandler != null) {
            wifiDirectHandler.cleanup();
        }
        super.onDestroy();
    }
} 
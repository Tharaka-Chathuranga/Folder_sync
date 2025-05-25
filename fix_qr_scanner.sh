#!/bin/bash

QR_SCANNER_PATH="/home/tharaka/.pub-cache/hosted/pub.dev/qr_code_scanner-1.0.1/android/build.gradle"
FIXED_FILE="$(pwd)/android/qr_code_scanner_fix/build.gradle"

if [ -f "$QR_SCANNER_PATH" ]; then
  echo "Backing up original build.gradle..."
  cp "$QR_SCANNER_PATH" "${QR_SCANNER_PATH}.backup"
  
  echo "Replacing with fixed version..."
  cp "$FIXED_FILE" "$QR_SCANNER_PATH"
  
  echo "Fix applied successfully!"
  echo "You can now try building your app again."
else
  echo "Error: Could not find qr_code_scanner build.gradle file at $QR_SCANNER_PATH"
  exit 1
fi 
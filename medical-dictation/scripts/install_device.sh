#!/bin/bash
# install_device.sh - Install HxDictate directly to your iPhone
# Faster than TestFlight for development testing

set -e

APP_NAME="HxDictate"
PROJECT="${APP_NAME}.xcodeproj"

echo "📱 Direct Install to iPhone"
echo "============================"
echo ""

# Find connected device
echo "🔍 Looking for iPhone..."
DEVICE=$(xcrun xctrace list devices 2>/dev/null | grep -E "iPhone.*(\d+\.\d+)" | head -1)

if [ -z "$DEVICE" ]; then
    echo "❌ No iPhone found"
    echo ""
    echo "Connect your iPhone 17 Pro and:"
    echo "1. Trust this computer on the device"
    echo "2. Unlock the device"
    echo "3. Run again"
    exit 1
fi

echo "✅ Found: $DEVICE"
echo ""

# Extract device ID
DEVICE_ID=$(echo "$DEVICE" | grep -oE '[A-Fa-f0-9]{40}')

if [ -z "$DEVICE_ID" ]; then
    # Try UUID format
    DEVICE_ID=$(echo "$DEVICE" | grep -oE '[A-Fa-f0-9]{8}-([A-Fa-f0-9]{4}-){3}[A-Fa-f0-9]{12}')
fi

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not extract device ID"
    echo "   Device info: $DEVICE"
    exit 1
fi

echo "Device ID: $DEVICE_ID"
echo ""

# Build and install
echo "🛠️  Building and installing..."
echo "   (This will take a few minutes...)"
echo ""

xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    build \
    2>&1 | grep -E "(Building|Compiling|Linking|Build succeeded|error:|warning:)"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS!"
    echo ""
    echo "✅ HxDictate installed on your iPhone!"
    echo ""
    echo "Check your home screen for the app."
else
    echo ""
    echo "❌ Build failed"
    echo ""
    echo "Common issues:"
    echo "- Models not added to Xcode project"
    echo "- Device not trusted"
    echo "- Signing certificate expired"
    echo ""
    echo "Try full build:"
    echo "   open HxDictate.xcodeproj"
fi

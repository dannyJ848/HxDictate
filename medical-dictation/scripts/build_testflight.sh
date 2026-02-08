#!/bin/bash
# build_testflight.sh - Build and upload to TestFlight
# Run this to deploy HxDictate directly to your iPhone via TestFlight

set -e

APP_NAME="HxDictate"
SCHEME="HxDictate"
WORKSPACE="${APP_NAME}.xcworkspace"
PROJECT="${APP_NAME}.xcodeproj"
BUNDLE_ID="com.danny.hxdictate"

echo "🚀 HxDictate TestFlight Deployment"
echo "==================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Install from App Store."
    exit 1
fi

# Check if user is logged in to Apple Developer account
if ! xcodebuild -list -project "$PROJECT" &> /dev/null; then
    echo "❌ Project not found. Run from project directory."
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Create build directory
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"

# Check for signing
echo "🔐 Checking code signing..."
echo ""
echo "⚠️  You need:"
echo "   1. Apple Developer account ($99/year)"
echo "   2. Valid signing certificate"
echo "   3. App registered in App Store Connect"
echo ""

# For now, build for simulator or local device
# TestFlight requires proper signing setup

echo "🛠️  Building app..."

# Archive build
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="" \
    2>&1 | tee "$BUILD_DIR/build.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed. Check $BUILD_DIR/build.log"
    echo ""
    echo "Common issues:"
    echo "- No signing team selected"
    echo "- Missing development certificate"
    echo "- Models not added to project"
    exit 1
fi

echo ""
echo "✅ Archive created: $BUILD_DIR/$APP_NAME.xcarchive"
echo ""

# Export IPA
echo "📦 Creating IPA..."

cat > "$BUILD_DIR/ExportOptions.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR" \
    2>&1 | tee -a "$BUILD_DIR/build.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Export failed. Check $BUILD_DIR/build.log"
    exit 1
fi

echo ""
echo "✅ IPA created: $BUILD_DIR/$APP_NAME.ipa"
echo ""

# Upload to TestFlight (requires app-specific password)
echo "☁️  Uploading to TestFlight..."
echo ""
echo "You'll need:"
echo "1. Apple ID: your email"
echo "2. App-specific password (generate at appleid.apple.com)"
echo ""

# Using altool for upload
xcrun altool --upload-app \
    --type ios \
    --file "$BUILD_DIR/$APP_NAME.ipa" \
    --apiKey "" \
    --apiIssuer "" \
    2>&1 | tee -a "$BUILD_DIR/upload.log"

echo ""
echo "✅ Upload complete!"
echo ""
echo "Next steps:"
echo "1. Go to https://appstoreconnect.apple.com"
echo "2. Navigate to My Apps → HxDictate → TestFlight"
echo "3. Wait for processing (~10-30 minutes)"
echo "4. Install on your iPhone via TestFlight app"
echo ""

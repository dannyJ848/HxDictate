#!/bin/bash
# deploy_testflight.sh - Deploy HxDictate to TestFlight using existing Apple Developer account

set -e

APP_NAME="HxDictate"
PROJECT="${APP_NAME}.xcodeproj"
BUILD_DIR="build"

echo "🚀 HxDictate → TestFlight"
echo "=========================="
echo ""

# Detect team ID from existing projects
TEAM_ID=""
echo "🔍 Detecting your Apple Developer Team..."

# Try to get team ID from security find-identity
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1)
if [ -n "$IDENTITIES" ]; then
    # Extract team ID from certificate (format: ... (Team ID))
    TEAM_ID=$(echo "$IDENTITIES" | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()' | head -1)
fi

if [ -z "$TEAM_ID" ]; then
    echo ""
    echo "⚠️  Could not auto-detect Team ID"
    echo ""
    echo "Find your Team ID:"
    echo "1. Open https://developer.apple.com/account"
    echo "2. Go to Membership → Team ID"
    echo ""
    read -p "Enter your Team ID (10 characters): " TEAM_ID
fi

echo "✅ Using Team ID: $TEAM_ID"
echo ""

# Update project with team ID
echo "🔧 Configuring project..."

# Use xcodeproj gem to update project
ruby << RUBY
require 'xcodeproj'

project = Xcodeproj::Project.open('$PROJECT')
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['DEVELOPMENT_TEAM'] = '$TEAM_ID'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
end

project.save
puts "✅ Project configured with Team ID: $TEAM_ID"
RUBY

# Check for models
echo ""
echo "📦 Checking models..."

if [ ! -f "scripts/build/models/ggml-large-v3.bin" ]; then
    echo "⚠️  Whisper Large V3 not found in Xcode project"
    echo "   Models need to be added to the project before building"
    echo ""
    echo "   Run: ls scripts/build/models/"
    echo "   Then add to Xcode: Right-click project → Add Files"
fi

if [ ! -f "scripts/build/models/deepseek-r1-distill-qwen-14b-q3_k_m.gguf" ]; then
    echo "⚠️  DeepSeek 14B not found in Xcode project"
fi

echo ""
echo "🛠️  Building archive..."

mkdir -p "$BUILD_DIR"

# Clean build
xcodebuild clean -project "$PROJECT" -scheme "$APP_NAME" 2>&1 > /dev/null

# Archive
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -allowProvisioningUpdates \
    2>&1 | tee "$BUILD_DIR/build.log" | grep -E "(error:|warning:|Build succeeded|Archive succeeded)"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed!"
    echo "   Check full log: $BUILD_DIR/build.log"
    echo ""
    echo "Common issues:"
    echo "- Models not added to Xcode project"
    echo "- Signing certificate issues"
    echo "- Missing entitlements"
    exit 1
fi

echo ""
echo "✅ Archive built successfully!"
echo ""

# Create export options
echo "📦 Creating IPA..."

cat > "$BUILD_DIR/ExportOptions.plist" <> EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>manualSigning</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

# Export IPA
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR" \
    2>&1 | tee -a "$BUILD_DIR/build.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Export failed!"
    exit 1
fi

IPA_PATH="$BUILD_DIR/$APP_NAME.ipa"
if [ ! -f "$IPA_PATH" ]; then
    # Find the IPA file
    IPA_PATH=$(find "$BUILD_DIR" -name "*.ipa" | head -1)
fi

echo ""
echo "✅ IPA created: $IPA_PATH"
echo ""

# Upload to TestFlight
echo "☁️  Uploading to TestFlight..."
echo ""

# Check if app exists in App Store Connect
echo "⚠️  First time setup required:"
echo ""
echo "1. Go to https://appstoreconnect.apple.com"
echo "2. Click 'My Apps' → '+' → 'New App'"
echo "3. Enter:"
echo "   - Name: HxDictate"
echo "   - Bundle ID: com.danny.hxdictate"
echo "   - SKU: hxdictate-001"
echo "   - Primary Language: English"
echo ""

read -p "Have you created the app in App Store Connect? (y/n): " CREATED

if [ "$CREATED" != "y" ]; then
    echo ""
    echo "⏸️  Pausing for App Store Connect setup..."
    echo "   Create the app, then run this script again."
    exit 0
fi

# Upload using altool
echo ""
echo "📤 Uploading IPA..."

# For Apple ID with app-specific password
read -p "Apple ID email: " APPLE_ID
echo ""
echo "⚠️  You need an app-specific password:"
echo "   1. Go to https://appleid.apple.com"
echo "   2. Sign in → App-Specific Passwords → Generate"
echo ""
read -s -p "App-specific password: " APP_PASS
echo ""

xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_PASS" \
    2>&1 | tee "$BUILD_DIR/upload.log"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS!"
    echo ""
    echo "✅ Uploaded to TestFlight!"
    echo ""
    echo "Next:"
    echo "1. Wait 10-30 minutes for processing"
    echo "2. Open TestFlight app on your iPhone"
    echo "3. Install HxDictate"
    echo ""
else
    echo ""
    echo "❌ Upload failed"
    echo "   Check: $BUILD_DIR/upload.log"
fi

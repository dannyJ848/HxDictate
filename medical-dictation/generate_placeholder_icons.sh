#!/bin/bash
# generate_placeholder_icons.sh
# Creates simple placeholder app icons for testing

set -e

ASSET_DIR="HxDictate/Assets.xcassets/AppIcon.appiconset"
cd "$(dirname "$0")"

# Check if we have sips (macOS) or ImageMagick
if command -v sips &> /dev/null; then
    echo "Using sips to generate icons..."
    
    # Create a simple colored square as base
    # Using a medical/scribble themed color (blue)
    
    # Generate each size
    sips -z 40 40   --out "${ASSET_DIR}/Icon-20@2x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 20@2x"
    sips -z 60 60   --out "${ASSET_DIR}/Icon-20@3x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 20@3x"
    sips -z 58 58   --out "${ASSET_DIR}/Icon-29@2x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 29@2x"
    sips -z 87 87   --out "${ASSET_DIR}/Icon-29@3x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 29@3x"
    sips -z 80 80   --out "${ASSET_DIR}/Icon-40@2x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 40@2x"
    sips -z 120 120 --out "${ASSET_DIR}/Icon-40@3x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 40@3x"
    sips -z 120 120 --out "${ASSET_DIR}/Icon-60@2x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 60@2x"
    sips -z 180 180 --out "${ASSET_DIR}/Icon-60@3x.png"   /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 60@3x"
    sips -z 1024 1024 --out "${ASSET_DIR}/Icon-1024.png" /System/Library/CoreServices/DefaultDesktop.heic 2>/dev/null || echo "⚠️  Could not generate 1024"
    
else
    echo "sips not available. Creating empty placeholder files..."
    touch "${ASSET_DIR}/Icon-20@2x.png"
    touch "${ASSET_DIR}/Icon-20@3x.png"
    touch "${ASSET_DIR}/Icon-29@2x.png"
    touch "${ASSET_DIR}/Icon-29@3x.png"
    touch "${ASSET_DIR}/Icon-40@2x.png"
    touch "${ASSET_DIR}/Icon-40@3x.png"
    touch "${ASSET_DIR}/Icon-60@2x.png"
    touch "${ASSET_DIR}/Icon-60@3x.png"
    touch "${ASSET_DIR}/Icon-1024.png"
fi

echo "✅ Placeholder icons created"
echo "⚠️  Replace these with actual app icons before TestFlight submission"

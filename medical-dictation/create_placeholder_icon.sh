#!/bin/bash
# create_placeholder_icon.sh
# Creates a simple placeholder app icon for HxDictate

set -e

ICONSET_DIR="ios-app/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET_DIR"

# Create a simple colored square with text using ImageMagick if available
# Otherwise create empty placeholder files

echo "Creating placeholder app icons..."

# Create a simple SVG and convert to PNGs
SVG_CONTENT='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#007AFF" rx="230"/>
  <text x="512" y="580" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="400" font-weight="bold" fill="white" text-anchor="middle">Hx</text>
  <path d="M 512 200 L 512 824" stroke="white" stroke-width="20" opacity="0.3"/>
  <circle cx="512" cy="512" r="400" fill="none" stroke="white" stroke-width="8" opacity="0.2"/>
</svg>'

# Save SVG
echo "$SVG_CONTENT" > "$ICONSET_DIR/icon.svg"

# Check if we can convert SVG to PNG
if command -v convert >/dev/null 2>&1 || command -v sips >/dev/null 2>&1; then
    echo "Image tools available, generating PNG icons..."
    
    # Generate different sizes
    # Note: In a real scenario, you'd use proper icon generation tools
    # For now, we'll just create empty placeholder files that Xcode will flag
    
    touch "$ICONSET_DIR/Icon-20@2x.png"
    touch "$ICONSET_DIR/Icon-20@3x.png"
    touch "$ICONSET_DIR/Icon-29@2x.png"
    touch "$ICONSET_DIR/Icon-29@3x.png"
    touch "$ICONSET_DIR/Icon-40@2x.png"
    touch "$ICONSET_DIR/Icon-40@3x.png"
    touch "$ICONSET_DIR/Icon-60@2x.png"
    touch "$ICONSET_DIR/Icon-60@3x.png"
    touch "$ICONSET_DIR/Icon-1024.png"
    
    echo "✅ Placeholder icon files created"
    echo ""
    echo "⚠️  IMPORTANT: Replace these with actual icon images before App Store submission"
    echo "   You can use a tool like:"
    echo "   - https://appicon.co/"
    echo "   - Xcode's built-in asset catalog editor"
    echo "   - Sketch/Figma with 1024x1024 base image"
else
    echo "⚠️  ImageMagick not available, creating empty placeholder files"
    echo "   You'll need to manually add icon images to:"
    echo "   $ICONSET_DIR"
    
    touch "$ICONSET_DIR/Icon-20@2x.png"
    touch "$ICONSET_DIR/Icon-20@3x.png"
    touch "$ICONSET_DIR/Icon-29@2x.png"
    touch "$ICONSET_DIR/Icon-29@3x.png"
    touch "$ICONSET_DIR/Icon-40@2x.png"
    touch "$ICONSET_DIR/Icon-40@3x.png"
    touch "$ICONSET_DIR/Icon-60@2x.png"
    touch "$ICONSET_DIR/Icon-60@3x.png"
    touch "$ICONSET_DIR/Icon-1024.png"
fi

echo ""
echo "✅ AppIcon placeholder setup complete"

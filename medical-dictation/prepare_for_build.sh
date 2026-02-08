#!/bin/bash
# prepare_for_build.sh - Prepare HxDictate for Xcode build

set -e

echo "🔧 Preparing HxDictate for build..."

# Check models exist
echo "📦 Checking models..."
MODELS_DIR="scripts/build/models"
if [ ! -f "$MODELS_DIR/ggml-large-v3.bin" ]; then
    echo "❌ Whisper Large V3 not found"
    exit 1
fi
if [ ! -f "$MODELS_DIR/deepseek-r1-distill-qwen-14b-q3_k_m.gguf" ]; then
    echo "❌ DeepSeek 14B not found"
    exit 1
fi
if [ ! -f "$MODELS_DIR/ggml-small.bin" ]; then
    echo "❌ Whisper Small not found"
    exit 1
fi
echo "✅ All models present"

# Check libraries exist
echo "📚 Checking libraries..."
if [ ! -f "scripts/build/whisper.cpp/build-ios/src/libwhisper.a" ]; then
    echo "❌ libwhisper.a not found"
    exit 1
fi
if [ ! -f "scripts/build/llama.cpp/build-ios/src/libllama.a" ]; then
    echo "❌ libllama.a not found"
    exit 1
fi
echo "✅ All libraries present"

# Calculate total size
echo ""
echo "📊 Model sizes:"
du -h $MODELS_DIR/*.bin $MODELS_DIR/*.gguf 2>/dev/null || true

echo ""
echo "📊 Library sizes:"
du -h scripts/build/whisper.cpp/build-ios/src/libwhisper.a
find scripts/build/llama.cpp/build-ios -name "libggml*.a" -exec du -h {} \;
du -h scripts/build/llama.cpp/build-ios/src/libllama.a

echo ""
echo "✅ Ready for Xcode build!"
echo ""
echo "Next steps:"
echo "1. Open HxDictate.xcodeproj in Xcode"
echo "2. Select your iPhone 17 Pro as the target device"
echo "3. Set your development team in Signing & Capabilities"
echo "4. Build and run (Cmd+R)"
echo ""
echo "⚠️  Note: First build will take several minutes due to model copying"

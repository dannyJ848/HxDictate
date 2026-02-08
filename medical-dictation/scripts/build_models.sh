#!/bin/bash
# build_models.sh - Build whisper.cpp and llama.cpp for iOS
# Run this on macOS with Xcode installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
IOS_DEPLOYMENT_TARGET="17.0"

echo "🏗️  Building Scribe Dependencies"
echo "================================="

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone/update repositories
clone_or_update() {
    local repo=$1
    local dir=$2
    if [ -d "$dir" ]; then
        echo "Updating $dir..."
        cd "$dir" && git pull && cd ..
    else
        echo "Cloning $repo..."
        git clone --depth 1 "$repo" "$dir"
    fi
}

clone_or_update "https://github.com/ggerganov/whisper.cpp.git" "whisper.cpp"
clone_or_update "https://github.com/ggerganov/llama.cpp.git" "llama.cpp"

# Build whisper.cpp for iOS
echo ""
echo "📦 Building Whisper.cpp..."
cd whisper.cpp

# Build for iOS device (arm64)
echo "Building for iOS device..."m -rf build-ios && mkdir build-ios && cd build-ios
cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DWHISPER_METAL=ON \
    -DWHISPER_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

make -j$(sysctl -n hw.ncpu)

cd ../..

# Build llama.cpp for iOS
echo ""
echo "📦 Building llama.cpp..."
cd llama.cpp

# Build for iOS device (arm64)
echo "Building for iOS device..."
rm -rf build-ios && mkdir build-ios && cd build-ios
cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

make -j$(sysctl -n hw.ncpu)

cd ../..

# Download models
echo ""
echo "📥 Downloading Models..."
mkdir -p models

cd models

# Whisper small
if [ ! -f "ggml-small.bin" ]; then
    echo "Downloading Whisper small model..."
    bash ../whisper.cpp/models/download-ggml-model.sh small
    cp ../whisper.cpp/models/ggml-small.bin .
fi

# DeepSeek 7B (requires HuggingFace login or manual download)
if [ ! -f "deepseek-r1-distill-qwen-7b-q4_k_m.gguf" ]; then
    echo ""
    echo "⚠️  DeepSeek model not found!"
    echo "Download from: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
    echo "Convert to GGUF format using llama.cpp's convert script"
    echo "Quantize to Q4_K_M for best size/quality tradeoff"
    echo ""
    echo "Or download pre-converted from:"
    echo "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF"
fi

cd ..

echo ""
echo "✅ Build Complete!"
echo ""
echo "Next steps:"
echo "1. Open Scribe.xcodeproj"
echo "2. Add the built libraries to your project:"
echo "   - $BUILD_DIR/whisper.cpp/build-ios/libwhisper.a"
echo "   - $BUILD_DIR/llama.cpp/build-ios/libllama.a"
echo "   - $BUILD_DIR/llama.cpp/build-ios/libggml.a"
echo "3. Copy models to app bundle or implement download-on-first-launch"
echo ""

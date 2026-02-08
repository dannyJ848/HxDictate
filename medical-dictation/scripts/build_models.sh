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

# Patch CMakeLists.txt to skip examples and tests for iOS build
if [ -f "CMakeLists.txt" ]; then
    # Backup original
    cp CMakeLists.txt CMakeLists.txt.backup
    # Comment out the examples and tests subdirectories
    sed -i '' 's/add_subdirectory(examples)/# add_subdirectory(examples)/' CMakeLists.txt
    sed -i '' 's/add_subdirectory(tests)/# add_subdirectory(tests)/' CMakeLists.txt
fi

# Build for iOS device (arm64)
echo "Building whisper.cpp for iOS device..."
rm -rf build-ios
mkdir build-ios
cd build-ios

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

# Restore original CMakeLists.txt
if [ -f "CMakeLists.txt.backup" ]; then
    mv CMakeLists.txt.backup CMakeLists.txt
fi

# Build llama.cpp for iOS
echo ""
echo "📦 Building llama.cpp..."
cd llama.cpp

# Patch CMakeLists.txt to skip tools for iOS build
if [ -f "CMakeLists.txt" ]; then
    # Backup original
    cp CMakeLists.txt CMakeLists.txt.backup
    # Comment out the tools subdirectory
    sed -i '' 's/add_subdirectory(tools)/# add_subdirectory(tools)/' CMakeLists.txt
    # Also try to comment out examples if present
    sed -i '' 's/add_subdirectory(examples)/# add_subdirectory(examples)/' CMakeLists.txt 2>/dev/null || true
fi

# Build for iOS device (arm64)
echo "Building llama.cpp for iOS device..."
rm -rf build-ios
mkdir build-ios
cd build-ios

cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_TESTS=OFF

# Build only core libraries
make -j$(sysctl -n hw.ncpu) ggml llama

cd ../..

# Restore original CMakeLists.txt
if [ -f "CMakeLists.txt.backup" ]; then
    mv CMakeLists.txt.backup CMakeLists.txt
fi

# Download models
echo ""
echo "📥 Downloading Models..."
mkdir -p models

cd models

# Whisper models
if [ ! -f "ggml-small.bin" ]; then
    echo "Downloading Whisper small model (~466MB)..."
    bash ../whisper.cpp/models/download-ggml-model.sh small
    cp ../whisper.cpp/models/ggml-small.bin .
fi

# Whisper Large V3 (EXTREME mode)
if [ ! -f "ggml-large-v3.bin" ]; then
    echo ""
    echo "⚠️  Whisper Large V3 not found (~2.9GB)"
    echo "Download manually from:"
    echo "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
    echo "Or run: curl -L -o ggml-large-v3.bin 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin'"
fi

# DeepSeek models (require manual download due to size/auth)
if [ ! -f "deepseek-r1-distill-qwen-7b-q4_k_m.gguf" ] && [ ! -f "deepseek-r1-distill-qwen-14b-q3_k_m.gguf" ]; then
    echo ""
    echo "⚠️  DeepSeek models not found!"
    echo ""
    echo "For 7B (Balanced): ~4.5GB"
    echo "  https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF"
    echo "  File: deepseek-r1-distill-qwen-7b-Q4_K_M.gguf"
    echo ""
    echo "For 14B (EXTREME): ~6.5GB"
    echo "  https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF"
    echo "  File: deepseek-r1-distill-qwen-14b-Q3_K_M.gguf"
    echo ""
    echo "Note: HuggingFace may require authentication for some models"
fi

cd ..

echo ""
echo "✅ Build Complete!"
echo ""
echo "Next steps:"
echo "1. Create Xcode project"
echo "2. Add the built libraries:"
echo "   - $BUILD_DIR/whisper.cpp/build-ios/libwhisper.a"
echo "   - $BUILD_DIR/llama.cpp/build-ios/libllama.a" 
echo "   - $BUILD_DIR/llama.cpp/build-ios/libggml.a"
echo "3. Add header search paths to whisper.cpp and llama.cpp include dirs"
echo "4. Download models and add to project or implement download-on-first-launch"
echo ""

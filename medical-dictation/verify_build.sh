#!/bin/bash
# verify_build.sh - Verify HxDictate is ready for Xcode build

set -e

echo "🔍 Verifying HxDictate build readiness..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check Swift files exist
echo "📄 Checking Swift source files..."
SWIFT_FILES=(
    "ios-app/Sources/ScribeApp/ScribeApp.swift"
    "ios-app/Sources/Scribe/Core/Audio/AudioSessionManager.swift"
    "ios-app/Sources/Scribe/Core/STT/TranscriptionEngine.swift"
    "ios-app/Sources/Scribe/Core/LLM/LLMProcessor.swift"
    "ios-app/Sources/Scribe/Models/NoteModels.swift"
    "ios-app/Sources/Scribe/Models/HPTemplate.swift"
    "ios-app/Sources/Scribe/UI/RecordingView.swift"
    "ios-app/Sources/Scribe/UI/HistoryView.swift"
    "ios-app/Sources/Scribe/UI/SettingsView.swift"
    "ios-app/Sources/Scribe/UI/GuidedHPView.swift"
)

for file in "${SWIFT_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ${RED}❌ Missing: $file${NC}"
        ((ERRORS++))
    fi
done
echo ""

# Check bridging headers
echo "🔗 Checking bridging headers..."
if [ -f "Scribe-Bridging-Header.h" ]; then
    echo "  ✅ Root bridging header"
else
    echo "  ${RED}❌ Missing: Scribe-Bridging-Header.h${NC}"
    ((ERRORS++))
fi

if [ -f "ios-app/Scribe-Bridging-Header.h" ]; then
    echo "  ✅ iOS app bridging header"
else
    echo "  ${RED}❌ Missing: ios-app/Scribe-Bridging-Header.h${NC}"
    ((ERRORS++))
fi
echo ""

# Check resources
echo "🎨 Checking resources..."
if [ -f "ios-app/Resources/Info.plist" ]; then
    echo "  ✅ Info.plist"
else
    echo "  ${RED}❌ Missing: Info.plist${NC}"
    ((ERRORS++))
fi

if [ -d "ios-app/Resources/Assets.xcassets" ]; then
    echo "  ✅ Assets.xcassets"
else
    echo "  ${RED}❌ Missing: Assets.xcassets${NC}"
    ((ERRORS++))
fi

if [ -f "ios-app/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
    echo "  ✅ AppIcon set"
else
    echo "  ${YELLOW}⚠️  Missing: AppIcon images${NC}"
    ((WARNINGS++))
fi
echo ""

# Check models
echo "🧠 Checking models..."
MODELS=(
    "scripts/build/models/ggml-small.bin"
    "scripts/build/models/ggml-large-v3.bin"
    "scripts/build/models/deepseek-r1-distill-qwen-14b-q3_k_m.gguf"
)

for model in "${MODELS[@]}"; do
    if [ -f "$model" ]; then
        SIZE=$(du -h "$model" | cut -f1)
        echo "  ✅ $(basename $model) ($SIZE)"
    else
        echo "  ${RED}❌ Missing: $model${NC}"
        ((ERRORS++))
    fi
done
echo ""

# Check libraries
echo "📚 Checking static libraries..."
LIBRARIES=(
    "scripts/build/whisper.cpp/build-ios/src/libwhisper.a"
    "scripts/build/llama.cpp/build-ios/src/libllama.a"
    "scripts/build/llama.cpp/build-ios/ggml/src/libggml.a"
    "scripts/build/llama.cpp/build-ios/ggml/src/ggml-metal/libggml-metal.a"
)

for lib in "${LIBRARIES[@]}"; do
    if [ -f "$lib" ]; then
        echo "  ✅ $(basename $lib)"
    else
        echo "  ${RED}❌ Missing: $lib${NC}"
        ((ERRORS++))
    fi
done
echo ""

# Check Xcode project
echo "🔨 Checking Xcode project..."
if [ -d "HxDictate.xcodeproj" ]; then
    echo "  ✅ HxDictate.xcodeproj"
else
    echo "  ${RED}❌ Missing: HxDictate.xcodeproj${NC}"
    ((ERRORS++))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo "${GREEN}✅ Build verification PASSED${NC}"
    echo ""
    echo "🚀 Ready for Xcode build!"
    echo ""
    echo "Next steps:"
    echo "  1. Open HxDictate.xcodeproj in Xcode"
    echo "  2. Select your iPhone 17 Pro as target"
    echo "  3. Set your development team"
    echo "  4. Build and run (⌘R)"
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        echo "${YELLOW}⚠️  Warnings: $WARNINGS (non-blocking)${NC}"
    fi
    
    exit 0
else
    echo "${RED}❌ Build verification FAILED${NC}"
    echo ""
    echo "Errors: $ERRORS"
    if [ $WARNINGS -gt 0 ]; then
        echo "Warnings: $WARNINGS"
    fi
    echo ""
    echo "Please fix the errors above before building."
    exit 1
fi

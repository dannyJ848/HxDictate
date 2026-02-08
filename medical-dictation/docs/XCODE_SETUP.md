# Xcode Project Setup

## Option 1: Automated (Recommended)

```bash
cd /Users/dannygomez/.openclaw/workspace/medical-dictation

# Install xcodeproj gem if needed
gem install xcodeproj

# Generate Xcode project
ruby generate_xcode_project.rb

# Open in Xcode
open HxDictate.xcodeproj
```

## Option 2: Manual Setup

### Step 1: Create New Project
1. Open Xcode
2. File → New → Project
3. Select "iOS" → "App"
4. Name: **HxDictate**
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Uncheck "Include Tests" (for now)
8. Save to: `/Users/dannygomez/.openclaw/workspace/medical-dictation/`

### Step 2: Add Source Files
1. Delete the default `ContentView.swift` and `HxDictateApp.swift`
2. Drag `ios-app/Sources/` folder into Xcode
3. Select "Create groups" and check your app target

### Step 3: Add Bridging Header
1. Drag `ios-app/Scribe-Bridging-Header.h` into project root
2. Select your target → Build Settings
3. Search for "Bridging Header"
4. Set: `$(SRCROOT)/Scribe-Bridging-Header.h`

### Step 4: Link Libraries
1. Select target → General → Frameworks, Libraries
2. Click "+" → Add Other → Add Files
3. Navigate to and add:
   - `scripts/build/whisper.cpp/build-ios/libwhisper.a`
   - `scripts/build/llama.cpp/build-ios/libllama.a`
   - `scripts/build/llama.cpp/build-ios/libggml.a`

### Step 5: Configure Build Settings
**Build Settings → Search Paths:**

**Library Search Paths:**
```
$(inherited)
$(SRCROOT)/scripts/build/whisper.cpp/build-ios
$(SRCROOT)/scripts/build/llama.cpp/build-ios
```

**Header Search Paths:**
```
$(inherited)
$(SRCROOT)/scripts/build/whisper.cpp/include
$(SRCROOT)/scripts/build/llama.cpp/include
$(SRCROOT)/scripts/build/whisper.cpp/ggml/include
$(SRCROOT)/scripts/build/llama.cpp/ggml/include
```

**Other Linker Flags:**
```
-lwhisper -lllama -lggml
```

### Step 6: Add Frameworks
In "Frameworks, Libraries":
- Add `Accelerate.framework`
- Add `Metal.framework`
- Add `MetalKit.framework`

### Step 7: Add Models
1. Create new group: "Models"
2. Drag model files from `scripts/build/models/`:
   - `ggml-large-v3.bin` (2.9 GB)
   - `deepseek-r1-distill-qwen-14b-q3_k_m.gguf` (6.8 GB)
   - `ggml-small.bin` (465 MB)
3. Check "Copy items if needed"
4. Select your app target

⚠️ **Warning:** Including 10GB of models will make your app bundle huge. Consider implementing download-on-first-launch instead.

### Step 8: Info.plist Permissions
Add to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for medical dictation.</string>
```

### Step 9: Build and Run
1. Select iPhone 17 Pro as target (Metal requires device, not simulator)
2. Cmd+R to build and run

## Troubleshooting

### "Library not found" error
- Check Library Search Paths
- Verify .a files exist in build directories

### "Header not found" error  
- Check Header Search Paths
- Verify whisper.cpp and llama.cpp include directories exist

### Metal errors on simulator
- Must run on physical device (iPhone 17 Pro)
- Simulator doesn't support Metal

### Memory warnings
- 14B model is heavy
- Close other apps before testing
- Expect thermal throttling

## Alternative: Download-on-First-Launch

To avoid 10GB app bundle:

1. Don't include models in app bundle
2. Implement download UI in app
3. Download models to Documents directory on first launch
4. Update model paths in code to use Documents directory

See `ios-app/Sources/Scribe/Core/LLM/LLMProcessor.swift` for path configuration.

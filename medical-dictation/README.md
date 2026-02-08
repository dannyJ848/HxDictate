# Scribe - Medical Dictation for iOS

Real-time, on-device clinical documentation powered by Whisper.cpp + DeepSeek.

## ⚡ Quick Start

```bash
# 1. Clone and enter directory
cd medical-dictation

# 2. Build the C++ dependencies
./scripts/build_models.sh

# 3. Download the DeepSeek model (manual step)
# Visit: https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF
# Download: deepseek-r1-distill-qwen-7b-Q4_K_M.gguf
# Place in: models/

# 4. Open in Xcode
open ios-app/Scribe.xcodeproj

# 5. Build and run on iPhone 17 Pro (or simulator with reduced models)
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI Layer                                              │
│  ├─ RecordingView (live transcription)                     │
│  ├─ HistoryView (saved encounters)                         │
│  └─ SettingsView (model management)                        │
├─────────────────────────────────────────────────────────────┤
│  Swift Business Logic                                       │
│  ├─ AudioSessionManager (AVAudioEngine)                    │
│  ├─ TranscriptionEngine (whisper.cpp bridge)               │
│  ├─ LLMProcessor (llama.cpp bridge)                        │
│  └─ SwiftData persistence                                  │
├─────────────────────────────────────────────────────────────┤
│  C++ Libraries (Metal GPU accelerated)                      │
│  ├─ whisper.cpp (STT)                                      │
│  └─ llama.cpp + ggml (LLM inference)                       │
├─────────────────────────────────────────────────────────────┤
│  Models (~5GB total)                                        │
│  ├─ whisper-small.bin (~466MB)                             │
│  └─ deepseek-7b-q4.gguf (~4.5GB)                           │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Manual Setup (if build script fails)

### 1. Build whisper.cpp

```bash
cd build/whisper.cpp
mkdir build-ios && cd build-ios

cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DWHISPER_METAL=ON \
    -DWHISPER_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

make -j8
```

### 2. Build llama.cpp

```bash
cd build/llama.cpp
mkdir build-ios && cd build-ios

cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

make -j8
```

### 3. Xcode Project Setup

1. **Create bridging header** (`Scribe-Bridging-Header.h`):
```objc
#ifndef Scribe_Bridging_Header_h
#define Scribe_Bridging_Header_h

// whisper.cpp
#import "whisper.h"

// llama.cpp  
#import "llama.h"
#import "ggml.h"

#endif
```

2. **Link libraries** in Build Settings:
   - Add `.a` files to "Link Binary with Libraries"
   - Add header search paths to whisper.cpp and llama.cpp includes
   - Set "Objective-C Bridging Header" to your bridging header path

3. **Add Metal framework** for GPU acceleration

## 📱 Device Requirements

| Component | Requirement |
|-----------|-------------|
| iOS Version | 17.0+ |
| Device | iPhone 15 Pro / 16 Pro / 17 Pro recommended |
| RAM | 8GB+ (for 7B model) |
| Storage | ~6GB free (models + app) |
| NPU | Apple A17 Pro or better |

## 🎯 Performance Expectations

On iPhone 17 Pro (A18 Pro):

| Task | Latency |
|------|---------|
| STT (Whisper small) | ~0.3s real-time factor |
| LLM inference (7B Q4) | ~10-20 tok/sec |
| Full note generation | ~3-5 seconds |

## 🔒 Privacy & HIPAA

- **No network calls** for patient data processing
- All models run on-device
- Core Data with encryption
- Optional biometric app lock
- No iCloud sync for patient data

## 📝 Output Templates

### SOAP Note
```markdown
**Subjective:** Patient reports...
**Objective:** Vital signs:...
**Assessment:** Primary diagnosis:...
**Plan:** 1. ... 2. ...
```

### H&P
Full history and physical with all standard sections.

### Custom Templates
Add rotation-specific templates in Settings.

## 🐛 Troubleshooting

### "Model not found" error
Models are too large for git. Download manually:
- Whisper: `bash scripts/download_whisper.sh small`
- DeepSeek: Download from HuggingFace, convert to GGUF

### Build fails with Metal errors
Ensure you're building for device (not simulator) - Metal requires actual GPU.

### Out of memory crashes
Use smaller models:
- Whisper: base instead of small
- LLM: Qwen 4B or Llama 3.2 3B instead of 7B

## 📚 Resources

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [DeepSeek R1](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B)
- [GGUF Conversion](https://github.com/ggerganov/llama.cpp/blob/master/convert_hf_to_gguf.py)

## 📄 License

This project structure is MIT licensed. Models have their own licenses (Whisper = MIT, DeepSeek = MIT, etc.)


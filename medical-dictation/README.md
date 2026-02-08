# HxDictate - Medical Dictation for iOS

Real-time, on-device clinical documentation powered by Whisper Large V3 + DeepSeek 14B.

**Status:** ✅ Libraries built, models downloaded, ready for Xcode integration

---

## 🚀 Quick Start

```bash
# Clone repo
git clone https://github.com/dannyJ848/HxDictate.git
cd HxDictate

# Generate Xcode project (automated)
ruby generate_xcode_project.rb

# Or manual setup - see docs/XCODE_SETUP.md
```

---

## 🔥 EXTREME Configuration

| Component | Model | Size | Status |
|-----------|-------|------|--------|
| **STT** | Whisper Large V3 | 2.9 GB | ✅ Downloaded |
| **LLM** | DeepSeek-R1 14B Q3 | 6.8 GB | ✅ Downloaded |
| **Fallback** | Whisper Small | 465 MB | ✅ Downloaded |
| **Total** | | **~10.2 GB** | ✅ Ready |

### Performance (iPhone 17 Pro)

| Metric | Expected |
|--------|----------|
| Model load time | ~15-20 seconds |
| STT latency | ~0.5x real-time |
| LLM inference | ~6-10 tokens/sec |
| Note generation | ~6-10 seconds |
| Battery drain | ~25-30%/hour |
| Temperature | Warm to hot |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI Interface                                          │
│  ├─ RecordingView (live transcription)                     │
│  ├─ HistoryView (saved encounters)                         │
│  └─ SettingsView (performance tiers)                       │
├─────────────────────────────────────────────────────────────┤
│  Core Components                                            │
│  ├─ AudioSessionManager (AVAudioEngine)                    │
│  ├─ TranscriptionEngine (Whisper Large V3)                 │
│  ├─ LLMProcessor (DeepSeek 14B)                            │
│  └─ SwiftData (encrypted persistence)                      │
├─────────────────────────────────────────────────────────────┤
│  C++ Libraries (Metal GPU accelerated)                      │
│  ├─ libwhisper.a ✅                                        │
│  ├─ libllama.a ✅                                          │
│  └─ libggml.a ✅                                           │
├─────────────────────────────────────────────────────────────┤
│  Models (~10GB)                                             │
│  ├─ ggml-large-v3.bin (2.9GB) ✅                           │
│  └─ deepseek-14b-q3.gguf (6.8GB) ✅                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 What's Included

### Pre-built Binaries
- ✅ `libwhisper.a` - iOS ARM64 + Metal
- ✅ `libllama.a` - iOS ARM64 + Metal  
- ✅ `libggml.a` - GGML backend

### Source Code
- ✅ Full SwiftUI app (Recording, History, Settings)
- ✅ Audio capture (AVAudioEngine, 16kHz PCM)
- ✅ Bridging headers for C++ libraries
- ✅ SwiftData models for encrypted persistence
- ✅ Performance tier system (PowerSaver → EXTREME)

### Documentation
- ✅ `docs/XCODE_SETUP.md` - Manual Xcode setup guide
- ✅ `docs/EXTREME_MODELS.md` - Model download & performance
- ✅ `docs/ADVANCED_MODELS.md` - Model selection guide

---

## 🔧 Setup Options

### Option 1: Automated (Recommended)
```bash
gem install xcodeproj
ruby generate_xcode_project.rb
open HxDictate.xcodeproj
```

### Option 2: Manual
See `docs/XCODE_SETUP.md` for step-by-step instructions.

---

## ⚙️ Build Configuration

### Required Build Settings

**Library Search Paths:**
```
$(SRCROOT)/scripts/build/whisper.cpp/build-ios
$(SRCROOT)/scripts/build/llama.cpp/build-ios
```

**Header Search Paths:**
```
$(SRCROOT)/scripts/build/whisper.cpp/include
$(SRCROOT)/scripts/build/llama.cpp/include
$(SRCROOT)/scripts/build/whisper.cpp/ggml/include
$(SRCROOT)/scripts/build/llama.cpp/ggml/include
```

**Linked Libraries:**
- `libwhisper.a`
- `libllama.a`
- `libggml.a`
- `Accelerate.framework`
- `Metal.framework`
- `MetalKit.framework`

---

## 🎯 Performance Tiers

| Tier | STT | LLM | Use Case |
|------|-----|-----|----------|
| 🔋 PowerSaver | Whisper Small | Qwen 3B | ED/Surgery - speed |
| ⚖️ Balanced | Whisper Medium | DeepSeek 7B | General medicine |
| 🚀 Maximum | Whisper Large Turbo | DeepSeek 14B | Psychiatry/complex |
| 🔥 **EXTREME** | **Whisper Large V3** | **DeepSeek 14B** | **Absolute max** |

---

## 🔒 Privacy & HIPAA

- ✅ **100% on-device** - No network for patient data
- ✅ Encrypted SwiftData storage
- ✅ Optional biometric lock
- ✅ No iCloud sync for patient data
- ✅ AirDrop export only

---

## 📝 Output Templates

- **SOAP Note** - Subjective, Objective, Assessment, Plan
- **H&P** - Full History & Physical
- **Brief Summary** - 1-paragraph handoff
- **Bullet Points** - Quick review
- **Custom** - Rotation-specific templates

---

## ⚠️ Known Limitations

### Memory (14B Model)
- Peak RAM usage: ~14GB on 8GB device
- iOS will aggressively manage memory
- May unload background apps
- Thermal throttling likely under sustained use

### Battery
- 25-30% per hour of active use
- Consider external battery for long sessions

### Device Requirements
- **Must use physical iPhone 17 Pro** - Simulator doesn't support Metal
- A18 Pro chip required for acceptable performance

---

## 🐛 Troubleshooting

### "Model not found" on first launch
Models are too large for git. Downloaded models are in:
```
scripts/build/models/
```

Copy to Xcode project or implement download-on-first-launch.

### Metal errors
- Must run on physical device
- iPhone 17 Pro (A18 Pro) required

### Memory warnings
- Close all background apps
- Use Balanced tier instead of EXTREME
- Reduce context window in code

### Build errors
- Check Xcode 15+ installed
- Verify CMake installed (`brew install cmake`)
- Run `build_models.sh` first

---

## 📚 Resources

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [DeepSeek R1](https://huggingface.co/deepseek-ai/DeepSeek-R1)
- [GGUF Models](https://huggingface.co/bartowski)

---

## 🎓 For Medical Students

This app is designed for clinical rotations:

- **Emergency Medicine** - Fast capture, structured output
- **Internal Medicine** - Detailed H&P generation
- **Psychiatry** - Nuanced assessment/plan reasoning
- **Surgery** - Pre-op notes, procedure documentation

**Always review AI-generated notes** before signing. The LLM can hallucinate.

---

Built with 💙 for privacy-first medical AI.

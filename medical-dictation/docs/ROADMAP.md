# Scribe Implementation Roadmap

## ✅ Completed (Today)

- [x] Project architecture design
- [x] SwiftUI app scaffold (Recording, History, Settings views)
- [x] Audio capture (AVAudioEngine)
- [x] Whisper.cpp integration structure
- [x] LLM (llama.cpp + DeepSeek) integration structure
- [x] SwiftData models for persistence
- [x] Build scripts for C++ dependencies
- [x] Bridging header for C libraries
- [x] Documentation

## 🚧 Next Steps (You)

### 1. Build the C++ Libraries
```bash
cd /Users/dannygomez/.openclaw/workspace/medical-dictation
./scripts/build_models.sh
```

### 2. Download Models
- Whisper small: Auto-downloaded by script
- DeepSeek 7B: 
  ```bash
  # Option 1: Direct download (if available)
  huggingface-cli download bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF --local-dir models/
  
  # Option 2: Manual - visit https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF
  # Download: deepseek-r1-distill-qwen-7b-Q4_K_M.gguf
  ```

### 3. Create Xcode Project
The current code uses Swift Package Manager structure. For iOS with C++:

**Option A: Convert to Xcode Project**
```bash
cd ios-app
swift package generate-xcodeproj  # If using older SPM
# OR manually create Xcode project and add Swift files
```

**Option B: Use Xcode's SPM integration**
1. Create new iOS project in Xcode
2. Add Swift files from `Sources/Scribe/`
3. Add bridging header
4. Link built `.a` libraries

### 4. Fix C++ Bridging
The bridging header provided is a starting point. You'll need to:
- Point header search paths to actual whisper.cpp/llama.cpp headers
- Ensure `libwhisper.a`, `libllama.a`, `libggml.a` are linked
- Handle Metal shader compilation

### 5. Test on Device
Simulator won't work for Metal/NPU. You need physical iPhone 17 Pro.

## 🔄 Iteration Plan

### v0.1 (MVP - Week 1)
- [ ] Working STT with Whisper small
- [ ] Basic transcript recording
- [ ] Save/load transcripts

### v0.2 (LLM - Week 2)
- [ ] DeepSeek 7B loading
- [ ] SOAP note generation
- [ ] Basic UI polish

### v0.3 (Clinical - Week 3)
- [ ] Custom templates for rotations
- [ ] Export options (copy, share)
- [ ] Biometric lock

### v0.4 (Polish - Week 4)
- [ ] Voice commands
- [ ] Term highlighting
- [ ] Performance optimization

## ⚠️ Known Blockers

1. **Model Size**: 4.5GB is large for app bundle
   - Solution: Implement download-on-first-launch
   
2. **RAM Pressure**: 7B + Whisper + iOS overhead
   - Solution: Unload Whisper when LLM runs, aggressive memory management
   
3. **Cold Start**: First inference is slow (~10s)
   - Solution: Warm-up on app launch
   
4. **Medical Accuracy**: LLMs hallucinate
   - Solution: Always show raw transcript, require review

## 🔧 Alternative Models (if 7B too heavy)

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| DeepSeek-R1-Distill-Qwen-7B | 4.5GB | Medium | Best |
| Llama-3.2-3B-Instruct | 1.8GB | Fast | Good |
| Phi-3-mini-4k | 1.8GB | Fast | Good |
| Qwen2.5-3B-Instruct | 1.8GB | Fast | Good |

For clinical use, consider fine-tuning a smaller model on medical notes.

## 📞 Help Resources

- whisper.cpp Discord: https://discord.gg/whispercpp
- llama.cpp issues: https://github.com/ggerganov/llama.cpp/issues
- iOS ML community: Core ML / Metal Performance Shaders docs


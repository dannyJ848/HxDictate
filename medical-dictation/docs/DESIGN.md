# Medical Dictation App - Design Document

**Codename:** Scribe
**Platform:** iOS 18+, iPhone 17 Pro optimized
**Privacy Model:** 100% on-device, zero network calls for patient data

---

## Core Requirements

### 1. Real-Time Speech-to-Text
- **Engine:** Whisper.cpp with `ggml-small.bin` or distilled variant
- **Latency target:** <500ms streaming transcription
- **Accuracy:** Medical terminology robust (can fine-tune with clinical vocab)
- **Languages:** English primary, Spanish secondary (rotation dependent)

### 2. Local LLM for Structure
- **Model:** DeepSeek-R1-Distill-Qwen-7B (Q4_K_M quantized ~4.5GB)
- **Alternative:** Llama-3.1-8B-Instruct if DeepSeek fails on-device
- **Task:** Convert raw transcript → structured H&P (History & Physical)
- **Inference:** llama.cpp with Metal GPU acceleration

### 3. Output Formats
- **SOAP Note** (Subjective, Objective, Assessment, Plan)
- **H&P** (History & Physical - comprehensive)
- **Brief Summary** (1-paragraph for handoff)
- **Bullet Points** (quick review)

### 4. TTS Feedback (Optional)
- **Engine:** Piper neural TTS (small voice ~50MB)
- **Use case:** Confirm capture, read back critical findings

---

## Technical Architecture

### App Structure (Swift Package)
```
Scribe/
├── App/
│   ├── ScribeApp.swift
│   └── Info.plist
├── Core/
│   ├── Audio/              # AVAudioEngine, buffer management
│   ├── STT/                # Whisper.cpp bridge
│   ├── LLM/                # llama.cpp bridge
│   └── TTS/                # Piper or AVSpeech
├── UI/
│   ├── RecordingView/
│   ├── ReviewView/
│   └── HistoryListView/
├── Models/
│   ├── PatientEncounter.swift
│   ├── Transcript.swift
│   └── StructuredNote.swift
└── Resources/
    └── Models/             # GGUF files (git-lfs or download on first run)
```

### Model Storage Strategy
- Base app: ~100MB (code + UI)
- Whisper small: ~466MB
- DeepSeek 7B Q4: ~4.5GB
- **Total:** ~5GB (acceptable for 256GB+ iPhone)

### Download Strategy
- Ship with tiny/base Whisper for immediate use
- Download small Whisper + DeepSeek on first launch (with progress UI)
- Store in app container, encrypted

---

## Privacy & Compliance

### Data Handling
- All audio processing: In-memory only, never written to disk unencrypted
- Transcripts: Core Data with encryption
- No iCloud sync for patient data (HIPAA risk)
- Export: AirDrop/Share sheet to user's EHR (no cloud intermediaries)

### HIPAA Considerations
- No network transmission = no BAA needed
- Device encryption + app-level encryption
- Auto-lock after 5 min inactivity
- Biometric auth for app access

---

## MVP Features (Week 1-2)

1. [ ] Audio capture with AVAudioEngine
2. [ ] Whisper.cpp integration (small model)
3. [ ] Real-time transcript display
4. [ ] Save/edit transcripts
5. [ ] Export as text/Markdown

## v1.0 Features (Week 3-4)

1. [ ] llama.cpp + DeepSeek 7B integration
2. [ ] Structured note generation (SOAP/H&P)
3. [ ] Template system (custom prompts)
4. [ ] History library with search
5. [ ] Voice commands ("new paragraph", "section: assessment")

## Future Enhancements

- [ ] Medical term auto-correction
- [ ] Drug interaction warnings (offline database)
- [ ] Vitals extraction ("BP 120/80" → structured data)
- [ ] Multiple patient queue
- [ ] Apple Watch companion (start/stop recording)

---

## Known Challenges

1. **RAM Pressure:** 7B model + Whisper + iOS overhead = tight on 8GB
   - Solution: Unload Whisper when LLM runs, use streaming
   
2. **Battery:** Sustained NPU usage drains fast
   - Solution: Batch processing option, thermal throttling awareness
   
3. **Cold Start:** First inference is slow
   - Solution: Warm-up on app launch, keep model resident
   
4. **Medical Accuracy:** Hallucination risk in LLM output
   - Solution: Clear disclaimers, raw transcript always preserved, review required

---

## Resources

- Whisper.cpp: https://github.com/ggerganov/whisper.cpp
- llama.cpp: https://github.com/ggerganov/llama.cpp
- DeepSeek R1: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B
- Piper TTS: https://github.com/rhasspy/piper


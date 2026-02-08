# Scribe - Advanced Model Configurations

Aggressive model choices that push iPhone 17 Pro to its limits.

---

## 🏆 Maximum Accuracy Setup (Aggressive)

### STT: Whisper Large v3 Turbo
- **Size:** 1.6 GB
- **VRAM:** ~3 GB
- **Why:** Near-Large accuracy at 55% the size. Critical for medical terminology.
- **Download:** `ggml-large-v3-turbo.bin`

### LLM: DeepSeek-R1-Distill-Qwen-14B
- **Size:** 8.5 GB (Q4_K_M)
- **VRAM:** ~11 GB peak
- **Why:** Significantly better reasoning than 7B. Medical reasoning chains are more coherent.
- **Tradeoffs:** Memory pressure, slower inference (~8 tok/sec)

**Total:** ~10 GB model weight → ~14 GB peak RAM usage

---

## ⚡ Balanced Power Setup (Recommended)

### STT: Whisper Medium
- **Size:** 1.5 GB
- **VRAM:** ~2.5 GB
- **Sweet spot:** Noticeably better than Small, not as heavy as Large

### LLM: DeepSeek-R1-Distill-Qwen-7B
- **Size:** 4.5 GB (Q4_K_M)
- **VRAM:** ~6 GB
- **Reliable:** Fits comfortably in 8GB RAM

**Total:** ~6 GB model weight → ~9 GB peak RAM

---

## 🔧 Memory Optimization for 14B Models

If you run 14B, add these to `LLMProcessor.swift`:

```swift
// Reduce context window
ctxParams.n_ctx = 2048  // Was 4096

// Reduce batch size  
ctxParams.n_batch = 256 // Was 512

// Don't offload all layers (keeps some in RAM)
modelParams.n_gpu_layers = 40 // Was 99 (all)

// Enable mmap but disable mlock
modelParams.use_mmap = true
modelParams.use_mlock = false
```

### Aggressive Memory Management

```swift
// When switching from STT to LLM:
func prepareForLLM() {
    // 1. Pause audio engine (keep running but stop buffers)
    audioManager.pause()
    
    // 2. Force garbage collection of audio buffers
    transcriptionEngine.compactMemory()
    
    // 3. Unload Whisper temporarily if needed
    if memoryPressureHigh {
        transcriptionEngine.unloadModel()
    }
    
    // 4. Now load/run LLM
    llmProcessor.processTranscript(...)
    
    // 5. Restore STT after
    transcriptionEngine.loadModel()
}
```

---

## 📊 Performance Benchmarks (iPhone 17 Pro Estimates)

| Config | Load Time | STT Latency | LLM Speed | Note Gen Time |
|--------|-----------|-------------|-----------|---------------|
| Conservative (Small/3B) | 2s | 0.3x RTF | 25 tok/s | 2s |
| Balanced (Medium/7B) | 5s | 0.4x RTF | 15 tok/s | 4s |
| Aggressive (Turbo/14B) | 12s | 0.35x RTF | 8 tok/s | 8s |

*RTF = Real-time factor (0.3x = 3x faster than real-time)

---

## 🎯 Rotation-Specific Model Choices

### Emergency Medicine
- **STT:** Medium (fast, good in noisy environments)
- **LLM:** 7B (speed matters more than nuance)

### Psychiatry / Internal Medicine
- **STT:** Large v3 Turbo (subtle speech patterns, medication names)
- **LLM:** 14B Q3 (nuanced assessment generation)

### Surgery
- **STT:** Medium (procedural vocabulary)
- **LLM:** 7B (structured H&P, less reasoning needed)

---

## 🔄 Dynamic Model Loading

Consider implementing model tiers:

```swift
enum PerformanceTier {
    case powerSaver    // Small + 3B
    case balanced      // Medium + 7B  
    case maximum       // Turbo + 14B
    
    var sttModel: String {
        switch self {
        case .powerSaver: return "ggml-small.bin"
        case .balanced: return "ggml-medium.bin"
        case .maximum: return "ggml-large-v3-turbo.bin"
        }
    }
    
    var llmModel: String {
        switch self {
        case .powerSaver: return "qwen2.5-3b-q4.gguf"
        case .balanced: return "deepseek-r1-7b-q4.gguf"
        case .maximum: return "deepseek-r1-14b-q3.gguf"
        }
    }
}
```

Let user switch based on rotation/battery level.

---

## 🚨 Warning Signs of Memory Pressure

Watch for these in Xcode:
```
⚠️  Received memory warning (Level 1)
⚠️  Received memory warning (Level 2) 
❌  Terminated due to memory issue
```

If you see Level 2, immediately:
1. Unload STT model
2. Reduce LLM context window
3. Save state and alert user

---

## 📥 Model Download Links

### Whisper (all from official whisper.cpp repo)
```bash
bash models/download-ggml-model.sh large-v3-turbo
bash models/download-ggml-model.sh medium
bash models/download-ggml-model.sh small
```

### DeepSeek (HuggingFace)
- **7B Q4:** `bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF`
- **14B Q4:** `bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF`
- **14B Q3:** Same repo, look for `Q3_K_M` or `Q3_K_S` variants

### Alternative: Medical Fine-Tuned
- **Meditron-7B:** `epfl-llm/meditron-7b` (medically fine-tuned Llama)
- **BioMistral-7B:** Good for clinical reasoning

---

## Final Recommendation

**Start with Balanced (Medium + 7B)** — get the app working reliably first.

**Then test Aggressive (Turbo + 14B Q3)** — see if your specific rotation's note complexity justifies the tradeoffs.

For psychiatry or complex internal medicine where the assessment/plan reasoning chain matters, 14B is worth it. For ED or surgery where speed and structure matter more than deep reasoning, 7B is plenty.

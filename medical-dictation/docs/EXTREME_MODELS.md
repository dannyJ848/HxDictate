# Model Download Guide

## EXTREME Configuration Models

For the 🔥 EXTREME tier (Whisper Large V3 + DeepSeek 14B):

### 1. Whisper Large V3
**Size:** 2.9 GB  
**Download:**
```bash
cd medical-dictation/models
curl -L -o ggml-large-v3.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
```

Or manual: https://huggingface.co/ggerganov/whisper.cpp/tree/main

### 2. DeepSeek-R1-Distill-Qwen-14B
**Size:** ~6.5 GB (Q3_K_M quantization)  
**Download:**
```bash
# Install huggingface-cli
pip install huggingface-hub

# Download (requires HuggingFace token)
huggingface-cli download bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF \
  --local-dir . \
  --include "*Q3_K_M.gguf"
```

Or manual: https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF

**Recommended quantization for iPhone:**
- `Q3_K_M` (~6.5GB) - Best balance for 8GB RAM
- `Q4_K_M` (~8.5GB) - Better quality but risk of memory pressure

### 3. Total Storage Required
- Whisper Large V3: 2.9 GB
- DeepSeek 14B Q3: 6.5 GB
- App + overhead: ~0.5 GB
- **Total: ~10 GB**

### 4. Performance Expectations (iPhone 17 Pro)

| Metric | Expected |
|--------|----------|
| App launch | ~5 seconds |
| Model load | ~15-20 seconds (cold) |
| STT latency | ~0.5x real-time (slower than smaller models) |
| LLM speed | ~6-10 tokens/second |
| Note generation | ~6-10 seconds |
| Battery drain | ~25-30% per hour |
| Device temperature | Warm to hot under sustained use |

### 5. Memory Management Tips

If you get memory warnings:

1. **Kill background apps** before using Scribe
2. **Don't multitask** while recording
3. **Keep sessions short** (< 10 minutes)
4. **Let phone cool** between patients if it gets hot
5. **Have Balanced tier ready** as fallback

### 6. Model Verification

Verify downloads with SHA checksums (optional but recommended):

```bash
# Whisper Large V3 expected SHA256:
# (Check whisper.cpp repo for current hash)
shasum -a 256 ggml-large-v3.bin

# DeepSeek (check HuggingFace model card for hashes)
```


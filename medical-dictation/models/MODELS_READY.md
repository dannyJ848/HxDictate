# EXTREME Models Downloaded ✅

All models for the 🔥 EXTREME tier have been downloaded:

| Model | File | Size |
|-------|------|------|
| Whisper Large V3 | `ggml-large-v3.bin` | 2.9 GB |
| DeepSeek 14B Q3 | `deepseek-r1-distill-qwen-14b-q3_k_m.gguf` | 6.8 GB |
| Whisper Small | `ggml-small.bin` | 465 MB |

**Total: ~10.2 GB**

## ⚠️ Important

These models are **NOT committed to Git** (too large). They're stored in `scripts/build/models/` locally.

To use them:
1. Copy/move them to your Xcode project bundle, OR
2. Implement download-on-first-launch in your app

## Performance Expectations (iPhone 17 Pro)

| Metric | Expected |
|--------|----------|
| App launch | ~5 seconds |
| Model load | ~15-20 seconds (cold) |
| STT latency | ~0.5x real-time |
| LLM speed | ~6-10 tokens/second |
| Note generation | ~6-10 seconds |
| Battery drain | ~25-30% per hour |
| Device temperature | Warm to hot |

## Next Steps

See `docs/EXTREME_MODELS.md` for detailed setup instructions.


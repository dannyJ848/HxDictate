# GitHub Setup Guide

Push Scribe to your GitHub account.

---

## 1. Create GitHub Repository

**Option A: Via GitHub Web**
1. Go to https://github.com/new
2. Name: `scribe-medical-dictation` (or whatever)
3. Set to **Private** (contains medical app code)
4. Don't initialize with README (we have one)
5. Create repository

**Option B: Via GitHub CLI**
```bash
gh repo create scribe-medical-dictation --private --source=. --push
```

---

## 2. Push Your Code

```bash
cd /Users/dannygomez/.openclaw/workspace/medical-dictation

# Initialize git (if not already done)
git init

# Add remote (replace with your username)
git remote add origin https://github.com/YOURUSERNAME/scribe-medical-dictation.git

# Add all files
git add -A

# Commit
git commit -m "Initial commit: Scribe medical dictation app

- Real-time STT with Whisper.cpp
- On-device LLM with DeepSeek-R1 14B
- HIPAA-compliant (100% local)
- SwiftUI interface with rotation templates
- Performance tiers: PowerSaver to EXTREME"

# Push
git push -u origin master
```

---

## 3. ⚠️ IMPORTANT: Git LFS for Models

Models are too big for regular git. Use Git LFS:

```bash
# Install git-lfs
brew install git-lfs
git lfs install

# Track model files
git lfs track "*.bin"
git lfs track "*.gguf"
git lfs track "*.pt"
git lfs track "*.safetensors"

# Add .gitattributes
git add .gitattributes
git commit -m "Add Git LFS for model files"
```

**BUT:** Git LFS has bandwidth limits. For 10GB+ of models:

**Better approach:** Don't commit models to git. Instead:

### Add to .gitignore:
```
# Models - too large for git
models/*.bin
models/*.gguf
models/*.pt
models/*.safetensors

# Build artifacts
build/
*.a
*.dylib
*.framework

# Xcode
*.xcworkspace/
*.xcodeproj/xcuserdata/
DerivedData/

# Sensitive
*.pem
*.key
GoogleService-Info.plist
```

### Create model download script:
```bash
cat > scripts/download_models.sh << 'EOF'
#!/bin/bash
# Download models after cloning repo
set -e

echo "Downloading Scribe models..."
mkdir -p models

cd models

# Whisper Large V3
echo "Downloading Whisper Large V3 (~2.9GB)..."
if [ ! -f "ggml-large-v3.bin" ]; then
    curl -L -o ggml-large-v3.bin \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
fi

# DeepSeek 14B Q3
echo "Downloading DeepSeek-R1 14B Q3 (~6.5GB)..."
if [ ! -f "deepseek-r1-distill-qwen-14b-q3_k_m.gguf" ]; then
    # You'll need to use huggingface-cli or download manually
    echo "DeepSeek requires HuggingFace authentication"
    echo "Visit: https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF"
    echo "Download: deepseek-r1-distill-qwen-14b-Q3_K_M.gguf"
fi

echo "Done!"
EOF
chmod +x scripts/download_models.sh
```

---

## 4. GitHub Secrets (for CI/CD)

If you set up GitHub Actions for builds:

```bash
# Add secrets via CLI or web interface
gh secret set APPLE_DEVELOPMENT_TEAM --body "YOUR_TEAM_ID"
gh secret set APPLE_CERTIFICATE --bodyFile ~/path/to/cert.p12
gh secret set APPLE_CERTIFICATE_PASSWORD --body "cert_password"
```

---

## 5. README Update

Update the README with your repo URL and model download instructions.

---

## 6. Quick Reference

```bash
# Daily workflow
git add -A
git commit -m "description"
git push

# Pull latest
git pull

# Check status
git status

# View history
git log --oneline -10
```


# TestFlight Deployment Guide

## Quick Deploy Options

### Option 1: Direct Install (Fastest - Development)
Just for testing on YOUR device:
```bash
cd /Users/dannygomez/.openclaw/workspace/medical-dictation
./scripts/install_device.sh
```

Requirements:
- iPhone 17 Pro connected via USB
- Device unlocked and trusted
- Xcode will auto-sign with your existing certificate

### Option 2: TestFlight (For distribution)
Deploy to TestFlight for easy installation:
```bash
cd /Users/dannygomez/.openclaw/workspace/medical-dictation
./scripts/deploy_testflight.sh
```

Requirements:
- Apple Developer account (✅ you have this)
- App registered in App Store Connect
- App-specific password

---

## First-Time TestFlight Setup

### Step 1: Register App (One-time)
1. Go to https://appstoreconnect.apple.com
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Enter:
   - **Name:** HxDictate
   - **Bundle ID:** com.danny.hxdictate
   - **SKU:** hxdictate-001
   - **Primary Language:** English
   - **User Access:** Full Access

### Step 2: Generate App-Specific Password
1. Go to https://appleid.apple.com
2. Sign in → **"App-Specific Passwords"**
3. Click **"Generate"**
4. Save the password (format: XXXX-XXXX-XXXX-XXXX)

### Step 3: Deploy
```bash
./scripts/deploy_testflight.sh
```

Follow prompts:
- Team ID (auto-detected or enter manually)
- Apple ID email
- App-specific password

### Step 4: Install on iPhone
1. Wait 10-30 minutes for processing
2. Download **TestFlight** app from App Store
3. Open TestFlight → Accept invitation → Install HxDictate

---

## Troubleshooting

### "No signing team found"
```bash
# Check your certificates
security find-identity -v -p codesigning

# Or open Xcode and select team manually:
open HxDictate.xcodeproj
# → HxDictate target → Signing & Capabilities → Team
```

### "Bundle ID already taken"
Change bundle ID in Xcode or use your unique one:
- Current: `com.danny.hxdictate`
- Try: `com.danny.hxdictate.v2`

### "App not found in App Store Connect"
You must create the app in App Store Connect BEFORE uploading.

### "Invalid app-specific password"
Generate a new one at appleid.apple.com. Do NOT use your Apple ID password.

### Build errors with models
Models must be added to Xcode project:
1. In Xcode, right-click project
2. **"Add Files to HxDictate"**
3. Select from `scripts/build/models/`:
   - `ggml-large-v3.bin`
   - `deepseek-r1-distill-qwen-14b-q3_k_m.gguf`
   - `ggml-small.bin`
4. Check **"Copy items if needed"**

---

## Automated CI/CD (Advanced)

For future automated builds, set up secrets:
```bash
# Export for CI
echo "export APPLE_ID=your@email.com" >> ~/.zshrc
echo "export APPLE_TEAM_ID=XXXXXXXXXX" >> ~/.zshrc
echo "export APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx" >> ~/.zshrc
```

Then deploy without prompts:
```bash
./scripts/deploy_testflight.sh --auto
```

---

## 📱 After Install

1. **First launch:** Models load (~15-20 seconds)
2. **Grant microphone permission** when prompted
3. **Select EXTREME tier** in Settings
4. **Test recording** - tap red button, speak, stop
5. **Generate note** - tap sparkle button

**⚠️ Warning:** 10GB of models will use significant storage and battery!


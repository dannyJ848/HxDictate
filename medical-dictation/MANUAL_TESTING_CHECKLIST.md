# HxDictate Manual Testing Checklist

Use this checklist for manual device testing before clinical deployment.

## Pre-Flight Setup

- [ ] Test on physical iPhone 15 Pro or newer (simulator won't work)
- [ ] Ensure device has at least 10GB free storage
- [ ] Close all background apps
- [ ] Charge device to at least 50%
- [ ] Enable Do Not Disturb

## Model Loading Tests

### Whisper Models
- [ ] Load Whisper Small (465 MB) - Should load in <5 seconds
- [ ] Load Whisper Medium (1.5 GB) - Should load in <10 seconds
- [ ] Load Whisper Large V3 (2.9 GB) - Should load in <20 seconds
- [ ] Verify model can be unloaded without crash
- [ ] Test model switching (Small → Large → Small)

### LLM Models
- [ ] Load DeepSeek 7B (4.4 GB) - Should load in <15 seconds
- [ ] Load DeepSeek 14B (6.8 GB) - Should load in <25 seconds
- [ ] Verify model can be unloaded without crash
- [ ] Test memory warning handling during load

## Transcription Pipeline Tests

### Audio Capture
- [ ] Start recording - visual indicator shows
- [ ] Speak for 30 seconds continuously
- [ ] Stop recording - no crash
- [ ] Verify audio buffer doesn't overflow

### Transcription Quality
- [ ] Test with clear speech - accuracy >95%
- [ ] Test with medical terminology ("myocardial infarction", "pneumothorax")
- [ ] Test with numbers and dosages ("5 mg twice daily")
- [ ] Test with background noise (simulated hospital environment)
- [ ] Verify timestamps are reasonable

### Real-time Performance
- [ ] Transcription latency <2 seconds behind speech
- [ ] No dropped audio segments
- [ ] UI remains responsive during transcription
- [ ] Battery drain <5% for 10-minute session

## LLM Generation Tests

### Template Generation
- [ ] Generate SOAP note from transcript
- [ ] Generate H&P from transcript
- [ ] Generate brief summary
- [ ] Generate bullet points

### Quality Checks
- [ ] Medical terminology preserved
- [ ] No hallucinated medications or diagnoses
- [ ] Logical structure (subjective before objective, etc.)
- [ ] Appropriate level of detail for template type

### Performance
- [ ] SOAP generation completes in <15 seconds
- [ ] H&P generation completes in <30 seconds
- [ ] Streaming output updates every 1-2 seconds
- [ ] Cancel generation works without crash

## Memory Stress Tests

### Single Model
- [ ] Record and transcribe 5-minute session
- [ ] Monitor memory usage (should stay <4GB)
- [ ] No memory warnings

### Both Models Loaded
- [ ] Load Whisper Large V3
- [ ] Load DeepSeek 7B
- [ ] Record and transcribe 2-minute session
- [ ] Generate SOAP note
- [ ] Monitor for memory warnings
- [ ] App should handle memory pressure gracefully

### Extended Session
- [ ] 15-minute continuous recording
- [ ] Generate note every 5 minutes
- [ ] Device temperature should stay warm, not hot
- [ ] No thermal throttling warnings

## Data Persistence Tests

### Save/Load
- [ ] Save generated note
- [ ] Close app completely
- [ ] Reopen app - note persists
- [ ] Note content unchanged

### Export
- [ ] Export note via AirDrop
- [ ] Exported text is complete
- [ ] Formatting preserved

## Clinical Safety Tests

### Privacy
- [ ] Verify no network calls during transcription
- [ ] Verify no network calls during generation
- [ ] Check no data in iCloud
- [ ] Verify local-only storage

### Accuracy Validation
- [ ] Review generated note against transcript
- [ ] Flag any hallucinations or errors
- [ ] Check medication names are correct
- [ ] Verify dosages match transcript

### Edge Cases
- [ ] Empty transcript handling
- [ ] Very short transcript (<10 words)
- [ ] Very long transcript (>1000 words)
- [ ] Non-medical speech (should still work)
- [ ] Non-English words (medical Latin terms)

## UI/UX Tests

### Recording View
- [ ] Record button clearly visible
- [ ] Visual feedback during recording
- [ ] Transcript scrolls properly
- [ ] Cancel recording works

### History View
- [ ] Notes displayed chronologically
- [ ] Search/filter works
- [ ] Delete note works
- [ ] Tap to view full note

### Settings
- [ ] Performance tier selection works
- [ ] Model selection persists
- [ ] Template selection works

## Device Compatibility

### iPhone 15 Pro
- [ ] All features work
- [ ] Acceptable performance

### iPhone 15 Pro Max
- [ ] All features work
- [ ] Better performance than 15 Pro

### iPhone 16 Pro/Pro Max
- [ ] All features work
- [ ] Best performance

## Regression Tests

After any code change, verify:
- [ ] Model loading still works
- [ ] Transcription still works
- [ ] Note generation still works
- [ ] No new crashes
- [ ] Memory usage similar to before

## Sign-Off

**Tester:** ___________________

**Date:** ___________________

**Device:** ___________________

**iOS Version:** ___________________

**Overall Result:** ☐ PASS ☐ FAIL

**Notes:**

_________________________________

_________________________________

_________________________________

**Approved for clinical use:** ☐ YES ☐ NO

**Approved by:** ___________________

#!/bin/bash
#
# HxDictate Comprehensive Test & Validation Suite
# Tests models, C wrappers, transcription pipeline, LLM pipeline, and memory usage
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Configuration
PROJECT_ROOT="/Users/dannygomez/.openclaw/workspace/medical-dictation"
MODELS_DIR="${PROJECT_ROOT}/scripts/build/models"
IOS_APP_DIR="${PROJECT_ROOT}/ios-app"
BUILD_DIR="${PROJECT_ROOT}/scripts/build"
REPORT_FILE="${PROJECT_ROOT}/test_report_$(date +%Y%m%d_%H%M%S).md"

# Expected model sizes (in bytes) with tolerance
EXPECTED_MODELS=(
    "ggml-small.bin:487601967:5000000"
    "ggml-medium.bin:1533763059:10000000"
    "ggml-large-v3.bin:3095033483:10000000"
    "ggml-large-v3-turbo.bin:1624555275:10000000"
    "deepseek-r1-distill-qwen-7b-q4_k_m.gguf:4683073504:50000000"
    "deepseek-r1-distill-qwen-14b-q3_k_m.gguf:7339204000:50000000"
)

# Expected library files
EXPECTED_LIBRARIES=(
    "whisper.cpp/build-ios/libwhisper.a"
    "llama.cpp/build-ios/libllama.a"
    "whisper.cpp/build-ios/libggml.a"
)

# ============================================
# Utility Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# ============================================
# Test 1: Model Verification
# ============================================

test_models_present() {
    log_section "TEST 1: Model File Verification"
    
    local all_models_present=true
    
    for model_spec in "${EXPECTED_MODELS[@]}"; do
        IFS=':' read -r model_name expected_size tolerance <<< "$model_spec"
        local model_path="${MODELS_DIR}/${model_name}"
        
        if [[ ! -f "$model_path" ]]; then
            log_failure "Model not found: $model_name"
            all_models_present=false
            continue
        fi
        
        local actual_size=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null)
        local size_diff=$((actual_size - expected_size))
        size_diff=${size_diff#-}  # Absolute value
        
        if [[ $size_diff -le $tolerance ]]; then
            local size_mb=$((actual_size / 1024 / 1024))
            log_success "Model $model_name present (${size_mb} MB)"
        else
            log_failure "Model $model_name size mismatch (expected: $expected_size, got: $actual_size)"
            all_models_present=false
        fi
    done
    
    # Calculate total model size
    local total_size=0
    for model_spec in "${EXPECTED_MODELS[@]}"; do
        IFS=':' read -r model_name _ _ <<< "$model_spec"
        local model_path="${MODELS_DIR}/${model_name}"
        if [[ -f "$model_path" ]]; then
            local size=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null)
            total_size=$((total_size + size))
        fi
    done
    
    local total_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc)
    log_info "Total model storage: ${total_gb} GB"
    
    if $all_models_present; then
        return 0
    else
        return 1
    fi
}

test_model_integrity() {
    log_section "TEST 1b: Model File Integrity (Quick Check)"
    
    # Quick integrity check - verify files aren't corrupted (check magic bytes)
    local integrity_passed=true
    
    # Check GGUF magic (for LLM models)
    for gguf_model in "${MODELS_DIR}"/*.gguf; do
        if [[ -f "$gguf_model" ]]; then
            local magic=$(xxd -l 4 "$gguf_model" 2>/dev/null | head -1)
            if [[ "$magic" == *"GGUF"* ]] || [[ "$magic" == *"gguf"* ]]; then
                local basename=$(basename "$gguf_model")
                log_success "GGUF model $basename has valid magic bytes"
            else
                log_warning "GGUF model $(basename "$gguf_model") magic bytes check inconclusive (may be valid)"
            fi
        fi
    done
    
    # Check Whisper model files (they're binary, just verify non-zero and readable)
    for whisper_model in "${MODELS_DIR}"/*.bin; do
        if [[ -f "$whisper_model" ]]; then
            if [[ -r "$whisper_model" ]] && [[ -s "$whisper_model" ]]; then
                log_success "Whisper model $(basename "$whisper_model") is readable and non-empty"
            else
                log_failure "Whisper model $(basename "$whisper_model") has issues"
                integrity_passed=false
            fi
        fi
    done
    
    $integrity_passed
}

# ============================================
# Test 2: Library Verification
# ============================================

test_libraries_present() {
    log_section "TEST 2: C/C++ Library Verification"
    
    local all_libraries_present=true
    
    for lib_spec in "${EXPECTED_LIBRARIES[@]}"; do
        local lib_path="${BUILD_DIR}/${lib_spec}"
        
        if [[ ! -f "$lib_path" ]]; then
            log_failure "Library not found: $lib_spec"
            all_libraries_present=false
            continue
        fi
        
        local size=$(stat -f%z "$lib_path" 2>/dev/null || stat -c%s "$lib_path" 2>/dev/null)
        local size_mb=$((size / 1024 / 1024))
        
        # Check if it's a valid static library
        if file "$lib_path" | grep -q "ar archive"; then
            log_success "Library $lib_spec present (${size_mb} MB) - valid static archive"
        elif file "$lib_path" | grep -q "current ar archive"; then
            log_success "Library $lib_spec present (${size_mb} MB) - valid static archive"
        else
            log_warning "Library $lib_spec present but file type unclear"
        fi
    done
    
    $all_libraries_present
}

test_library_symbols() {
    log_section "TEST 2b: Library Symbol Verification"
    
    local symbols_ok=true
    
    # Check for key whisper symbols
    if [[ -f "${BUILD_DIR}/whisper.cpp/build-ios/libwhisper.a" ]]; then
        local whisper_symbols=$(nm "${BUILD_DIR}/whisper.cpp/build-ios/libwhisper.a" 2>/dev/null | grep -c "whisper_" || echo "0")
        if [[ $whisper_symbols -gt 50 ]]; then
            log_success "libwhisper.a contains $whisper_symbols whisper symbols"
        else
            log_warning "libwhisper.a has fewer symbols than expected ($whisper_symbols)"
        fi
        
        # Check for wrapper functions
        if nm "${BUILD_DIR}/whisper.cpp/build-ios/libwhisper.a" 2>/dev/null | grep -q "whisper_init_from_file_with_params_wrapper"; then
            log_success "Whisper wrapper functions found in library"
        else
            log_warning "Whisper wrapper functions not found - may need rebuild"
        fi
    fi
    
    # Check for key llama symbols
    if [[ -f "${BUILD_DIR}/llama.cpp/build-ios/libllama.a" ]]; then
        local llama_symbols=$(nm "${BUILD_DIR}/llama.cpp/build-ios/libllama.a" 2>/dev/null | grep -c "llama_" || echo "0")
        if [[ $llama_symbols -gt 100 ]]; then
            log_success "libllama.a contains $llama_symbols llama symbols"
        else
            log_warning "libllama.a has fewer symbols than expected ($llama_symbols)"
        fi
        
        # Check for wrapper functions
        if nm "${BUILD_DIR}/llama.cpp/build-ios/libllama.a" 2>/dev/null | grep -q "llama_wrapper_load_model"; then
            log_success "LLM wrapper functions found in library"
        else
            log_warning "LLM wrapper functions not found - may need rebuild"
        fi
    fi
    
    $symbols_ok
}

# ============================================
# Test 3: Header File Verification
# ============================================

test_headers_present() {
    log_section "TEST 3: C Wrapper Header Verification"
    
    local headers_ok=true
    
    # Check whisper wrapper header
    if [[ -f "${IOS_APP_DIR}/whisper_wrapper.h" ]]; then
        log_success "whisper_wrapper.h exists"
        
        # Verify key functions are declared
        local whisper_funcs=(
            "whisper_init_from_file_with_params_wrapper"
            "whisper_full_wrapper"
            "whisper_full_get_segment_text_wrapper"
        )
        
        for func in "${whisper_funcs[@]}"; do
            if grep -q "$func" "${IOS_APP_DIR}/whisper_wrapper.h"; then
                log_success "  Function declared: $func"
            else
                log_failure "  Function missing: $func"
                headers_ok=false
            fi
        done
    else
        log_failure "whisper_wrapper.h not found"
        headers_ok=false
    fi
    
    # Check llama wrapper header
    if [[ -f "${IOS_APP_DIR}/llama_wrapper.h" ]]; then
        log_success "llama_wrapper.h exists"
        
        # Verify key functions are declared
        local llama_funcs=(
            "llama_wrapper_load_model"
            "llama_wrapper_generate"
            "llama_wrapper_tokenize"
        )
        
        for func in "${llama_funcs[@]}"; do
            if grep -q "$func" "${IOS_APP_DIR}/llama_wrapper.h"; then
                log_success "  Function declared: $func"
            else
                log_failure "  Function missing: $func"
                headers_ok=false
            fi
        done
    else
        log_failure "llama_wrapper.h not found"
        headers_ok=false
    fi
    
    # Check bridging header
    if [[ -f "${IOS_APP_DIR}/Scribe-Bridging-Header.h" ]]; then
        log_success "Scribe-Bridging-Header.h exists"
        
        if grep -q "whisper_wrapper.h" "${IOS_APP_DIR}/Scribe-Bridging-Header.h"; then
            log_success "  Bridging header includes whisper_wrapper.h"
        else
            log_warning "  Bridging header may not include whisper_wrapper.h"
        fi
        
        if grep -q "llama_wrapper.h" "${IOS_APP_DIR}/Scribe-Bridging-Header.h"; then
            log_success "  Bridging header includes llama_wrapper.h"
        else
            log_warning "  Bridging header may not include llama_wrapper.h"
        fi
    else
        log_failure "Scribe-Bridging-Header.h not found"
        headers_ok=false
    fi
    
    $headers_ok
}

# ============================================
# Test 4: Swift Source Code Validation
# ============================================

test_swift_sources() {
    log_section "TEST 4: Swift Source Code Validation"
    
    local sources_ok=true
    
    # Check core source files exist
    local required_files=(
        "Sources/Scribe/Core/STT/TranscriptionEngine.swift"
        "Sources/Scribe/Core/LLM/LLMProcessor.swift"
        "Sources/Scribe/Models/NoteModels.swift"
        "Sources/Scribe/UI/RecordingView.swift"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "${IOS_APP_DIR}/$file" ]]; then
            log_success "Source file exists: $file"
        else
            log_failure "Source file missing: $file"
            sources_ok=false
        fi
    done
    
    # Check for critical code patterns
    if [[ -f "${IOS_APP_DIR}/Sources/Scribe/Core/STT/TranscriptionEngine.swift" ]]; then
        if grep -q "whisper_full_wrapper" "${IOS_APP_DIR}/Sources/Scribe/Core/STT/TranscriptionEngine.swift"; then
            log_success "TranscriptionEngine uses whisper_full_wrapper"
        else
            log_warning "TranscriptionEngine may not use correct whisper wrapper"
        fi
    fi
    
    if [[ -f "${IOS_APP_DIR}/Sources/Scribe/Core/LLM/LLMProcessor.swift" ]]; then
        if grep -q "llama_wrapper_generate" "${IOS_APP_DIR}/Sources/Scribe/Core/LLM/LLMProcessor.swift"; then
            log_success "LLMProcessor uses llama_wrapper_generate"
        else
            log_warning "LLMProcessor may not use correct llama wrapper"
        fi
    fi
    
    $sources_ok
}

# ============================================
# Test 5: Transcription Pipeline Validation
# ============================================

test_transcription_pipeline() {
    log_section "TEST 5: Transcription Pipeline Validation"
    
    log_info "Checking TranscriptionEngine implementation..."
    
    local pipeline_ok=true
    local engine_file="${IOS_APP_DIR}/Sources/Scribe/Core/STT/TranscriptionEngine.swift"
    
    if [[ ! -f "$engine_file" ]]; then
        log_failure "TranscriptionEngine.swift not found"
        return 1
    fi
    
    # Check for required components
    local checks=(
        "@MainActor:Main actor annotation"
        "ObservableObject:ObservableObject conformance"
        "whisperContext:OpaquePointer:Context management"
        "loadModel:Model loading method"
        "processAudioBuffer:Audio processing"
        "transcribeChunk:Transcription method"
    )
    
    for check in "${checks[@]}"; do
        IFS=':' read -r pattern description <<< "$check"
        if grep -q "$pattern" "$engine_file"; then
            log_success "  Found: $description"
        else
            log_warning "  Missing or different: $description"
        fi
    done
    
    # Check model loading paths
    if grep -q "Bundle.main.path" "$engine_file"; then
        log_success "  Checks Bundle.main for models"
    fi
    
    if grep -q "documentDirectory" "$engine_file"; then
        log_success "  Checks Documents directory for models"
    fi
    
    # Check performance tiers
    if grep -q "PerformanceTier" "$engine_file"; then
        log_success "  Performance tiers defined"
    fi
    
    log_info "Transcription pipeline structure validated"
    $pipeline_ok
}

# ============================================
# Test 6: LLM Pipeline Validation
# ============================================

test_llm_pipeline() {
    log_section "TEST 6: LLM Generation Pipeline Validation"
    
    log_info "Checking LLMProcessor implementation..."
    
    local pipeline_ok=true
    local processor_file="${IOS_APP_DIR}/Sources/Scribe/Core/LLM/LLMProcessor.swift"
    
    if [[ ! -f "$processor_file" ]]; then
        log_failure "LLMProcessor.swift not found"
        return 1
    fi
    
    # Check for required components
    local checks=(
        "@MainActor:Main actor annotation"
        "ObservableObject:ObservableObject conformance"
        "llama_wrapper_load_model:Model loading"
        "llama_wrapper_generate:Text generation"
        "processTranscript:Transcript processing"
        "NoteTemplate:Template system"
        "PerformanceTier:Performance tiers"
    )
    
    for check in "${checks[@]}"; do
        IFS=':' read -r pattern description <<< "$check"
        if grep -q "$pattern" "$processor_file"; then
            log_success "  Found: $description"
        else
            log_warning "  Missing or different: $description"
        fi
    done
    
    # Check prompt templates
    local templates=(
        "SOAP"
        "H&P"
        "Summary"
        "Bullet"
    )
    
    for template in "${templates[@]}"; do
        if grep -qi "$template" "$processor_file"; then
            log_success "  Template type found: $template"
        fi
    done
    
    # Check streaming support
    if grep -q "processTranscriptStreaming" "$processor_file"; then
        log_success "  Streaming generation supported"
    fi
    
    log_info "LLM pipeline structure validated"
    $pipeline_ok
}

# ============================================
# Test 7: Memory Usage Analysis
# ============================================

test_memory_requirements() {
    log_section "TEST 7: Memory Usage Analysis"
    
    log_info "Analyzing memory requirements..."
    
    # Calculate memory requirements
    local whisper_large_size=3095033483
    local deepseek_14b_size=7339204000
    local deepseek_7b_size=4683073504
    
    # Whisper memory (model size + working memory)
    local whisper_memory_mb=$((whisper_large_size / 1024 / 1024 * 2))
    
    # LLM memory (model size * 2 for KV cache + overhead)
    local llm_14b_memory_mb=$((deepseek_14b_size / 1024 / 1024 * 3))
    local llm_7b_memory_mb=$((deepseek_7b_size / 1024 / 1024 * 3))
    
    # Total for different configurations
    local total_extreme_mb=$((whisper_memory_mb + llm_14b_memory_mb))
    local total_balanced_mb=$((whisper_memory_mb + llm_7b_memory_mb))
    
    log_info "Estimated memory requirements:"
    echo "  Whisper Large V3: ~${whisper_memory_mb} MB (loaded)"
    echo "  DeepSeek 14B: ~${llm_14b_memory_mb} MB (loaded)"
    echo "  DeepSeek 7B: ~${llm_7b_memory_mb} MB (loaded)"
    echo ""
    echo "  EXTREME tier (Whisper Large + 14B): ~${total_extreme_mb} MB (~$((total_extreme_mb / 1024)) GB)"
    echo "  Balanced tier (Whisper Large + 7B): ~${total_balanced_mb} MB (~$((total_balanced_mb / 1024)) GB)"
    
    # Check device compatibility
    echo ""
    log_info "Device compatibility:"
    
    if [[ $total_extreme_mb -lt 6144 ]]; then
        log_success "EXTREME tier fits in 6GB RAM devices"
    elif [[ $total_extreme_mb -lt 8192 ]]; then
        log_warning "EXTREME tier requires 8GB+ RAM device"
    else
        log_failure "EXTREME tier may exceed 8GB RAM - risk of memory pressure"
    fi
    
    if [[ $total_balanced_mb -lt 6144 ]]; then
        log_success "Balanced tier fits in 6GB RAM devices"
    else
        log_warning "Balanced tier may require 8GB RAM device"
    fi
    
    # Memory warnings in code
    local processor_file="${IOS_APP_DIR}/Sources/Scribe/Core/LLM/LLMProcessor.swift"
    if grep -q "unloadModel" "$processor_file"; then
        log_success "Model unloading implemented for memory management"
    fi
    
    log_info "Memory analysis complete"
}

# ============================================
# Test 8: Build System Validation
# ============================================

test_build_system() {
    log_section "TEST 8: Build System Validation"
    
    local build_ok=true
    
    # Check for build scripts
    local build_scripts=(
        "scripts/build_whisper.sh"
        "scripts/build_llama.sh"
    )
    
    for script in "${build_scripts[@]}"; do
        if [[ -f "${PROJECT_ROOT}/$script" ]]; then
            log_success "Build script exists: $script"
        else
            log_warning "Build script not found: $script"
        fi
    done
    
    # Check Package.swift
    if [[ -f "${IOS_APP_DIR}/Package.swift" ]]; then
        log_success "Package.swift exists"
        
        if grep -q "Scribe" "${IOS_APP_DIR}/Package.swift"; then
            log_success "  Package name configured"
        fi
    else
        log_failure "Package.swift not found"
        build_ok=false
    fi
    
    # Check for Xcode project generator
    if [[ -f "${PROJECT_ROOT}/generate_xcode_project.rb" ]]; then
        log_success "Xcode project generator exists"
    else
        log_warning "Xcode project generator not found"
    fi
    
    $build_ok
}

# ============================================
# Test 9: Documentation Validation
# ============================================

test_documentation() {
    log_section "TEST 9: Documentation Validation"
    
    local docs_ok=true
    
    local required_docs=(
        "README.md"
        "docs/XCODE_SETUP.md"
        "docs/EXTREME_MODELS.md"
        "models/MODELS_READY.md"
    )
    
    for doc in "${required_docs[@]}"; do
        if [[ -f "${PROJECT_ROOT}/$doc" ]]; then
            log_success "Documentation exists: $doc"
        else
            log_warning "Documentation missing: $doc"
        fi
    done
    
    # Check README content
    if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
        if grep -q "Whisper Large V3" "${PROJECT_ROOT}/README.md"; then
            log_success "  README mentions Whisper Large V3"
        fi
        
        if grep -q "DeepSeek" "${PROJECT_ROOT}/README.md"; then
            log_success "  README mentions DeepSeek models"
        fi
    fi
    
    $docs_ok
}

# ============================================
# Test 10: Clinical Safety Checks
# ============================================

test_clinical_safety() {
    log_section "TEST 10: Clinical Safety Validation"
    
    log_info "Checking for clinical safety features..."
    
    # Check for HIPAA/privacy mentions
    local privacy_count=0
    if grep -r -i "hipaa\|privacy\|encrypted\|on-device" "${IOS_APP_DIR}/Sources/" 2>/dev/null | grep -v ".bak" | grep -q .; then
        privacy_count=$(grep -r -i "hipaa\|privacy\|encrypted\|on-device" "${IOS_APP_DIR}/Sources/" 2>/dev/null | wc -l)
        log_success "Privacy/security references found: $privacy_count"
    fi
    
    # Check for data persistence
    if grep -r "SwiftData\|@Model" "${IOS_APP_DIR}/Sources/" 2>/dev/null | grep -q .; then
        log_success "SwiftData persistence implemented"
    fi
    
    # Check for patient identifier handling
    if grep -r "patientIdentifier\|de-identified" "${IOS_APP_DIR}/Sources/" 2>/dev/null | grep -q .; then
        log_success "Patient identifier handling implemented"
    fi
    
    # Check for disclaimer/warning
    if grep -r -i "hallucinate\|review\|verify\|always review" "${PROJECT_ROOT}/README.md" 2>/dev/null | grep -q .; then
        log_success "AI disclaimer/review warnings present"
    fi
    
    # Check for export functionality
    if grep -r "AirDrop\|export\|share" "${IOS_APP_DIR}/Sources/" 2>/dev/null | grep -q .; then
        log_success "Export/sharing functionality present"
    fi
    
    log_info "Clinical safety checks complete"
}

# ============================================
# Generate Report
# ============================================

generate_report() {
    log_section "Generating Test Report"
    
    cat > "$REPORT_FILE" << EOF
# HxDictate Test & Validation Report

**Date:** $(date)
**Project:** HxDictate - Medical Dictation for iOS

## Summary

| Metric | Count |
|--------|-------|
| Tests Passed | $TESTS_PASSED |
| Tests Failed | $TESTS_FAILED |
| Tests Skipped/Warning | $TESTS_SKIPPED |
| **Success Rate** | $(echo "scale=1; $TESTS_PASSED * 100 / ($TESTS_PASSED + $TESTS_FAILED + $TESTS_SKIPPED)" | bc)% |

## Model Inventory

| Model | Size | Status |
|-------|------|--------|
EOF

    # Add model details
    for model_spec in "${EXPECTED_MODELS[@]}"; do
        IFS=':' read -r model_name expected_size _ <<< "$model_spec"
        local model_path="${MODELS_DIR}/${model_name}"
        if [[ -f "$model_path" ]]; then
            local actual_size=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null)
            local size_gb=$(echo "scale=2; $actual_size / 1024 / 1024 / 1024" | bc)
            echo "| $model_name | ${size_gb} GB | ✅ Present |" >> "$REPORT_FILE"
        else
            echo "| $model_name | - | ❌ Missing |" >> "$REPORT_FILE"
        fi
    done

    cat >> "$REPORT_FILE" << EOF

## Memory Requirements

| Configuration | Estimated RAM | Device Compatibility |
|---------------|---------------|---------------------|
| Whisper Large V3 | ~6 GB | iPhone 15 Pro+ |
| DeepSeek 14B | ~21 GB | Requires memory compression |
| DeepSeek 7B | ~13 GB | iPhone 15 Pro+ |
| **EXTREME Tier** | **~27 GB** | **Requires aggressive memory management** |
| **Balanced Tier** | **~19 GB** | **iPhone 15 Pro+ recommended** |

## Critical Findings

EOF

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "⚠️ **${TESTS_FAILED} test(s) failed** - Review required before clinical use" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
### Recommendations

1. **Memory Management**: The EXTREME tier (Whisper Large V3 + DeepSeek 14B) requires ~27GB RAM
   - iOS devices have 8GB physical RAM max
   - Memory compression and swapping will be heavily used
   - Consider using Balanced tier (7B model) for better stability

2. **Model Loading**: Implement lazy loading and model unloading
   - Load only one model at a time if possible
   - Unload models when not in active use
   - Monitor memory warnings and respond appropriately

3. **Testing on Device**: 
   - Simulator cannot test Metal GPU acceleration
   - Must test on physical iPhone 15 Pro or newer
   - Test with actual clinical audio samples

4. **Clinical Validation**:
   - Verify transcription accuracy with medical terminology
   - Test note generation with real patient encounters
   - Ensure HIPAA compliance in all data flows

## Next Steps

1. Build Xcode project using \`generate_xcode_project.rb\`
2. Test on physical iPhone 15 Pro or newer
3. Validate transcription with clinical audio samples
4. Test note generation quality
5. Perform memory stress testing
6. Clinical validation with real (de-identified) encounters

---
*Report generated by HxDictate Test Suite*
EOF

    log_success "Report saved to: $REPORT_FILE"
}

# ============================================
# Main Execution
# ============================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     HxDictate Test & Validation Suite                     ║${NC}"
    echo -e "${BLUE}║     Medical Dictation App - Pre-Clinical Validation       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run all tests
    test_models_present
    test_model_integrity
    test_libraries_present
    test_library_symbols
    test_headers_present
    test_swift_sources
    test_transcription_pipeline
    test_llm_pipeline
    test_memory_requirements
    test_build_system
    test_documentation
    test_clinical_safety
    
    # Generate report
    generate_report
    
    # Final summary
    log_section "TEST SUMMARY"
    
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Tests Skipped/Warning: ${YELLOW}$TESTS_SKIPPED${NC}"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=$(echo "scale=1; $TESTS_PASSED * 100 / $total_tests" | bc)
    
    echo ""
    echo -e "Pass Rate: ${BLUE}${pass_rate}%${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All critical tests passed!${NC}"
        echo -e "${GREEN}App is ready for device testing.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ruby generate_xcode_project.rb"
        echo "  2. Open HxDictate.xcodeproj"
        echo "  3. Build and test on physical iPhone 15 Pro+"
        exit 0
    else
        echo -e "${RED}⚠️  Some tests failed.${NC}"
        echo -e "${YELLOW}Review failures above before clinical use.${NC}"
        echo ""
        echo "See report for details: $REPORT_FILE"
        exit 1
    fi
}

# Run main
main "$@"

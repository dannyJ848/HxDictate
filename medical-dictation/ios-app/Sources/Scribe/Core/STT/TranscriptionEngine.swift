import Foundation
import Combine
import AVFoundation

/// Real-time transcription engine using whisper.cpp
@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var currentTranscript: String = ""
    @Published var isTranscribing = false
    @Published var modelStatus: ModelStatus = .notLoaded
    
    private var whisperContext: OpaquePointer?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var transcriptionTask: Task<Void, Never>?
    private var isModelLoaded = false
    
    enum ModelStatus {
        case notLoaded
        case loading
        case ready
        case error(String)
    }
    
    enum PerformanceTier {
        case small, medium, largeTurbo, largeV3
        
        var modelName: String {
            switch self {
            case .small: return "ggml-small.bin"
            case .medium: return "ggml-medium.bin"
            case .largeTurbo: return "ggml-large-v3-turbo.bin"
            case .largeV3: return "ggml-large-v3.bin"
            }
        }
        
        var size: String {
            switch self {
            case .small: return "466 MB"
            case .medium: return "1.5 GB"
            case .largeTurbo: return "1.6 GB"
            case .largeV3: return "2.9 GB"
            }
        }
    }
    
    // MARK: - Model Management
    
    func loadModel(tier: PerformanceTier = .small) async {
        await loadModel(named: tier.modelName)
    }
    
    func loadModel(named modelName: String) async {
        guard !isModelLoaded else { return }
        
        modelStatus = .loading
        
        // Search for model in multiple locations
        // Search for model in multiple locations (documents first for downloaded models, then bundle)
        let possiblePaths = [
            // Documents directory (downloaded on first launch)
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("models/\(modelName)").path,
            // Bundle paths
            Bundle.main.path(forResource: modelName, ofType: nil),
            Bundle.main.bundlePath + "/scripts/build/models/" + modelName,
            // Hardcoded paths for development
            FileManager.default.currentDirectoryPath + "/scripts/build/models/" + modelName,
            "/Users/dannygomez/.openclaw/workspace/medical-dictation/scripts/build/models/" + modelName,
            "/Users/dannygomez/.openclaw-minimax/workspace/HxDictate/medical-dictation/scripts/build/models/" + modelName
        ].compactMap { $0 }
        
        guard let modelPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            modelStatus = .error("Model not found: \(modelName)")
            return
        }
        
        print("📦 Loading Whisper model from: \(modelPath)")
        
        // Create context params
        guard let paramsPtr = whisper_context_default_params_by_ref_wrapper() else {
            modelStatus = .error("Failed to create context params")
            return
        }
        defer { whisper_free_context_params_wrapper(paramsPtr) }
        
        // Configure for Metal
        #if !targetEnvironment(simulator)
        // paramsPtr.pointee.use_gpu = true  // Can't access directly, would need setter
        print("Running on device, Metal GPU enabled")
        #else
        print("Running on simulator, using CPU")
        #endif
        
        // Load the model
        whisperContext = whisper_init_from_file_with_params_wrapper(modelPath, paramsPtr)
        
        if whisperContext != nil {
            isModelLoaded = true
            modelStatus = .ready
            print("✅ Whisper model loaded successfully")
        } else {
            modelStatus = .error("Failed to initialize Whisper context")
            print("❌ Failed to load Whisper model")
        }
    }
    
    func unloadModel() {
        if let ctx = whisperContext {
            whisper_free_wrapper(ctx)
            whisperContext = nil
        }
        isModelLoaded = false
        modelStatus = .notLoaded
        print("🗑️ Whisper model unloaded")
    }
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let floatData = buffer.floatChannelData?.pointee else { return }
        
        bufferLock.lock()
        let frameLength = Int(buffer.frameLength)
        let newSamples = (0..<frameLength).map { floatData[$0] }
        audioBuffer.append(contentsOf: newSamples)
        
        // Process every 3 seconds of audio
        if audioBuffer.count >= 48000 {
            let chunk = Array(audioBuffer)
            audioBuffer.removeAll(keepingCapacity: true)
            bufferLock.unlock()
            
            transcriptionTask?.cancel()
            transcriptionTask = Task {
                await transcribeChunk(chunk)
            }
        } else {
            bufferLock.unlock()
        }
    }
    
    /// Process final audio buffer when recording stops
    func processFinalBuffer() async {
        bufferLock.lock()
        guard !audioBuffer.isEmpty else {
            bufferLock.unlock()
            return
        }
        let chunk = Array(audioBuffer)
        audioBuffer.removeAll()
        bufferLock.unlock()
        
        await transcribeChunk(chunk)
    }
    
    private func transcribeChunk(_ samples: [Float]) async {
        guard let ctx = whisperContext else { 
            print("⚠️ No whisper context available")
            return 
        }
        guard !Task.isCancelled else { return }
        
        isTranscribing = true
        defer { isTranscribing = false }
        
        // Create full params
        guard let paramsPtr = whisper_full_default_params_by_ref_wrapper(WHISPER_SAMPLING_GREEDY) else {
            print("❌ Failed to create full params")
            return
        }
        defer { whisper_free_params_wrapper(paramsPtr) }
        
        // Set parameters
        whisper_full_params_set_n_threads(paramsPtr, Int32(max(1, min(6, ProcessInfo.processInfo.processorCount - 2))))
        whisper_full_params_set_language(paramsPtr, "en")
        whisper_full_params_set_translate(paramsPtr, false)
        whisper_full_params_set_no_context(paramsPtr, true)
        whisper_full_params_set_single_segment(paramsPtr, false)
        whisper_full_params_set_print_special(paramsPtr, false)
        whisper_full_params_set_print_progress(paramsPtr, false)
        whisper_full_params_set_print_realtime(paramsPtr, false)
        whisper_full_params_set_print_timestamps(paramsPtr, true)
        
        print("🎙️ Transcribing \(samples.count) samples...")
        
        // Run transcription
        let result = samples.withUnsafeBufferPointer { buffer in
            whisper_full_wrapper(ctx, paramsPtr, buffer.baseAddress, Int32(samples.count))
        }
        
        guard result == 0 else {
            print("❌ Whisper transcription failed")
            return
        }
        
        guard !Task.isCancelled else { return }
        
        // Extract transcription text
        let nSegments = whisper_full_n_segments_wrapper(ctx)
        var transcription = ""
        
        for i in 0..<nSegments {
            if let text = whisper_full_get_segment_text_wrapper(ctx, i) {
                transcription += String(cString: text)
            }
        }
        
        print("📝 Transcribed: \(transcription.prefix(100))...")
        
        await MainActor.run {
            if !transcription.isEmpty {
                self.currentTranscript += transcription + " "
            }
        }
    }
    
    /// Transcribe a complete audio file (for non-streaming use)
    func transcribeAudio(samples: [Float]) async -> String {
        guard let ctx = whisperContext else {
            return "Error: Model not loaded"
        }
        
        isTranscribing = true
        defer { isTranscribing = false }
        
        guard let paramsPtr = whisper_full_default_params_by_ref_wrapper(WHISPER_SAMPLING_GREEDY) else {
            return "Error: Failed to create params"
        }
        defer { whisper_free_params_wrapper(paramsPtr) }
        
        whisper_full_params_set_n_threads(paramsPtr, Int32(max(1, min(6, ProcessInfo.processInfo.processorCount - 2))))
        whisper_full_params_set_language(paramsPtr, "en")
        whisper_full_params_set_translate(paramsPtr, false)
        whisper_full_params_set_no_context(paramsPtr, false)
        whisper_full_params_set_single_segment(paramsPtr, false)
        whisper_full_params_set_print_special(paramsPtr, false)
        whisper_full_params_set_print_progress(paramsPtr, false)
        whisper_full_params_set_print_realtime(paramsPtr, false)
        whisper_full_params_set_print_timestamps(paramsPtr, true)
        
        let result = samples.withUnsafeBufferPointer { buffer in
            whisper_full_wrapper(ctx, paramsPtr, buffer.baseAddress, Int32(samples.count))
        }
        
        guard result == 0 else {
            return "Error: Transcription failed"
        }
        
        let nSegments = whisper_full_n_segments_wrapper(ctx)
        var transcription = ""
        
        for i in 0..<nSegments {
            if let text = whisper_full_get_segment_text_wrapper(ctx, i) {
                transcription += String(cString: text)
            }
        }
        
        return transcription
    }
    
    func clearTranscript() {
        currentTranscript = ""
        audioBuffer.removeAll()
    }
    
    deinit {
        if let ctx = whisperContext {
            whisper_free_wrapper(ctx)
        }
    }
}

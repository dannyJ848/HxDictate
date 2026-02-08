import Foundation
import Combine
import AVFoundation

/// Bridges to whisper.cpp for on-device STT
@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var currentTranscript: String = ""
    @Published var isTranscribing = false
    @Published var modelStatus: ModelStatus = .notLoaded
    
    private var whisperContext: OpaquePointer?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var transcriptionTask: Task<Void, Never>?
    
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
        modelStatus = .loading
        
        // Try multiple locations for model
        let possiblePaths = [
            // 1. App bundle
            Bundle.main.path(forResource: modelName, ofType: nil),
            // 2. Documents directory (for download-on-first-launch)
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent(modelName).path,
            // 3. Build directory (development)
            FileManager.default.currentDirectoryPath + "/scripts/build/models/" + modelName,
            // 4. Absolute path from workspace
            "/Users/dannygomez/.openclaw/workspace/medical-dictation/scripts/build/models/" + modelName
        ].compactMap { $0 }
        
        guard let modelPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            modelStatus = .error("Model not found: \(modelName). Checked paths: \(possiblePaths)")
            return
        }
        
        // whisper.cpp C bridge call
        let params = whisper_context_default_params()
        whisperContext = whisper_init_from_file_with_params(modelPath, params)
        
        if whisperContext != nil {
            modelStatus = .ready
        } else {
            modelStatus = .error("Failed to initialize Whisper context")
        }
    }
    
    func unloadModel() {
        if let ctx = whisperContext {
            whisper_free(ctx)
            whisperContext = nil
        }
        modelStatus = .notLoaded
    }
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let floatData = buffer.floatChannelData?.pointee else { return }
        
        bufferLock.lock()
        let frameLength = Int(buffer.frameLength)
        let newSamples = (0..<frameLength).map { floatData[$0] }
        audioBuffer.append(contentsOf: newSamples)
        
        // Process every 3 seconds of audio (48000 samples @ 16kHz)
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
    
    private func transcribeChunk(_ samples: [Float]) async {
        guard let ctx = whisperContext else { return }
        guard !Task.isCancelled else { return }
        
        isTranscribing = true
        defer { isTranscribing = false }
        
        // whisper.cpp parameters
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = false
        params.language = "en"
        params.n_threads = 4 // iPhone 17 Pro has 6 performance cores
        
        let result = whisper_full(ctx, params, samples, Int32(samples.count))
        
        guard result == 0 else {
            print("Whisper transcription failed with code: \(result)")
            return
        }
        
        let segmentCount = whisper_full_n_segments(ctx)
        var transcript = ""
        
        for i in 0..<segmentCount {
            if let text = whisper_full_get_segment_text(ctx, i) {
                transcript += String(cString: text) + " "
            }
        }
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            self.currentTranscript += transcript.trimmingCharacters(in: .whitespaces) + " "
        }
    }
    
    func clearTranscript() {
        currentTranscript = ""
        audioBuffer.removeAll()
    }
}

// C function declarations (would be in a bridging header)
// These are placeholders - actual implementation needs whisper.cpp headers
struct whisper_context {}
struct whisper_full_params {}
enum whisper_sampling_strategy: Int32 {
    case WHISPER_SAMPLING_GREEDY = 0
}
func whisper_context_default_params() -> whisper_full_params { fatalError() }
func whisper_init_from_file_with_params(_ path: String, _ params: whisper_full_params) -> OpaquePointer? { fatalError() }
func whisper_free(_ ctx: OpaquePointer) {}
func whisper_full_default_params(_ strategy: whisper_sampling_strategy) -> whisper_full_params { fatalError() }
func whisper_full(_ ctx: OpaquePointer, _ params: whisper_full_params, _ samples: [Float], _ n_samples: Int32) -> Int32 { fatalError() }
func whisper_full_n_segments(_ ctx: OpaquePointer) -> Int32 { fatalError() }
func whisper_full_get_segment_text(_ ctx: OpaquePointer, _ segment: Int32) -> UnsafePointer<CChar>? { fatalError() }

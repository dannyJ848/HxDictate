import AVFoundation
import Combine

/// Manages audio capture for transcription
@MainActor
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var bufferSize: UInt32 = 4096
    
    /// Callback for audio buffer (delivered to Whisper)
    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    
    func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    func startRecording() throws {
        guard !isRecording else { return }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        inputNode = engine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)
        
        // Whisper expects 16kHz mono PCM
        let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        
        guard let converter = AVAudioConverter(from: recordingFormat, to: whisperFormat) else {
            throw AudioError.formatConversionFailed
        }
        
        inputNode!.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Convert to Whisper format
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: whisperFormat,
                frameCapacity: AVAudioFrameCount(whisperFormat.sampleRate * 0.1) // 100ms chunks
            ) else { return }
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            // Calculate audio level for UI
            self.updateAudioLevel(buffer: buffer)
            
            // Dispatch to transcription engine
            self.onAudioBuffer?(convertedBuffer, time)
        }
        
        try engine.start()
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        isRecording = false
        audioLevel = 0.0
    }
    
    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        DispatchQueue.main.async {
            self.audioLevel = self.scaledPower(power: avgPower)
        }
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else { return 0.0 }
        let minDb: Float = -80.0
        if power < minDb { return 0.0 }
        return (power - minDb) / (-minDb)
    }
}

enum AudioError: Error {
    case formatConversionFailed
    case engineStartFailed
}

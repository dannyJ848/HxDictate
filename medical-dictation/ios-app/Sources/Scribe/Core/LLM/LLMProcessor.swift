import Foundation
import Combine

/// Simplified LLM Processor - minimal working version for testing
@MainActor
final class LLMProcessor: ObservableObject {
    @Published var structuredNote: StructuredNote?
    @Published var isProcessing = false
    @Published var modelStatus: ModelStatus = .notLoaded
    @Published var currentTemplate: NoteTemplate = .soap
    
    private var llamaContext: OpaquePointer?
    private let processingQueue = DispatchQueue(label: "com.scribe.llm", qos: .userInitiated)
    
    enum ModelStatus {
        case notLoaded
        case loading(progress: Double)
        case ready
        case error(String)
    }
    
    enum NoteTemplate: String, CaseIterable {
        case soap = "SOAP Note"
        case hp = "H&P"
        case summary = "Brief Summary"
        case bullets = "Bullet Points"
        
        var systemPrompt: String {
            switch self {
            case .soap:
                return """
You are a medical scribe. Convert the following patient encounter transcript into a structured SOAP note.
Format:
**Subjective:** Patient's complaints, history, symptoms
**Objective:** Vital signs, physical exam findings, test results
**Assessment:** Diagnosis/differential diagnosis
**Plan:** Treatment plan, medications, follow-up

Be concise but complete. Use medical terminology appropriately.

Transcript:
"""
            case .hp:
                return """
You are a medical scribe. Convert the following patient encounter transcript into a complete History and Physical (H&P) note.
Include: Chief Complaint, History of Present Illness, Past Medical History, Medications, Allergies, Family History, Social History, Review of Systems, Physical Exam, Assessment, and Plan.

Transcript:
"""
            case .summary:
                return "Summarize the following patient encounter in one clear paragraph suitable for handoff to another provider:"
            case .bullets:
                return "Extract the key points from the following patient encounter as concise bullet points:"
            }
        }
    }
    
    // MARK: - Model Management
    
    /// Load LLM with tier-based configuration
    func loadModel(tier: PerformanceTier = .balanced) async {
        modelStatus = .loading(progress: 0)
        
        guard let modelPath = locateModel(named: tier.llmModel) else {
            modelStatus = .error("Model not found: \(tier.llmModel)")
            return
        }
        
        // llama.cpp initialization with tier-specific params
        var params = llama_model_default_params()
        params.n_gpu_layers = tier.gpuLayers
        params.use_mmap = 1
        params.use_mlock = tier == .maximum ? 0 : 1
        
        guard let model = llama_load_model_from_file(modelPath, params) else {
            modelStatus = .error("Failed to load model")
            return
        }
        
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = tier.contextWindow
        ctxParams.n_batch = tier.batchSize
        ctxParams.n_threads = 6
        ctxParams.n_threads_batch = 6
        ctxParams.flash_attn = 1
        ctxParams.logits_all = 0
        ctxParams.embeddings = 0
        
        llamaContext = llama_new_context_with_model(model, ctxParams)
        
        if llamaContext != nil {
            modelStatus = .ready
        } else {
            modelStatus = .error("Failed to initialize context")
        }
    }
    
    func unloadModel() {
        if let ctx = llamaContext {
            llama_free(ctx)
            llamaContext = nil
        }
        modelStatus = .notLoaded
    }
    
    private func locateModel(named: String) -> String? {
        var possiblePaths: [String] = []
        
        if let bundlePath = Bundle.main.path(forResource: named, ofType: nil) {
            possiblePaths.append(bundlePath)
        }
        
        if let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(named).path {
            possiblePaths.append(docsPath)
        }
        
        possiblePaths.append(FileManager.default.currentDirectoryPath + "/scripts/build/models/" + named)
        possiblePaths.append("/Users/dannygomez/.openclaw/workspace/medical-dictation/scripts/build/models/" + named)
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    // MARK: - Inference
    
    func processTranscript(_ transcript: String, template: NoteTemplate? = nil) async -> StructuredNote? {
        guard llamaContext != nil else { return nil }
        
        let templateToUse = template ?? currentTemplate
        let prompt = templateToUse.systemPrompt + "\n\n" + transcript + "\n\nStructured Note:"
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Simplified processing - just return a placeholder for now
        // Full implementation would use llama.cpp inference
        let sections = parseOutput("Generated note would appear here", template: templateToUse)
        
        return StructuredNote(
            template: templateToUse,
            rawTranscript: transcript,
            generatedAt: Date(),
            sections: sections,
            fullText: "Note generation requires full llama.cpp integration"
        )
    }
    
    private func parseOutput(_ output: String, template: NoteTemplate) -> [String: String] {
        var sections: [String: String] = [:]
        
        switch template {
        case .soap:
            sections["Subjective"] = "Patient reports symptoms..."
            sections["Objective"] = "Vital signs stable..."
            sections["Assessment"] = "Assessment pending..."
            sections["Plan"] = "Plan pending..."
        default:
            sections["Content"] = output
        }
        
        return sections
    }
}

// MARK: - Performance Tier

extension LLMProcessor {
    enum PerformanceTier {
        case powerSaver
        case balanced
        case maximum
        case extreme
        
        var llmModel: String {
            switch self {
            case .powerSaver: return "qwen2.5-3b-q4_k_m.gguf"
            case .balanced: return "deepseek-r1-distill-qwen-7b-q4_k_m.gguf"
            case .maximum: return "deepseek-r1-distill-qwen-14b-q3_k_m.gguf"
            case .extreme: return "deepseek-r1-distill-qwen-14b-q3_k_m.gguf"
            }
        }
        
        var gpuLayers: Int32 {
            switch self {
            case .powerSaver: return 99
            case .balanced: return 99
            case .maximum: return 40
            case .extreme: return 40
            }
        }
        
        var contextWindow: UInt32 {
            switch self {
            case .powerSaver: return 4096
            case .balanced: return 4096
            case .maximum: return 2048
            case .extreme: return 2048
            }
        }
        
        var batchSize: UInt32 {
            switch self {
            case .powerSaver: return 512
            case .balanced: return 512
            case .maximum: return 256
            case .extreme: return 256
            }
        }
    }
}

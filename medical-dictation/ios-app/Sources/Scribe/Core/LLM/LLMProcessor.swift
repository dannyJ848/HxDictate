import Foundation
import Combine

/// LLM Processor - Real llama.cpp integration for on-device inference
@MainActor
final class LLMProcessor: ObservableObject {
    @Published var structuredNote: StructuredNote?
    @Published var isProcessing = false
    @Published var modelStatus: ModelStatus = .notLoaded
    @Published var currentTemplate: NoteTemplate = .soap
    @Published var generationProgress: String = ""
    @Published var generatedText: String = ""
    
    // Private state - pointers to C structures
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var modelPath: String?
    private var isModelLoaded = false
    
    // Generation settings - use nonisolated(unsafe) for C struct that is only accessed from MainActor
    private var maxTokens: Int32 = 1024  // Reduced for iOS memory constraints
    private nonisolated(unsafe) var samplerConfig = llama_wrapper_default_sampler_config()
    
    enum ModelStatus: Equatable {
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
                return "Summarize the following patient encounter in one clear paragraph suitable for handoff to another provider:\n\nTranscript:"
            case .bullets:
                return "Extract the key points from the following patient encounter as concise bullet points:\n\nTranscript:"
            }
        }
        
        /// Format the output into sections
        func parseSections(from text: String) -> [String: String] {
            var sections: [String: String] = [:]
            
            switch self {
            case .soap:
                sections = parseSOAP(from: text)
            case .hp:
                sections = parseHP(from: text)
            case .summary:
                sections = ["Summary": text.trimmingCharacters(in: .whitespacesAndNewlines)]
            case .bullets:
                sections = ["Key Points": text.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            
            // If parsing failed, return the full text
            if sections.isEmpty {
                sections = ["Generated Note": text]
            }
            
            return sections
        }
        
        private func parseSOAP(from text: String) -> [String: String] {
            var sections: [String: String] = [:]
            let lines = text.components(separatedBy: .newlines)
            var currentSection: String?
            var currentContent: [String] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Check for section headers
                if trimmed.lowercased().hasPrefix("subjective:") ||
                   trimmed.lowercased().hasPrefix("**subjective:**") {
                    if let section = currentSection {
                        sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                    }
                    currentSection = "Subjective"
                    currentContent = [String(trimmed.dropFirst(trimmed.contains("**") ? 14 : 12))]
                } else if trimmed.lowercased().hasPrefix("objective:") ||
                          trimmed.lowercased().hasPrefix("**objective:**") {
                    if let section = currentSection {
                        sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                    }
                    currentSection = "Objective"
                    currentContent = [String(trimmed.dropFirst(trimmed.contains("**") ? 12 : 10))]
                } else if trimmed.lowercased().hasPrefix("assessment:") ||
                          trimmed.lowercased().hasPrefix("**assessment:**") {
                    if let section = currentSection {
                        sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                    }
                    currentSection = "Assessment"
                    currentContent = [String(trimmed.dropFirst(trimmed.contains("**") ? 13 : 11))]
                } else if trimmed.lowercased().hasPrefix("plan:") ||
                          trimmed.lowercased().hasPrefix("**plan:**") {
                    if let section = currentSection {
                        sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                    }
                    currentSection = "Plan"
                    currentContent = [String(trimmed.dropFirst(trimmed.contains("**") ? 8 : 5))]
                } else {
                    currentContent.append(line)
                }
            }
            
            // Don't forget the last section
            if let section = currentSection {
                sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            }
            
            return sections
        }
        
        private func parseHP(from text: String) -> [String: String] {
            var sections: [String: String] = [:]
            let lines = text.components(separatedBy: .newlines)
            var currentSection: String?
            var currentContent: [String] = []
            
            let sectionHeaders = [
                "chief complaint", "history of present illness", "hpi",
                "past medical history", "pmh", "medications", "meds",
                "allergies", "family history", "social history",
                "review of systems", "ros", "physical exam", "exam",
                "assessment", "plan"
            ]
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let lowerTrimmed = trimmed.lowercased()
                
                var foundHeader: String?
                for header in sectionHeaders {
                    if lowerTrimmed.hasPrefix(header + ":") ||
                       lowerTrimmed.hasPrefix("**" + header + ":**") {
                        foundHeader = header.capitalized
                        break
                    }
                }
                
                if let header = foundHeader {
                    if let section = currentSection {
                        sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                    }
                    currentSection = header
                    // Extract content after header
                    let headerEnd = trimmed.firstIndex(of: ":") ?? trimmed.startIndex
                    let contentStart = trimmed.index(headerEnd, offsetBy: 1)
                    let content = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespaces)
                    currentContent = content.isEmpty ? [] : [content]
                } else {
                    currentContent.append(line)
                }
            }
            
            if let section = currentSection {
                sections[section] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            }
            
            return sections
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize llama backend
        llama_wrapper_backend_init()
    }
    
    nonisolated func cleanup() {
        // This can be called from deinit
        // Since we can't access actor-isolated state from here,
        // we rely on the fact that the pointers will be cleaned up
        // by the OS when the process exits
    }
    
    // MARK: - Model Management
    
    /// Load the LLM model from disk
    /// - Parameter tier: Performance tier determining which model to load
    func loadModel(tier: PerformanceTier = .balanced) async {
        guard !isModelLoaded else {
            modelStatus = .ready
            return
        }
        
        modelStatus = .loading(progress: 0)
        
        // Find model file
        let modelName = tier.llmModel
        let possiblePaths = [
            Bundle.main.path(forResource: modelName, ofType: nil),
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent(modelName).path,
            "/Users/dannygomez/.openclaw/workspace/medical-dictation/scripts/build/models/" + modelName
        ].compactMap { $0 }
        
        guard let foundPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            modelStatus = .error("Model not found: \(modelName)")
            print("⚠️ Model not found: \(modelName)")
            print("Searched paths: \(possiblePaths)")
            return
        }
        
        modelPath = foundPath
        print("📦 Loading model from: \(foundPath)")
        
        // Update progress
        modelStatus = .loading(progress: 0.1)
        
        // Load model on background thread
        let result = await Task.detached(priority: .userInitiated) { [foundPath, tier] () -> ModelLoadResult in
            // Load model without progress callback (C callbacks can't capture Swift context)
            let model = llama_wrapper_load_model(
                foundPath,
                tier.gpuLayers,
                nil,  // No progress callback - C callbacks can't capture Swift context
                nil
            )
            
            guard let model = model else {
                return .failure("Failed to load model from \(foundPath)")
            }
            
            // Get vocab from model
            let vocab = llama_wrapper_get_vocab(model)
            guard let vocab = vocab else {
                llama_wrapper_free_model(model)
                return .failure("Failed to get vocabulary from model")
            }
            
            // Create context
            let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
            let context = llama_wrapper_new_context(
                model,
                tier.contextWindow,
                Int32(nThreads),
                Int32(nThreads)
            )
            
            guard let context = context else {
                llama_wrapper_free_model(model)
                return .failure("Failed to create context")
            }
            
            // Get model info
            var descBuf = [CChar](repeating: 0, count: 256)
            llama_wrapper_model_desc(model, &descBuf, 256)
            let desc = String(cString: descBuf)
            
            return .success(
                model: model,
                context: context,
                vocab: vocab,
                description: desc,
                contextSize: llama_wrapper_n_ctx(context),
                vocabSize: llama_wrapper_n_vocab(vocab)
            )
        }.value
        
        // Handle result on main actor
        switch result {
        case .success(let model, let context, let vocab, let desc, let ctxSize, let vocabSize):
            self.model = model
            self.context = context
            self.vocab = vocab
            self.isModelLoaded = true
            self.modelStatus = .ready
            self.configureSampler(tier: tier)
            
            print("✅ Model loaded: \(desc)")
            print("   Context: \(ctxSize) tokens")
            print("   Vocab: \(vocabSize) tokens")
            
        case .failure(let error):
            modelStatus = .error(error)
            print("❌ Model loading failed: \(error)")
        }
    }
    
    /// Unload the model and free resources
    func unloadModel() {
        if let ctx = context {
            llama_wrapper_free_context(ctx)
            context = nil
        }
        if let m = model {
            llama_wrapper_free_model(m)
            model = nil
        }
        vocab = nil
        isModelLoaded = false
        modelStatus = .notLoaded
        print("🗑️ Model unloaded")
    }
    
    /// Configure the sampler with performance tier settings
    private func configureSampler(tier: PerformanceTier) {
        samplerConfig = llama_wrapper_default_sampler_config()
        samplerConfig.temperature = tier.temperature
        samplerConfig.top_k = tier.topK
        samplerConfig.top_p = tier.topP
        samplerConfig.repeat_penalty = tier.repeatPenalty
        samplerConfig.repeat_last_n = tier.repeatLastN
    }
    
    // MARK: - Inference
    
    /// Process a transcript into a structured clinical note
    /// - Parameters:
    ///   - transcript: The raw transcribed text
    ///   - template: The note template to use (defaults to currentTemplate)
    /// - Returns: A StructuredNote containing the generated note
    func processTranscript(_ transcript: String, template: NoteTemplate? = nil) async -> StructuredNote? {
        let templateToUse = template ?? currentTemplate
        
        guard isModelLoaded, let ctx = context, vocab != nil else {
            print("⚠️ Model not loaded, cannot process transcript")
            return nil
        }
        
        isProcessing = true
        generationProgress = "Preparing prompt..."
        generatedText = ""
        defer { isProcessing = false }
        
        print("🧠 Processing with template: \(templateToUse.rawValue)")
        
        // Build prompt with template
        let prompt = buildPrompt(transcript: transcript, template: templateToUse)
        
        // Clear KV cache for fresh generation
        llama_wrapper_clear_kv_cache(ctx)
        
        generationProgress = "Generating..."
        
        // Generate text with streaming callback
        let output = await generateText(
            prompt: prompt,
            maxTokens: maxTokens,
            onToken: { [weak self] token in
                Task { @MainActor in
                    self?.generatedText.append(token)
                    self?.generationProgress = "Generated \(self?.generatedText.count ?? 0) chars..."
                }
            }
        )
        
        // Parse output into sections
        let sections = templateToUse.parseSections(from: output)
        let fullText = formatFullText(sections: sections, template: templateToUse)
        
        let note = StructuredNote(
            template: templateToUse,
            rawTranscript: transcript,
            generatedAt: Date(),
            sections: sections,
            fullText: fullText
        )
        
        self.structuredNote = note
        
        // CRITICAL: Unload model immediately after generation to free memory
        // This prevents iOS from killing the app due to memory pressure
        print("🧹 Auto-unloading model to free memory...")
        unloadModel()
        
        return note
    }
    
    /// Build the prompt for the LLM
    private func buildPrompt(transcript: String, template: NoteTemplate) -> String {
        let systemPrompt = template.systemPrompt
        
        return """
<|im_start|>system
\(systemPrompt)<|im_end|>
<|im_start|>user
\(transcript)<|im_end|>
<|im_start|>assistant
"""
    }
    
    /// Generate text from a prompt using the loaded model
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - maxTokens: Maximum tokens to generate
    ///   - onToken: Optional callback for each generated token
    /// - Returns: The generated text
    private func generateText(
        prompt: String,
        maxTokens: Int32,
        onToken: ((String) -> Void)? = nil
    ) async -> String {
        guard let ctx = context, let vocab = vocab else { return "" }
        
        // Capture sampler config locally to avoid MainActor isolation issues
        let localSamplerConfig = self.samplerConfig
        
        return await Task.detached(priority: .userInitiated) { [weak self] () -> String in
            guard let self = self else { return "" }
            
            var outputBuffer = [CChar](repeating: 0, count: 65536)
            
            // Generate using llama_wrapper_generate without callback
            // C callbacks cannot capture Swift context - use output buffer instead
            let generatedCount = llama_wrapper_generate(
                ctx,
                vocab,
                prompt,
                maxTokens,
                localSamplerConfig,
                nil,  // No token callback - C callbacks can't capture Swift context
                nil,
                &outputBuffer,
                65536
            )
            
            if generatedCount > 0 {
                let result = String(cString: outputBuffer)
                
                // Update progress on main actor
                Task { @MainActor in
                    self.generatedText = result
                    self.generationProgress = "Generated \(result.count) chars"
                }
                
                return result
            } else {
                return ""
            }
        }.value
    }
    
    /// Format sections into full text output
    private func formatFullText(sections: [String: String], template: NoteTemplate) -> String {
        var text = ""
        for (key, value) in sections.sorted(by: { $0.key < $1.key }) {
            text += "**\(key):**\n\(value)\n\n"
        }
        return text
    }
}

// MARK: - Model Load Result

/// Internal enum for model loading results
private enum ModelLoadResult {
    case success(model: OpaquePointer, context: OpaquePointer, vocab: OpaquePointer, description: String, contextSize: UInt32, vocabSize: Int32)
    case failure(String)
}

// MARK: - Performance Tier

extension LLMProcessor {
    enum PerformanceTier: String, CaseIterable {
        case powerSaver = "Power Saver"
        case balanced = "Balanced"
        case deepseekQ40 = "DeepSeek 7B Q4_0"
        
        var llmModel: String {
            switch self {
            case .powerSaver: return "llama-3.2-3b-q4_k_m.gguf"
            case .balanced: return "qwen2.5-7b-q4_k_m.gguf"
            case .deepseekQ40: return "deepseek-r1-distill-qwen-7b-q4_0.gguf"
            }
        }
        
        var supportsSpanish: Bool {
            switch self {
            case .powerSaver: return false
            case .balanced: return true
            case .deepseekQ40: return true
            }
        }
        
        var gpuLayers: Int32 {
            switch self {
            case .powerSaver: return 20
            case .balanced: return 15
            case .deepseekQ40: return 20
            }
        }
        
        var contextWindow: UInt32 {
            switch self {
            case .powerSaver: return 2048
            case .balanced: return 2048
            case .deepseekQ40: return 2048
            }
        }
        
        var temperature: Float {
            switch self {
            case .powerSaver: return 0.5  // More deterministic
            case .balanced: return 0.7
            case .deepseekQ40: return 0.7
            }
        }
        
        var topK: Int32 {
            return 40
        }
        
        var topP: Float {
            return 0.9
        }
        
        var repeatPenalty: Float {
            return 1.1
        }
        
        var repeatLastN: Int32 {
            return 64
        }
    }
}

// MARK: - Streaming Generation Support

extension LLMProcessor {
    /// Process transcript with streaming output
    /// - Parameters:
    ///   - transcript: The raw transcribed text
    ///   - template: The note template to use
    ///   - onToken: Callback called for each generated token
    /// - Returns: A StructuredNote containing the generated note
    func processTranscriptStreaming(
        _ transcript: String,
        template: NoteTemplate? = nil,
        onToken: @escaping (String) -> Void
    ) async -> StructuredNote? {
        let templateToUse = template ?? currentTemplate
        
        guard isModelLoaded, let ctx = context, vocab != nil else {
            print("⚠️ Model not loaded, cannot process transcript")
            return nil
        }
        
        isProcessing = true
        generationProgress = "Preparing prompt..."
        generatedText = ""
        defer { isProcessing = false }
        
        // Build prompt
        let prompt = buildPrompt(transcript: transcript, template: templateToUse)
        
        // Clear KV cache
        llama_wrapper_clear_kv_cache(ctx)
        
        generationProgress = "Generating..."
        
        // Generate with streaming
        await generateTextStreaming(
            prompt: prompt,
            maxTokens: maxTokens,
            onToken: onToken
        )
        
        // Parse output
        let sections = templateToUse.parseSections(from: generatedText)
        let fullText = formatFullText(sections: sections, template: templateToUse)
        
        let note = StructuredNote(
            template: templateToUse,
            rawTranscript: transcript,
            generatedAt: Date(),
            sections: sections,
            fullText: fullText
        )
        
        self.structuredNote = note
        return note
    }
    
    /// Generate text with streaming output
    private func generateTextStreaming(
        prompt: String,
        maxTokens: Int32,
        onToken: @escaping (String) -> Void
    ) async {
        guard let ctx = context, let vocab = vocab else { return }
        
        // Capture sampler config locally
        let localSamplerConfig = self.samplerConfig
        
        await Task.detached(priority: .userInitiated) {
            var outputBuffer = [CChar](repeating: 0, count: 65536)
            
            // Generate without callback - C callbacks cannot capture Swift context
            // For true streaming, we'd need a different architecture with a global callback registry
            llama_wrapper_generate(
                ctx,
                vocab,
                prompt,
                maxTokens,
                localSamplerConfig,
                nil,  // No callback - C callbacks can't capture Swift context
                nil,
                &outputBuffer,
                65536
            )
            
            // After generation, call onToken with the full output
            let result = String(cString: outputBuffer)
            if !result.isEmpty {
                onToken(result)
            }
        }.value
    }
}

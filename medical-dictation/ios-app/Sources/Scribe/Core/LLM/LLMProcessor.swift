import Foundation

/// Processes transcripts through local LLM for structured output
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
    
    enum PerformanceTier {
        case powerSaver    // Small + 3B
        case balanced      // Medium + 7B
        case maximum       // Turbo + 14B
        
        var llmModel: String {
            switch self {
            case .powerSaver: return "qwen2.5-3b-q4_k_m.gguf"
            case .balanced: return "deepseek-r1-distill-qwen-7b-q4_k_m.gguf"
            case .maximum: return "deepseek-r1-distill-qwen-14b-q3_k_m.gguf"
            }
        }
        
        var gpuLayers: Int32 {
            switch self {
            case .powerSaver: return 99
            case .balanced: return 99
            case .maximum: return 40  // Don't offload all 14B layers
            }
        }
        
        var contextWindow: UInt32 {
            switch self {
            case .powerSaver: return 4096
            case .balanced: return 4096
            case .maximum: return 2048  // Reduce for 14B
            }
        }
        
        var batchSize: UInt32 {
            switch self {
            case .powerSaver: return 512
            case .balanced: return 512
            case .maximum: return 256  // Reduce for 14B
            }
        }
        
        var description: String {
            switch self {
            case .powerSaver: return "Power Saver (3B)"
            case .balanced: return "Balanced (7B)"
            case .maximum: return "Maximum (14B)"
            }
        }
    }
    
    enum NoteTemplate: String, CaseIterable {
        case soap = "SOAP Note"
        case hp = "H&P"
        case summary = "Brief Summary"
        case bullets = "Bullet Points"
        
        var systemPrompt: String {
            switch self {
            case .soap:
                return """You are a medical scribe. Convert the following patient encounter transcript into a structured SOAP note.
Format:
**Subjective:** Patient's complaints, history, symptoms
**Objective:** Vital signs, physical exam findings, test results
**Assessment:** Diagnosis/differential diagnosis
**Plan:** Treatment plan, medications, follow-up

Be concise but complete. Use medical terminology appropriately.

Transcript:"""
                
            case .hp:
                return """You are a medical scribe. Convert the following patient encounter transcript into a complete History and Physical (H&P) note.
Include: Chief Complaint, History of Present Illness, Past Medical History, Medications, Allergies, Family History, Social History, Review of Systems, Physical Exam, Assessment, and Plan.

Transcript:"""
                
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
        params.use_mmap = true
        params.use_mlock = tier == .maximum ? false : true  // Don't lock 14B models
        
        guard let model = llama_load_model_from_file(modelPath, params) else {
            modelStatus = .error("Failed to load model")
            return
        }
        
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = tier.contextWindow
        ctxParams.n_batch = tier.batchSize
        ctxParams.n_threads = 6 // Use all performance cores
        ctxParams.n_threads_batch = 6
        ctxParams.flash_attn = true  // Enable Flash Attention for memory efficiency
        
        llamaContext = llama_new_context_with_model(model, ctxParams)
        
        if llamaContext != nil {
            modelStatus = .ready
            // Warm up with a simple inference
            _ = await generate("Hi", maxTokens: 1)
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
        // Check multiple locations
        let possiblePaths = [
            // 1. App bundle
            Bundle.main.path(forResource: named, ofType: nil),
            // 2. Documents directory
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent(named).path,
            // 3. Build directory (development)
            FileManager.default.currentDirectoryPath + "/scripts/build/models/" + named,
            // 4. Absolute path from workspace
            "/Users/dannygomez/.openclaw/workspace/medical-dictation/scripts/build/models/" + named
        ].compactMap { $0 }
        
        return possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
    }
    
    // MARK: - Inference
    
    func processTranscript(_ transcript: String, template: NoteTemplate? = nil) async -> StructuredNote? {
        guard let ctx = llamaContext else { return nil }
        
        let templateToUse = template ?? currentTemplate
        let prompt = templateToUse.systemPrompt + "\n\n" + transcript + "\n\nStructured Note:"
        
        isProcessing = true
        defer { isProcessing = false }
        
        return await processingQueue.async {
            let output = self.generate(prompt, maxTokens: 1024)
            
            // Parse the output based on template
            let sections = self.parseOutput(output, template: templateToUse)
            
            return StructuredNote(
                template: templateToUse,
                rawTranscript: transcript,
                generatedAt: Date(),
                sections: sections,
                fullText: output
            )
        }.result
    }
    
    private func generate(_ prompt: String, maxTokens: Int32) -> String {
        guard let ctx = llamaContext else { return "" }
        
        // Tokenize prompt
        let tokens = tokenize(prompt, addBOS: true)
        
        // Evaluate prompt
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }
        
        for (i, token) in tokens.enumerated() {
            batch.token[i] = token
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = 0
        }
        batch.logits[Int(tokens.count) - 1] = 1 // Compute logits for last token
        batch.n_tokens = Int32(tokens.count)
        
        if llama_decode(ctx, batch) != 0 {
            return ""
        }
        
        // Generate
        var generatedTokens: [llama_token] = []
        var nCur = batch.n_tokens
        
        for _ in 0..<maxTokens {
            let token = sampleToken(ctx: ctx)
            if token == llama_token_eos(ctx) {
                break
            }
            
            generatedTokens.append(token)
            
            // Prepare next batch
            llama_batch_clear(&batch)
            batch.token[0] = token
            batch.pos[0] = nCur
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1
            batch.n_tokens = 1
            
            if llama_decode(ctx, batch) != 0 {
                break
            }
            
            nCur += 1
        }
        
        // Detokenize
        return detokenize(generatedTokens)
    }
    
    private func tokenize(_ text: String, addBOS: Bool) -> [llama_token] {
        guard let ctx = llamaContext else { return [] }
        let model = llama_get_model(ctx)
        
        let maxTokens = Int(text.utf8.count) + (addBOS ? 1 : 0)
        var tokens: [llama_token] = Array(repeating: 0, count: maxTokens)
        
        let actualTokens = llama_tokenize(
            model,
            text,
            Int32(text.utf8.count),
            &tokens,
            Int32(maxTokens),
            addBOS,
            false
        )
        
        return Array(tokens.prefix(Int(actualTokens)))
    }
    
    private func sampleToken(ctx: OpaquePointer) -> llama_token {
        let vocab = llama_n_vocab(llama_get_model(ctx))
        var logits = llama_get_logits(ctx)!
        
        // Simple greedy sampling (can add temperature/top_p for variety)
        var maxLogit: Float = -Float.infinity
        var maxToken: llama_token = 0
        
        for i in 0..<vocab {
            if logits[Int(i)] > maxLogit {
                maxLogit = logits[Int(i)]
                maxToken = i
            }
        }
        
        return maxToken
    }
    
    private func detokenize(_ tokens: [llama_token]) -> String {
        guard let ctx = llamaContext else { return "" }
        let model = llama_get_model(ctx)
        
        var result = ""
        for token in tokens {
            var buffer: [CChar] = Array(repeating: 0, count: 32)
            let length = llama_token_to_piece(model, token, &buffer, 32, 0, false)
            if length > 0 {
                result += String(bytes: buffer.prefix(Int(length)).map { UInt8($0) }, encoding: .utf8) ?? ""
            }
        }
        return result
    }
    
    private func parseOutput(_ output: String, template: NoteTemplate) -> [String: String] {
        var sections: [String: String] = [:]
        
        switch template {
        case .soap:
            sections["Subjective"] = extractSection(output, keyword: "Subjective")
            sections["Objective"] = extractSection(output, keyword: "Objective")
            sections["Assessment"] = extractSection(output, keyword: "Assessment")
            sections["Plan"] = extractSection(output, keyword: "Plan")
        case .hp:
            // Parse H&P sections
            let hpSections = ["Chief Complaint", "History of Present Illness", "Past Medical History",
                            "Medications", "Allergies", "Family History", "Social History",
                            "Review of Systems", "Physical Exam", "Assessment", "Plan"]
            for section in hpSections {
                sections[section] = extractSection(output, keyword: section)
            }
        default:
            sections["Content"] = output
        }
        
        return sections
    }
    
    private func extractSection(_ text: String, keyword: String) -> String {
        let pattern = "(?i)\\*?\\*?\\s*\(keyword)\\s*:?\\*?\\*?\\s*\\n?(.*?)(?=\\n\\s*\\*?\\*?[A-Z]|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return ""
        }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            let contentRange = match.range(at: 2)
            if let swiftRange = Range(contentRange, in: text) {
                return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }
}

// C function stubs (actual implementation needs llama.cpp headers)
typealias llama_token = Int32
typealias llama_model = OpaquePointer
typealias llama_context = OpaquePointer
struct llama_model_params {}
struct llama_context_params {}
struct llama_batch {
    var n_tokens: Int32 = 0
    var token: UnsafeMutablePointer<llama_token>?
    var pos: UnsafeMutablePointer<Int32>?
    var n_seq_id: UnsafeMutablePointer<Int32>?
    var seq_id: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>?
    var logits: UnsafeMutablePointer<Int8>?
    var all_pos_0: Int32 = 0
    var all_pos_1: Int32 = 0
    var all_seq_id: Int32 = 0
}

func llama_model_default_params() -> llama_model_params { fatalError() }
func llama_context_default_params() -> llama_context_params { fatalError() }
func llama_load_model_from_file(_ path: String, _ params: llama_model_params) -> OpaquePointer? { fatalError() }
func llama_new_context_with_model(_ model: OpaquePointer, _ params: llama_context_params) -> OpaquePointer? { fatalError() }
func llama_free(_ ctx: OpaquePointer) {}
func llama_n_vocab(_ model: OpaquePointer) -> Int32 { fatalError() }
func llama_get_model(_ ctx: OpaquePointer) -> OpaquePointer { fatalError() }
func llama_get_logits(_ ctx: OpaquePointer) -> UnsafeMutablePointer<Float>? { fatalError() }
func llama_token_eos(_ ctx: OpaquePointer) -> llama_token { fatalError() }
func llama_tokenize(_ model: OpaquePointer, _ text: String, _ text_len: Int32, _ tokens: UnsafeMutablePointer<llama_token>, _ n_max_tokens: Int32, _ add_special: Bool, _ parse_special: Bool) -> Int32 { fatalError() }
func llama_token_to_piece(_ model: OpaquePointer, _ token: llama_token, _ buf: UnsafeMutablePointer<CChar>, _ length: Int32, _ lstrip: Int32, _ special: Bool) -> Int32 { fatalError() }
func llama_decode(_ ctx: OpaquePointer, _ batch: llama_batch) -> Int32 { fatalError() }
func llama_batch_init(_ n_tokens: Int32, _ embd: Int32, _ n_seq_max: Int32) -> llama_batch { fatalError() }
func llama_batch_free(_ batch: llama_batch) {}
func llama_batch_clear(_ batch: inout llama_batch) {}

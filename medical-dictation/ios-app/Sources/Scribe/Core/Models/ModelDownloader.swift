import Foundation

/// Handles downloading ML models on first launch to reduce app bundle size
actor ModelDownloader: ObservableObject {
    static let shared = ModelDownloader()
    
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var currentModel: String = ""
    @Published var downloadError: String?
    
    private let fileManager = FileManager.default
    
    /// Base URL for model downloads (HuggingFace mirrors)
    private let modelBaseURLs = [
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/",
        "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/"
    ]
    
    /// Get the documents directory for storing models
    var modelsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDir = paths[0]
        let modelsDir = docsDir.appendingPathComponent("models", isDirectory: true)
        
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        return modelsDir
    }
    
    /// Check if a model exists locally
    func modelExists(_ modelName: String) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(modelName)
        return fileManager.fileExists(atPath: modelPath.path)
    }
    
    /// Check if all required models are downloaded
    func allModelsDownloaded() -> Bool {
        let requiredModels = [
            "ggml-small.bin",      // PowerSaver STT
            "ggml-medium.bin",     // Balanced STT  
            "ggml-large-v3.bin",  // Maximum STT
            "llama-3.2-3b-q4_k_m.gguf",     // PowerSaver LLM
            "qwen2.5-7b-q4_k_m.gguf",       // Balanced LLM
            "deepseek-r1-distill-qwen-7b-q4_k_m.gguf"  // Maximum LLM
        ]
        
        return requiredModels.allSatisfy { modelExists($0) }
    }
    
    /// Download a single model
    func downloadModel(
        _ modelName: String,
        from urlString: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let destinationURL = modelsDirectory.appendingPathComponent(modelName)
        
        // Skip if already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            print("✅ Model already exists: \(modelName)")
            return
        }
        
        guard let url = URL(string: urlString + modelName) else {
            throw ModelDownloadError.invalidURL
        }
        
        print("📥 Downloading \(modelName)...")
        
        let (tempURL, response) = try await URLSession.shared.downloadTask(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.downloadFailed
        }
        
        // Move to final location
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        print("✅ Downloaded \(modelName)")
    }
    
    /// Download all required models
    func downloadAllModels(progressHandler: ((String, Double) -> Void)? = nil) async {
        guard !allModelsDownloaded() else {
            print("✅ All models already downloaded")
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadError = nil
        
        let models: [(name: String, url: String)] = [
            // STT Models (Whisper)
            ("ggml-small.bin", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"),
            ("ggml-medium.bin", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"),
            ("ggml-large-v3.bin", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"),
            // LLM Models
            ("llama-3.2-3b-q4_k_m.gguf", "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/"),
            ("qwen2.5-7b-q4_k_m.gguf", "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/"),
            ("deepseek-r1-distill-qwen-7b-q4_k_m.gguf", "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/")
        ]
        
        for (index, model) in models.enumerated() {
            currentModel = model.name
            
            do {
                try await downloadModel(model.name, from: model.url) { progress in
                    let totalProgress = (Double(index) + progress) / Double(models.count)
                    Task { @MainActor in
                        self.downloadProgress = totalProgress
                    }
                    progressHandler?(model.name, totalProgress)
                }
            } catch {
                downloadError = "Failed to download \(model.name): \(error.localizedDescription)"
                print("❌ Download error: \(error)")
            }
        }
        
        isDownloading = false
        currentModel = ""
        
        if allModelsDownloaded() {
            print("✅ All models downloaded successfully!")
        }
    }
    
    /// Get the full path to a model
    func modelPath(_ modelName: String) -> URL {
        // First check documents directory
        let docsPath = modelsDirectory.appendingPathComponent(modelName)
        if fileManager.fileExists(atPath: docsPath.path) {
            return docsPath
        }
        
        // Fall back to bundle
        return URL(fileURLWithPath: Bundle.main.bundlePath)
            .appendingPathComponent("scripts/build/models/\(modelName)")
    }
}

enum ModelDownloadError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case fileMoveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid download URL"
        case .downloadFailed: return "Download failed"
        case .fileMoveFailed: return "Failed to save model file"
        }
    }
}

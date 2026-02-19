import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var transcriptionEngine: TranscriptionEngine
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    @State private var showingModelDownloadSheet = false
    @State private var selectedTier: PerformanceTier = .balanced
    
    // Privacy settings
    @State private var biometricEnabled = true
    @State private var autoLockEnabled = true
    @State private var biometricType: BiometricAuthManager.BiometricType = .none
    
    // Auto-process settings
    @State private var autoProcessEnabled = false
    @State private var includeTimestamps = true
    
    enum PerformanceTier {
        case powerSaver
        case balanced
        case maximum
        
        var sttTier: TranscriptionEngine.PerformanceTier {
            switch self {
            case .powerSaver: return .medium
            case .balanced: return .medium
            case .maximum: return .medium
            }
        }
        
        var llmModel: String {
            switch self {
            case .powerSaver: return "Llama 3.2 3B"
            case .balanced: return "Qwen2.5 7B"
            case .maximum: return "DeepSeek-R1 7B Q4_K_M"
            }
        }
        
        var llmSize: String {
            switch self {
            case .powerSaver: return "~2.0 GB + 1.5 GB STT"
            case .balanced: return "~4.4 GB + 1.5 GB STT"
            case .maximum: return "~3.8 GB + 1.5 GB STT"
            }
        }
        
        var description: String {
            switch self {
            case .powerSaver:
                return "Llama 3.2 3B + Whisper Medium. Fastest, English only."
            case .balanced:
                return "Qwen2.5 7B + Whisper Medium. Multilingual (Spanish/English)."
            case .maximum:
                return "DeepSeek 7B Q3_K_L + Whisper Medium. Smallest DeepSeek with Medium STT."
            }
        }
    }
    
    var tierDescription: String {
        selectedTier.description
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Performance Tier") {
                    Picker("Mode", selection: $selectedTier) {
                        Text("Power Saver").tag(PerformanceTier.powerSaver)
                        Text("Balanced").tag(PerformanceTier.balanced)
                        Text("Maximum").tag(PerformanceTier.maximum)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTier) { newTier in
                        Task {
                            // Reload both models with new tier
                            transcriptionEngine.unloadModel()
                            llmProcessor.unloadModel()
                            await transcriptionEngine.loadModel(tier: newTier.sttTier)
                            // Convert tier for LLM
                            let llmTier: LLMProcessor.PerformanceTier = {
                                switch newTier {
                                case .powerSaver: return .powerSaver
                                case .balanced: return .balanced
                                case .maximum: return .maximum
                                }
                            }()
                            await llmProcessor.loadModel(tier: llmTier)
                        }
                    }
                    
                    Text(tierDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Models") {
                    // STT Model
                    let sttStatus: ModelStatusRow.ModelStatus = {
                        switch transcriptionEngine.modelStatus {
                        case .ready: return .ready
                        case .loading: return .loading
                        case .error(let msg): return .error(msg)
                        case .notLoaded: return .notLoaded
                        }
                    }()
                    ModelStatusRow(
                        name: selectedTier.sttTier.modelName,
                        status: sttStatus,
                        size: selectedTier.sttTier.size,
                        action: {
                            Task {
                                await transcriptionEngine.loadModel(tier: selectedTier.sttTier)
                            }
                        }
                    )
                    
                    // LLM Model
                    let llmStatus: ModelStatusRow.ModelStatus = {
                        switch llmProcessor.modelStatus {
                        case .ready: return .ready
                        case .loading: return .loading
                        case .error(let msg): return .error(msg)
                        case .notLoaded: return .notLoaded
                        }
                    }()
                    ModelStatusRow(
                        name: selectedTier.llmModel,
                        status: llmStatus,
                        size: selectedTier.llmSize,
                        action: {
                            showingModelDownloadSheet = true
                        }
                    )
                }
                
                Section("Note Templates") {
                    // NavigationLink("Guided H&P") {
                    //     GuidedHPView()
                    // }
                    
                    Picker("Default Template", selection: $llmProcessor.currentTemplate) {
                        ForEach(LLMProcessor.NoteTemplate.allCases, id: \.self) { template in
                            Text(template.rawValue).tag(template)
                        }
                    }
                    
                    Toggle("Auto-process on stop", isOn: $autoProcessEnabled)
                    Toggle("Include timestamps", isOn: $includeTimestamps)
                }
                
                Section("Privacy") {
                    if biometricType != .none {
                        Toggle(biometricType == .faceID ? "Require Face ID" : "Require Touch ID", isOn: $biometricEnabled)
                    }
                    Toggle("Auto-lock after 5 minutes", isOn: $autoLockEnabled)
                    
                    NavigationLink("Data Management") {
                        DataManagementView()
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0 (Alpha)")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Documentation", destination: URL(string: "https://github.com/dannygomez/scribe")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingModelDownloadSheet) {
                ModelDownloadSheet()
            }
            .onAppear {
                Task {
                    let type = await BiometricAuthManager.shared.biometricType()
                    await MainActor.run {
                        biometricType = type
                    }
                }
            }
        }
    }
}

struct ModelStatusRow: View {
    let name: String
    let status: ModelStatus
    let size: String
    let action: () -> Void
    
    enum ModelStatus {
        case notLoaded
        case loading
        case ready
        case error(String)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: status)
            
            if case .notLoaded = status {
                Button("Load", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ModelStatusRow.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }
    
    var color: Color {
        switch status {
        case .ready: return .green
        case .loading: return .yellow
        case .error: return .red
        case .notLoaded: return .gray
        }
    }
    
    var text: String {
        switch status {
        case .ready: return "Ready"
        case .loading: return "Loading"
        case .error: return "Error"
        case .notLoaded: return "Not Loaded"
        }
    }
}

struct ModelDownloadSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    @State private var downloadProgress: Double = 0
    @State private var isDownloading = false
    @State private var currentModelName: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Download AI Models")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("First-time setup: Download the AI models needed for transcription and note generation. Total: ~9 GB. Models are stored locally—nothing leaves your device.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isDownloading {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                        
                        Text("\(currentModelName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        isDownloading = true
                        errorMessage = nil
                        Task {
                            await downloadAllModels()
                        }
                    } label: {
                        Text(isDownloading ? "Downloading..." : "Download All Models")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloading)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func downloadAllModels() async {
        await ModelDownloader.shared.downloadAllModels { modelName, progress in
            Task { @MainActor in
                self.currentModelName = modelName
                self.downloadProgress = progress
            }
        }
        
        await MainActor.run {
            isDownloading = false
            dismiss()
        }
    }
}

struct DataManagementView: View {
    var body: some View {
        List {
            Section {
                Button("Export All Notes") {
                    // Export as JSON/CSV
                }
                
                Button("Delete All Notes") {
                    // Confirmation + delete
                }
                .foregroundColor(.red)
            }
            
            Section("Storage") {
                HStack {
                    Text("Notes")
                    Spacer()
                    Text("12 MB")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Models")
                    Spacer()
                    Text("~5 GB")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Data Management")
    }
}

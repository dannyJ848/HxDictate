import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var transcriptionEngine: TranscriptionEngine
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    @State private var showingModelDownloadSheet = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Models") {
                    // STT Model
                    ModelStatusRow(
                        name: "Whisper STT",
                        status: transcriptionEngine.modelStatus,
                        size: "~466 MB",
                        action: {
                            Task {
                                await transcriptionEngine.loadModel()
                            }
                        }
                    )
                    
                    // LLM Model
                    ModelStatusRow(
                        name: "DeepSeek 7B",
                        status: llmProcessor.modelStatus,
                        size: "~4.5 GB",
                        action: {
                            showingModelDownloadSheet = true
                        }
                    )
                }
                
                Section("Output Preferences") {
                    Picker("Default Template", selection: .constant(LLMProcessor.NoteTemplate.soap)) {
                        ForEach(LLMProcessor.NoteTemplate.allCases, id: \.self) { template in
                            Text(template.rawValue).tag(template)
                        }
                    }
                    
                    Toggle("Auto-process on stop", isOn: .constant(false))
                    Toggle("Include timestamps", isOn: .constant(true))
                }
                
                Section("Privacy") {
                    Toggle("Require Face ID/Touch ID", isOn: .constant(true))
                    Toggle("Auto-lock after 5 minutes", isOn: .constant(true))
                    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Download DeepSeek 7B")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This model is ~4.5 GB and will be stored on your device. All processing happens locally—no data leaves your phone.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isDownloading {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                        
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        isDownloading = true
                        // Trigger download + load
                        Task {
                            await downloadAndLoadModel()
                        }
                    } label: {
                        Text(isDownloading ? "Downloading..." : "Download & Load")
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
    
    private func downloadAndLoadModel() async {
        // Simulate download progress
        for i in 0...100 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            await MainActor.run {
                downloadProgress = Double(i) / 100.0
            }
        }
        
        // Actually load the model
        await llmProcessor.loadModel()
        
        await MainActor.run {
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

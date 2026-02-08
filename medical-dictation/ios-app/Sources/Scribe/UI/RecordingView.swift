import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioSessionManager
    @EnvironmentObject var transcriptionEngine: TranscriptionEngine
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.circle.fill")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

// MARK: - Recording View

struct RecordingView: View {
    @EnvironmentObject var audioManager: AudioSessionManager
    @EnvironmentObject var transcriptionEngine: TranscriptionEngine
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    @State private var showingProcessSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status card
                StatusCard()
                
                // Audio visualizer
                AudioVisualizer(level: audioManager.audioLevel)
                    .frame(height: 60)
                
                // Live transcript
                ScrollView {
                    Text(transcriptionEngine.currentTranscript.isEmpty ? 
                         "Transcript will appear here..." :
                         transcriptionEngine.currentTranscript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    // Clear button
                    Button {
                        transcriptionEngine.clearTranscript()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                    }
                    .disabled(transcriptionEngine.currentTranscript.isEmpty)
                    
                    // Record/Stop button
                    RecordButton(
                        isRecording: audioManager.isRecording,
                        action: toggleRecording
                    )
                    
                    // Process button
                    Button {
                        showingProcessSheet = true
                    } label: {
                        Image(systemName: "sparkles.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    .disabled(transcriptionEngine.currentTranscript.isEmpty || {
                        if case .ready = llmProcessor.modelStatus {
                            return false
                        }
                        return true
                    }())
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Scribe")
            .sheet(isPresented: $showingProcessSheet) {
                ProcessSheet(transcript: transcriptionEngine.currentTranscript)
            }
        }
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            // Process any remaining audio in the buffer
            Task {
                await transcriptionEngine.processFinalBuffer()
                // CRITICAL: Unload Whisper immediately after transcription to free memory
                // This prevents iOS from killing the app when loading the LLM
                print("🧹 Unloading Whisper to free memory for LLM...")
                transcriptionEngine.unloadModel()
            }
        } else {
            do {
                try audioManager.startRecording()
                // Wire audio to transcription
                audioManager.onAudioBuffer = { buffer, time in
                    transcriptionEngine.processAudioBuffer(buffer, time: time)
                }
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.red)
                    .frame(width: 80, height: 80)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
    }
}

struct AudioVisualizer: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<20) { index in
                    let threshold = Float(index) / 20.0
                    let isActive = level > threshold
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: (geometry.size.width - 76) / 20)
                        .animation(.easeInOut(duration: 0.05), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct StatusCard: View {
    @EnvironmentObject var transcriptionEngine: TranscriptionEngine
    @EnvironmentObject var llmProcessor: LLMProcessor
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(sttColor)
                        .frame(width: 8, height: 8)
                    Text("STT: \(sttText)")
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(llmColor)
                        .frame(width: 8, height: 8)
                    Text("LLM: \(llmText)")
                        .font(.caption)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    var sttColor: Color {
        switch transcriptionEngine.modelStatus {
        case .ready: return .green
        case .loading: return .yellow
        case .error: return .red
        case .notLoaded: return .gray
        }
    }
    
    var sttText: String {
        switch transcriptionEngine.modelStatus {
        case .ready: return "Ready"
        case .loading: return "Loading..."
        case .error(let msg): return "Error: \(msg)"
        case .notLoaded: return "Not Loaded"
        }
    }
    
    var llmColor: Color {
        switch llmProcessor.modelStatus {
        case .ready: return .green
        case .loading: return .yellow
        case .error: return .red
        case .notLoaded: return .gray
        }
    }
    
    var llmText: String {
        switch llmProcessor.modelStatus {
        case .ready: return "Ready"
        case .loading(let progress): return "Loading \(Int(progress * 100))%"
        case .error(let msg): return "Error: \(msg)"
        case .notLoaded: return "Not Loaded"
        }
    }
}

// MARK: - Process Sheet

struct ProcessSheet: View {
    let transcript: String
    @EnvironmentObject var llmProcessor: LLMProcessor
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTemplate: LLMProcessor.NoteTemplate = .soap
    @State private var generatedNote: StructuredNote?
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(LLMProcessor.NoteTemplate.allCases, id: \.self) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if llmProcessor.isProcessing {
                    Spacer()
                    ProgressView("Processing with DeepSeek...")
                        .scaleEffect(1.2)
                    Spacer()
                } else if let note = generatedNote {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(note.sections.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(key)
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                    Text(value)
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button("Save to History") {
                            // Save via SwiftData
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Copy") {
                            UIPasteboard.general.string = note.fullText
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    Spacer()
                    Button("Generate Note") {
                        Task {
                            generatedNote = await llmProcessor.processTranscript(
                                transcript,
                                template: selectedTemplate
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled({
                        if case .ready = llmProcessor.modelStatus {
                            return false
                        }
                        return true
                    }())
                    Spacer()
                }
            }
            .navigationTitle("Process Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

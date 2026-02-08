import SwiftUI
import AVFoundation

/// Guided H&P view with voice navigation
struct GuidedHPView: View {
    @State private var template = HPTemplate()
    @StateObject private var audioManager = AudioSessionManager()
    @StateObject private var transcriptionEngine = TranscriptionEngine()
    
    @State private var showingPrompt = true
    @State private var currentPromptIndex = 0
    @State private var transcriptBuffer = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                HPProgressBar(currentSection: template.currentSection)
                    .padding()
                
                // Current section header
                SectionHeader(section: template.currentSection)
                    .padding(.horizontal)
                
                // Prompt card
                if showingPrompt, let prompts = HPTemplate.sectionPrompts[template.currentSection], !prompts.isEmpty {
                    PromptCard(
                        prompt: prompts[currentPromptIndex % prompts.count],
                        promptNumber: currentPromptIndex + 1,
                        totalPrompts: prompts.count
                    )
                    .padding()
                    .transition(.move(edge: .top))
                }
                
                // Live transcript
                ScrollView {
                    Text(transcriptionEngine.currentTranscript.isEmpty ? 
                         "Listening..." : transcriptionEngine.currentTranscript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Section content preview
                if let sectionContent = template.transcriptBySection[template.currentSection.rawValue], !sectionContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Section Notes:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sectionContent)
                            .font(.caption)
                            .lineLimit(3)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Voice command hints
                VoiceCommandHints()
                    .padding(.horizontal)
                
                // Controls
                HStack(spacing: 20) {
                    Button {
                        template.previousSection()
                        currentPromptIndex = 0
                    } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(template.currentSection.previous == nil)
                    
                    RecordButton(isRecording: audioManager.isRecording) {
                        toggleRecording()
                    }
                    
                    Button {
                        template.nextSection()
                        currentPromptIndex = 0
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(template.currentSection.next == nil)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Guided H&P")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(HPTemplate.HPSection.allCases, id: \.self) { section in
                            Button(section.rawValue) {
                                template.jumpTo(section: section)
                                currentPromptIndex = 0
                            }
                        }
                        
                        Divider()
                        
                        Button("Complete H&P") {
                            completeHP()
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            
            // Save transcript to current section
            if !transcriptionEngine.currentTranscript.isEmpty {
                let current = template.transcriptBySection[template.currentSection.rawValue] ?? ""
                template.transcriptBySection[template.currentSection.rawValue] = 
                    current + "\n" + transcriptionEngine.currentTranscript
            }
            
            // Check for section transitions
            if let newSection = template.detectSectionTransition(in: transcriptionEngine.currentTranscript) {
                template.jumpTo(section: newSection)
                currentPromptIndex = 0
            }
            
            // Check for voice commands
            if let command = HPVoiceCommand.detect(in: transcriptionEngine.currentTranscript) {
                handleVoiceCommand(command)
            }
            
            transcriptionEngine.clearTranscript()
            
        } else {
            do {
                try audioManager.startRecording()
                audioManager.onAudioBuffer = { buffer, time in
                    transcriptionEngine.processAudioBuffer(buffer, time: time)
                }
            } catch {
                print("Recording error: \(error)")
            }
        }
    }
    
    private func handleVoiceCommand(_ command: HPVoiceCommand) {
        switch command {
        case .next:
            template.nextSection()
            currentPromptIndex = 0
        case .previous:
            template.previousSection()
            currentPromptIndex = 0
        case .repeatPrompt:
            // Just replay TTS of current prompt
            break
        case .skip:
            currentPromptIndex += 1
        case .complete:
            completeHP()
        case .pause, .resume:
            toggleRecording()
        case .goTo:
            // Would need more sophisticated parsing
            break
        }
    }
    
    private func completeHP() {
        let note = template.generateHPNote()
        // Save to history, export, etc.
        print("H&P Complete:\n\(note)")
    }
}

// MARK: - Supporting Views

struct HPProgressBar: View {
    let currentSection: HPTemplate.HPSection
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: progressWidth(in: geometry), height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
    
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        let allSections = HPTemplate.HPSection.allCases
        guard let index = allSections.firstIndex(of: currentSection) else { return 0 }
        return geometry.size.width * CGFloat(index + 1) / CGFloat(allSections.count)
    }
}

struct SectionHeader: View {
    let section: HPTemplate.HPSection
    
    var body: some View {
        HStack {
            Text(section.rawValue)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("\(sectionNumber)/\(totalSections)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var sectionNumber: Int {
        HPTemplate.HPSection.allCases.firstIndex(of: section).map { $0 + 1 } ?? 0
    }
    
    private var totalSections: Int {
        HPTemplate.HPSection.allCases.count
    }
}

struct PromptCard: View {
    let prompt: String
    let promptNumber: Int
    let totalPrompts: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Question \(promptNumber) of \(totalPrompts)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    // Text-to-speech of prompt
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Text(prompt)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct VoiceCommandHints: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Voice Commands:")
                .font(.caption)
                .fontWeight(.bold)
            
            Text("\"Next section\" • \"Previous\" • \"Go to [section name]\" • \"Complete H and P\"")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct GuidedHPView_Previews: PreviewProvider {
    static var previews: some View {
        GuidedHPView()
    }
}

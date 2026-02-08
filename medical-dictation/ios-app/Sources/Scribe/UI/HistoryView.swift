import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \StructuredNote.encounterDate, order: .reverse) var notes: [StructuredNote]
    @State private var selectedNote: StructuredNote?
    @State private var searchText = ""
    
    var filteredNotes: [StructuredNote] {
        if searchText.isEmpty {
            return notes
        }
        return notes.filter { note in
            note.rawTranscript.localizedCaseInsensitiveContains(searchText) ||
            note.fullText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note)
                        .onTapGesture {
                            selectedNote = note
                        }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transcripts...")
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
            }
            .overlay {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "doc.text",
                        description: Text("Record and process your first patient encounter")
                    )
                }
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        // SwiftData handles deletion
    }
}

struct NoteRow: View {
    let note: StructuredNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.template.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(note.encounterDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(note.sections.first?.value.prefix(100) ?? "No content")
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            Text("\(Int(note.rawTranscript.count / 6)) words · \(formatDuration(note.duration))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var duration: TimeInterval {
        // Estimate based on word count (~150 wpm)
        Double(note.rawTranscript.count) / 7.5
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins)m \(secs)s"
    }
}

struct NoteDetailView: View {
    let note: StructuredNote
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.template.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(note.encounterDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Structured sections
                    ForEach(note.sections.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(key)
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            Text(value)
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Raw transcript (collapsible)
                    DisclosureGroup("Raw Transcript") {
                        Text(note.rawTranscript)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = note.fullText
                        } label: {
                            Label("Copy Note", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            UIPasteboard.general.string = note.rawTranscript
                        } label: {
                            Label("Copy Transcript", systemImage: "doc.text")
                        }
                        
                        ShareLink(item: note.fullText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

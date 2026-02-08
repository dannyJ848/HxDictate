import Foundation
import SwiftData

/// Represents a structured clinical note
@Model
final class StructuredNote {
    var id: UUID
    var templateRaw: String
    var rawTranscript: String
    var generatedAt: Date
    var sectionsData: Data // JSON-encoded sections
    var fullText: String
    var patientIdentifier: String? // De-identified or coded
    var encounterDate: Date
    
    init(
        template: LLMProcessor.NoteTemplate,
        rawTranscript: String,
        generatedAt: Date,
        sections: [String: String],
        fullText: String,
        patientIdentifier: String? = nil,
        encounterDate: Date = Date()
    ) {
        self.id = UUID()
        self.templateRaw = template.rawValue
        self.rawTranscript = rawTranscript
        self.generatedAt = generatedAt
        self.sectionsData = (try? JSONEncoder().encode(sections)) ?? Data()
        self.fullText = fullText
        self.patientIdentifier = patientIdentifier
        self.encounterDate = encounterDate
    }
    
    var template: LLMProcessor.NoteTemplate {
        LLMProcessor.NoteTemplate(rawValue: templateRaw) ?? .soap
    }
    
    var sections: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: sectionsData)) ?? [:]
    }
    
    var formattedOutput: String {
        var output = ""
        for (key, value) in sections.sorted(by: { $0.key < $1.key }) {
            output += "**\(key):**\n\(value)\n\n"
        }
        return output
    }
}

/// Active transcription session (not persisted until finalized)
struct TranscriptionSession {
    let id = UUID()
    var transcript: String = ""
    var startTime: Date = Date()
    var endTime: Date?
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var isComplete: Bool {
        endTime != nil
    }
}

/// Custom prompt templates for specific rotations
@Model
final class CustomTemplate {
    var id: UUID
    var name: String
    var systemPrompt: String
    var isBuiltIn: Bool
    var createdAt: Date
    
    init(name: String, systemPrompt: String, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }
    
    static let builtInTemplates: [CustomTemplate] = [
        CustomTemplate(
            name: "ED Fast Track",
            systemPrompt: """
You are an emergency medicine scribe. Create a focused note from this transcript.
Include: Chief Complaint, HPI (brief), relevant PMH/meds, focused exam, assessment, and disposition plan.
Be concise—ED notes should be scannable in 30 seconds.
""",
            isBuiltIn: true
        ),
        CustomTemplate(
            name: "Psychiatry",
            systemPrompt: """
You are a psychiatry scribe. Create a psychiatric progress note.
Include: Chief Complaint, HPI with mental status exam, psychiatric history, current meds, risk assessment, assessment, and plan.
Pay special attention to SI/HI, psychotic symptoms, mood, and cognition.
""",
            isBuiltIn: true
        ),
        CustomTemplate(
            name: "Surgery Pre-Op",
            systemPrompt: """
You are a surgical scribe. Create a pre-operative H&P.
Include: Indication for surgery, relevant history, anesthesia concerns, informed consent discussion, and surgical plan.
""",
            isBuiltIn: true
        )
    ]
}

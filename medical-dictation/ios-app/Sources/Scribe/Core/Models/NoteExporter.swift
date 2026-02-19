import Foundation
import SwiftUI

/// Handles exporting notes in various formats
actor NoteExporter {
    static let shared = NoteExporter()
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case text = "Plain Text"
        case pdf = "PDF"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .text: return "txt"
            case .pdf: return "pdf"
            }
        }
        
        var mimeType: String {
            switch self {
            case .json: return "application/json"
            case .csv: return "text/csv"
            case .text: return "text/plain"
            case .pdf: return "application/pdf"
            }
        }
    }
    
    /// Export a single note
    func exportNote(_ note: StructuredNote, format: ExportFormat) -> URL? {
        let filename = "\(note.template.rawValue.replacingOccurrences(of: " ", with: "_"))_\(note.generatedAt.timeIntervalSince1970).\(format.fileExtension)"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        var content: String
        
        switch format {
        case .json:
            content = exportAsJSON(note)
        case .csv:
            content = exportAsCSV([note])
        case .text:
            content = exportAsText(note)
        case .pdf:
            // PDF requires more complex handling - return nil for now
            return nil
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export note: \(error)")
            return nil
        }
    }
    
    /// Export all notes
    func exportAllNotes(_ notes: [StructuredNote], format: ExportFormat) -> URL? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "HxDictate_Export_\(timestamp).\(format.fileExtension)"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        var content: String
        
        switch format {
        case .json:
            let exportData = notes.map { noteToDictionary($0) }
            if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                content = jsonString
            } else {
                return nil
            }
        case .csv:
            content = exportAsCSV(notes)
        case .text:
            content = notes.map { exportAsText($0) }.joined(separator: "\n\n---\n\n")
        case .pdf:
            return nil
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export notes: \(error)")
            return nil
        }
    }
    
    private func exportAsJSON(_ note: StructuredNote) -> String {
        let data = noteToDictionary(note)
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private func noteToDictionary(_ note: StructuredNote) -> [String: Any] {
        var dict: [String: Any] = [
            "id": note.id.uuidString,
            "title": note.template.rawValue,
            "date": ISO8601DateFormatter().string(from: note.generatedAt),
            "template": note.templateRaw,
            "encounterDate": ISO8601DateFormatter().string(from: note.encounterDate)
        ]
        
        if !note.rawTranscript.isEmpty {
            dict["transcript"] = note.rawTranscript
        }
        
        if !note.sections.isEmpty {
            dict["sections"] = note.sections
        }
        
        if !note.fullText.isEmpty {
            dict["fullText"] = note.fullText
        }
        
        if let patientId = note.patientIdentifier {
            dict["patientIdentifier"] = patientId
        }
        
        return dict
    }
    
    private func exportAsCSV(_ notes: [StructuredNote]) -> String {
        var csv = "ID,Title,Date,Template,Transcript,Content\n"
        
        for note in notes {
            let id = escapeCSV(note.id.uuidString)
            let title = escapeCSV(note.title)
            let date = escapeCSV(ISO8601DateFormatter().string(from: note.date))
            let template = escapeCSV(note.template.rawValue)
            let transcript = escapeCSV(note.transcript ?? "")
            let content = escapeCSV(note.rawText ?? "")
            
            csv += "\(id),\(title),\(date),\(template),\(transcript),\(content)\n"
        }
        
        return csv
    }
    
    private func exportAsText(_ note: StructuredNote) -> String {
        var text = """
        \(note.template.rawValue)
        Date: \(formatDate(note.generatedAt))
        Encounter Date: \(formatDate(note.encounterDate))
        Template: \(note.templateRaw)
        
        """
        
        if !note.rawTranscript.isEmpty {
            text += """
            TRANSCRIPT:
            \(note.rawTranscript)
            
            """
        }
        
        if !note.sections.isEmpty {
            for (key, value) in note.sections.sorted(by: { $0.key < $1.key }) {
                text += "\(key.uppercased()):\n\(value)\n\n"
            }
        } else if !note.fullText.isEmpty {
            text += note.fullText
        }
        
        return text
    }
    
    private func escapeCSV(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

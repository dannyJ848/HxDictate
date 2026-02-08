import Foundation
import SwiftData

/// Comprehensive H&P Template with voice-guided workflow
/// Guides through complete history and physical exam with voice cues
@Model
final class HPTemplate {
    var id: UUID
    var name: String
    var currentSection: HPSection
    var isActive: Bool
    var createdAt: Date
    
    // Track which questions have been answered
    var completedQuestions: [String: Bool]
    var transcriptBySection: [String: String]
    
    init() {
        self.id = UUID()
        self.name = "Complete H&P"
        self.currentSection = .identifyingData
        self.isActive = false
        self.createdAt = Date()
        self.completedQuestions = [:]
        self.transcriptBySection = [:]
    }
    
    /// All H&P sections in order
    enum HPSection: String, CaseIterable {
        case identifyingData = "Identifying Data"
        case chiefComplaint = "Chief Complaint"
        case historyOfPresentIllness = "History of Present Illness"
        case pastMedicalHistory = "Past Medical History"
        case medications = "Medications"
        case allergies = "Allergies"
        case familyHistory = "Family History"
        case socialHistory = "Social History"
        case reviewOfSystems = "Review of Systems"
        case physicalExam = "Physical Exam"
        case assessment = "Assessment"
        case plan = "Plan"
        
        var next: HPSection? {
            let all = HPSection.allCases
            if let idx = all.firstIndex(of: self), idx < all.count - 1 {
                return all[idx + 1]
            }
            return nil
        }
        
        var previous: HPSection? {
            let all = HPSection.allCases
            if let idx = all.firstIndex(of: self), idx > 0 {
                return all[idx - 1]
            }
            return nil
        }
    }
    
    /// Voice cues that trigger section transitions
    static let sectionCues: [HPSection: [String]] = [
        .identifyingData: ["start", "begin", "patient name", "identifying data"],
        .chiefComplaint: ["chief complaint", "cc", "what brings you in", "why are you here"],
        .historyOfPresentIllness: ["history of present illness", "hpi", "tell me more", "when did this start"],
        .pastMedicalHistory: ["past medical history", "pmh", "medical history", "any medical problems"],
        .medications: ["medications", "meds", "what medications", "current medications"],
        .allergies: ["allergies", "allergic", "any allergies"],
        .familyHistory: ["family history", "fh", "family medical history", "parents health"],
        .socialHistory: ["social history", "sh", "do you smoke", "do you drink", "occupation"],
        .reviewOfSystems: ["review of systems", "ros", "any other symptoms", "system review"],
        .physicalExam: ["physical exam", "exam", "let me examine", "vital signs"],
        .assessment: ["assessment", "impression", "diagnosis"],
        .plan: ["plan", "treatment", "next steps", "follow up"]
    ]
    
    /// Detect if transcript contains a section cue
    func detectSectionTransition(in transcript: String) -> HPSection? {
        let lowerTranscript = transcript.lowercased()
        
        for (section, cues) in HPTemplate.sectionCues {
            if cues.contains(where: { lowerTranscript.contains($0) }) {
                return section
            }
        }
        return nil
    }
    
    /// Get prompting questions for current section
    var currentPrompts: [String] {
        HPTemplate.sectionPrompts[currentSection] ?? []
    }
    
    /// Section-specific prompting questions
    static let sectionPrompts: [HPSection: [String]] = [
        .identifyingData: [
            "Please state the patient's name, age, and gender.",
            "Who is the historian?",
            "What is the source of information?"
        ],
        .chiefComplaint: [
            "What brings you in today?",
            "In the patient's own words, what is the main problem?",
            "How long has this been going on?"
        ],
        .historyOfPresentIllness: [
            "Location: Where is the problem?",
            "Quality: What does it feel like?",
            "Severity: On a scale of 1-10?",
            "Timing: When did it start? Constant or intermittent?",
            "Modifying factors: What makes it better or worse?",
            "Associated symptoms: Any other symptoms?",
            "Context: What were you doing when this started?"
        ],
        .pastMedicalHistory: [
            "Any chronic medical conditions?",
            "Any previous surgeries?",
            "Any hospitalizations?",
            "Any significant childhood illnesses?"
        ],
        .medications: [
            "What medications are you currently taking?",
            "Include prescription, over-the-counter, and supplements.",
            "What are the doses and how often do you take them?"
        ],
        .allergies: [
            "Any medication allergies? What reaction did you have?",
            "Any food allergies?",
            "Any environmental allergies?"
        ],
        .familyHistory: [
            "Mother's health status and age? Any medical conditions?",
            "Father's health status and age? Any medical conditions?",
            "Any siblings? Their health status?",
            "Any family history of heart disease, diabetes, cancer, or genetic conditions?"
        ],
        .socialHistory: [
            "Occupation?",
            "Marital status? Who do you live with?",
            "Tobacco use? Past or present? How much?",
            "Alcohol use? How much per week?",
            "Any drug use?",
            "Exercise habits?",
            "Diet?",
            "Sleep habits?"
        ],
        .reviewOfSystems: [
            "General: Any fever, chills, fatigue, weight changes?",
            "HEENT: Headache, vision changes, hearing changes, sore throat?",
            "Cardiovascular: Chest pain, palpitations, shortness of breath?",
            "Respiratory: Cough, wheezing, shortness of breath?",
            "GI: Nausea, vomiting, diarrhea, constipation, abdominal pain?",
            "GU: Urinary frequency, urgency, pain?",
            "Musculoskeletal: Joint pain, muscle pain, stiffness?",
            "Neurological: Headache, dizziness, weakness, numbness?",
            "Psychiatric: Depression, anxiety, sleep disturbances?",
            "Endocrine: Heat or cold intolerance, excessive thirst?",
            "Hematologic: Easy bruising, bleeding?",
            "Allergic/Immunologic: Frequent infections?"
        ],
        .physicalExam: [
            "Vital signs: Temperature, blood pressure, heart rate, respiratory rate, oxygen saturation",
            "General appearance: Alert, oriented, in distress?",
            "HEENT: Head, eyes, ears, nose, throat exam",
            "Neck: JVD, lymph nodes, thyroid",
            "Cardiovascular: Heart sounds, murmurs, peripheral pulses",
            "Respiratory: Breath sounds, wheezes, crackles",
            "Abdomen: Bowel sounds, tenderness, masses, organomegaly",
            "Extremities: Edema, cyanosis, clubbing",
            "Neurological: Cranial nerves, motor, sensory, reflexes",
            "Skin: Rashes, lesions, wounds"
        ],
        .assessment: [
            "Primary diagnosis or differential diagnosis?",
            "Problem list?"
        ],
        .plan: [
            "Diagnostic tests ordered?",
            "Medications prescribed?",
            "Procedures planned?",
            "Patient education provided?",
            "Follow-up plan?",
            "Return precautions?"
        ]
    ]
    
    /// Generate formatted H&P note from collected data
    func generateHPNote() -> String {
        var note = ""
        
        for section in HPSection.allCases {
            if let content = transcriptBySection[section.rawValue], !content.isEmpty {
                note += "**\(section.rawValue):**\n\(content)\n\n"
            }
        }
        
        return note
    }
    
    /// Move to next section
    func nextSection() {
        if let next = currentSection.next {
            currentSection = next
        }
    }
    
    /// Move to previous section
    func previousSection() {
        if let prev = currentSection.previous {
            currentSection = prev
        }
    }
    
    /// Jump to specific section
    func jumpTo(section: HPSection) {
        currentSection = section
    }
}

/// Voice commands for H&P navigation
enum HPVoiceCommand: String, CaseIterable {
    case next = "next section"
    case previous = "previous section"
    case repeatPrompt = "repeat question"
    case skip = "skip this"
    case goTo = "go to"
    case complete = "complete h and p"
    case pause = "pause"
    case resume = "resume"
    
    static func detect(in transcript: String) -> HPVoiceCommand? {
        let lower = transcript.lowercased()
        return HPVoiceCommand.allCases.first { lower.contains($0.rawValue) }
    }
}

// TipTemplate.swift
// WhipTip Models

import Foundation

// [ENTITY: TipTemplate]
// [USES: TipRules, Participant, DisplayConfig, TemplateVersion]
// [FEATURE: Template Lifecycle]
struct TipTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    // LIFECYCLE-UI: Added last edited date
    var lastEditedDate: Date?
    var rules: TipRules
    var participants: [Participant]
    var displayConfig: DisplayConfig
    var schemaVersion: TemplateVersion = TemplateVersion(version: TemplateVersion.currentVersion, createdWith: TemplateVersion.currentAppVersion)
    
    // LIFECYCLE-UI: Updated initializer to include lastEditedDate
    init(id: UUID = UUID(), name: String, createdDate: Date = Date(), 
         lastEditedDate: Date? = nil,
         rules: TipRules, participants: [Participant], 
         displayConfig: DisplayConfig = DisplayConfig(),
         schemaVersion: TemplateVersion? = nil) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lastEditedDate = lastEditedDate
        self.rules = rules
        self.participants = participants
        self.displayConfig = displayConfig
        if let version = schemaVersion {
            self.schemaVersion = version
        }
    }
}

struct SplitResult { 
    var splits: [Participant]
    var warnings: [String] 
}

struct OnboardingResponse: Codable {
    var status: ResponseStatus
    var message: String
    var clarificationNeeded: Bool
    var template: TipTemplate?
    var suggestedQuestions: [String]?
    
    enum ResponseStatus: String, Codable { 
        case inProgress = "in_progress"
        case needsClarification = "needs_clarification"
        case complete = "complete"
        case error = "error"
    }
}

struct CalculationResponse: Codable { 
    var splits: [Participant]
    var summary: String
    var warnings: [String]?
    var visualizationHints: [String: String]? 
}

struct MockProduct: Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}
// HistoryService.swift
// WhipTip Service Layer

import Foundation
import Combine

// [SECTION: services]
// [SUBSECTION: history]

// [ENTITY: HistoryService]
// Service for handling calculation history
class HistoryService {
    @Published private(set) var history: [TipCalculationHistory] = []
    private let persistenceKey = "calculationHistory"
    private let maxHistoryItems = 100
    
    // [FEATURE: initialization]
    init() {
        loadHistory()
    }
    
    // [FEATURE: load_history]
    // Loads history from persistent storage
    private func loadHistory() {
        // Implementation would load from UserDefaults or other storage
        // This is a placeholder for the full implementation
        history = []
    }
    
    // [FEATURE: add_calculation]
    // Adds a new calculation to history
    func addCalculation(template: TipTemplate, 
                       tipAmount: Double, 
                       result: TipSplitResult) -> Bool {
        
        let newEntry = TipCalculationHistory(
            id: UUID(),
            templateId: template.id,
            templateName: template.name,
            tipAmount: tipAmount,
            participants: template.participants.count,
            splitType: template.rules.type,
            calculationTime: result.calculationTime,
            splits: result.splits
        )
        
        // Add to history and ensure we don't exceed the max size
        history.insert(newEntry, at: 0)
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        // Save to persistent storage
        saveHistory()
        return true
    }
    
    // [FEATURE: clear_history]
    // Clears all history entries
    func clearHistory() {
        history = []
        saveHistory()
    }
    
    // [FEATURE: delete_entry]
    // Deletes a specific history entry
    func deleteEntry(withId id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }
    
    // [FEATURE: get_entries]
    // Gets entries filtered by template ID
    func getEntries(forTemplateId templateId: UUID? = nil) -> [TipCalculationHistory] {
        if let templateId = templateId {
            return history.filter { $0.templateId == templateId }
        } else {
            return history
        }
    }
    
    // [HELPER: save_to_storage]
    // Helper method to save history to persistent storage
    private func saveHistory() {
        // Implementation would save to UserDefaults or other storage
        // This is a placeholder for the full implementation
    }
    
    // [FEATURE: export_history]
    // Exports history data in CSV format
    func exportHistoryCSV() -> String {
        var csv = "Date,Template,Amount,Participants,Type\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for entry in history {
            let dateString = dateFormatter.string(from: entry.calculationTime)
            csv += "\(dateString),\"\(entry.templateName)\",\(entry.tipAmount),\(entry.participants),\(entry.splitType)\n"
        }
        
        return csv
    }
    
    // [FEATURE: get_statistics]
    // Gets usage statistics from history data
    func getStatistics() -> HistoryStatistics {
        guard !history.isEmpty else {
            return HistoryStatistics(
                totalCalculations: 0,
                averageTipAmount: 0,
                mostUsedTemplate: nil,
                mostUsedSplitType: nil
            )
        }
        
        // Calculate total calculations
        let totalCalculations = history.count
        
        // Calculate average tip amount
        let totalAmount = history.reduce(0.0) { $0 + $1.tipAmount }
        let averageTipAmount = totalAmount / Double(totalCalculations)
        
        // Find most used template
        var templateCounts: [UUID: Int] = [:]
        for entry in history {
            templateCounts[entry.templateId, default: 0] += 1
        }
        let mostUsedTemplateId = templateCounts.max(by: { $0.value < $1.value })?.key
        let mostUsedTemplate = history.first { $0.templateId == mostUsedTemplateId }?.templateName
        
        // Find most used split type
        var typeCounts: [TipRuleType: Int] = [:]
        for entry in history {
            typeCounts[entry.splitType, default: 0] += 1
        }
        let mostUsedSplitType = typeCounts.max(by: { $0.value < $1.value })?.key
        
        return HistoryStatistics(
            totalCalculations: totalCalculations,
            averageTipAmount: averageTipAmount,
            mostUsedTemplate: mostUsedTemplate,
            mostUsedSplitType: mostUsedSplitType
        )
    }
}

// [ENTITY: HistoryStatistics]
// Statistics derived from history data
struct HistoryStatistics {
    let totalCalculations: Int
    let averageTipAmount: Double
    let mostUsedTemplate: String?
    let mostUsedSplitType: TipRuleType?
}
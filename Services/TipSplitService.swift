// TipSplitService.swift
// WhipTip Service Layer

import Foundation

// [SECTION: services]
// [SUBSECTION: splitting]

// [ENTITY: TipSplitService]
// Service for handling tip splitting and calculation results
struct TipSplitService {
    
    // [FEATURE: calculate_splits]
    // Calculates tip splits based on template and total tip amount
    static func calculateSplits(template: TipTemplate, tipAmount: Double) -> TipSplitResult {
        // Validate the template
        let validationResult = ValidationService.validateTemplate(template)
        if case .failure(let error) = validationResult {
            return TipSplitResult(
                splits: [],
                warnings: [error.localizedDescription],
                calculationTime: Date()
            )
        }
        
        // Compute the splits
        return computeSplits(template: template, pool: tipAmount)
    }
    
    // [FEATURE: save_calculation]
    // Saves calculation history
    static func saveCalculation(template: TipTemplate, result: TipSplitResult, tipAmount: Double) -> Bool {
        // Implementation would involve persistence layer
        // This is a placeholder for the full implementation
        print("Calculation saved: \(template.name), \(tipAmount), \(result.splits.count) splits")
        return true
    }
    
    // [FEATURE: get_history]
    // Retrieves calculation history
    static func getCalculationHistory() -> [TipCalculationHistory] {
        // Implementation would involve persistence layer
        // This is a placeholder for the full implementation
        return []
    }
    
    // [HELPER: format_currency]
    // Formats a number as currency
    static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
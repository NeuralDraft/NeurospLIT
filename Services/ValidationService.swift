// ValidationService.swift
// WhipTip Service Layer

import Foundation

// [SECTION: services]
// [SUBSECTION: validation]

// [ENTITY: ValidationService]
// Central service for validation functions across the app
struct ValidationService {
    
    // [FEATURE: template_validation]
    // Validates that a tip template contains all required information
    static func validateTemplate(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        // Validate template name
        if template.name.isEmpty {
            return .failure(.validation("Template name cannot be empty"))
        }
        
        // Validate participants
        let participantResult = validateParticipants(template.participants)
        if case .failure(let error) = participantResult {
            return .failure(error)
        }
        
        // Validate rules based on type
        switch template.rules.type {
        case .percentage:
            return validatePercentageWeights(template)
            
        case .roleWeighted:
            return validateRoleWeights(template)
            
        case .hoursBased:
            // Hours can be missing but we'll handle that in the calculation
            return .success(template)
            
        default:
            // Equal split and other types don't need special validation
            return .success(template)
        }
    }
    
    // [VALIDATION: participant_validation]
    private static func validateParticipants(_ participants: [Participant]) -> Result<[Participant], WhipCoreError> {
        // Check that we have at least one participant
        if participants.isEmpty {
            return .failure(.validation("At least one participant is required"))
        }
        
        // Check that all participants have names
        for participant in participants {
            if participant.name.isEmpty {
                return .failure(.validation("All participants must have a name"))
            }
            
            if participant.role.isEmpty {
                return .failure(.validation("All participants must have a role"))
            }
        }
        
        return .success(participants)
    }
    
    // [VALIDATION: percentage_weights]
    private static func validatePercentageWeights(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        var totalWeight: Double = 0
        
        // Calculate total weight
        for participant in template.participants {
            totalWeight += participant.weight ?? 0
        }
        
        // Check if total weight is valid
        if totalWeight <= 0 {
            return .failure(.validation("Total percentage weight must be greater than zero"))
        }
        
        // Check if total weight equals 100%
        if abs(totalWeight - 100.0) > 0.01 {
            return .failure(.validation("Total percentage weight must equal 100%"))
        }
        
        return .success(template)
    }
    
    // [VALIDATION: role_weights]
    private static func validateRoleWeights(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        let roleWeights = template.rules.roleWeights
        
        if roleWeights.isEmpty {
            return .failure(.validation("Role weights must be defined for role-weighted splits"))
        }
        
        // Make sure every role in participants has a weight
        for participant in template.participants {
            if roleWeights[participant.role] == nil {
                return .failure(.validation("No weight defined for role: \(participant.role)"))
            }
        }
        
        // Make sure at least one weight is non-zero
        let nonZeroWeight = roleWeights.values.contains { $0 > 0 }
        if !nonZeroWeight {
            return .failure(.validation("At least one role weight must be greater than zero"))
        }
        
        return .success(template)
    }
    
    // [VALIDATION: off_the_top_percentages]
    static func validateOffTheTopPercentages(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        guard let offTheTop = template.rules.offTheTop, !offTheTop.isEmpty else {
            return .success(template)
        }
        
        let totalPercentage = offTheTop.reduce(0.0) { $0 + $1.percentage }
        
        if totalPercentage > 100.0 {
            return .failure(.validation("Off-the-top percentages exceed 100%"))
        }
        
        return .success(template)
    }
    
    // [FEATURE: hours_validation]
    // Validates hours for hours-based calculation
    static func validateHours(_ participants: [Participant]) -> Bool {
        let totalHours = participants.reduce(0.0) { $0 + ($1.hours ?? 0) }
        return totalHours > 0
    }
}
// TipRules.swift
// WhipTip Models

import Foundation

// [SUBSECTION: Tip Rules]
// [ENTITY: TipRules]
// [USES: Foundation]
// [VALIDATION: Unknown rule types default to .equal; decoder maps legacy snake_case variants.]
struct TipRules: Codable {
    enum RuleType: String, Codable, CaseIterable {
        case hoursBased = "hours"
        case percentage = "percentage"
        case equal = "equal"
        case roleWeighted = "roleWeighted"
        case hybrid = "hybrid"
        case custom = "custom" // LIFECYCLE: Added for custom rule support

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "hours_based": self = .hoursBased
            case "equal_split": self = .equal
            case "role_weighted", "role-weighted": self = .roleWeighted
            case "hybrid_percentages": self = .hybrid
            default:
                if let value = RuleType(rawValue: raw) {
                    self = value
                } else {
                    self = .equal
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
    }
    var type: RuleType
    var formula: String = ""
    var offTheTop: [OffTheTopRule]?
    var roleWeights: [String: Double]?
    var customLogic: String?
    var values: [String: Double] = [:]  // LIFECYCLE: Added for consistent rule values
    
    // LIFECYCLE: Added constructor for TipRules
    init(type: RuleType, formula: String = "", values: [String: Double] = [:], 
         offTheTop: [OffTheTopRule]? = nil, roleWeights: [String: Double]? = nil, customLogic: String? = nil) {
        self.type = type
        self.formula = formula
        self.values = values
        self.offTheTop = offTheTop
        self.roleWeights = roleWeights
        self.customLogic = customLogic
    }
}

// [ENTITY: OffTheTopRule]
// [USES: Foundation]
// [LEGACY: OffTheTop alias preserved for compatibility]
struct OffTheTopRule: Codable { 
    var role: String
    var percentage: Double 
}

// [LEGACY: Typealias maintained for backward compatibility; prefer OffTheTopRule]
typealias OffTheTop = OffTheTopRule // legacy compatibility
typealias TipRuleType = TipRules.RuleType // LIFECYCLE: Added for consistent naming
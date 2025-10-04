import Foundation


public struct TipTemplate: Codable, Identifiable {
    public var id = UUID()
    public var name: String
    public var createdDate: Date
    public var rules: TipRules
    public var participants: [Participant]
    public var displayConfig: DisplayConfig
    public init(id: UUID = UUID(), name: String, createdDate: Date, rules: TipRules, participants: [Participant], displayConfig: DisplayConfig) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.rules = rules
        self.participants = participants
        self.displayConfig = displayConfig
    }
}

public struct TipRules: Codable {
    public enum RuleType: String, Codable, CaseIterable { case hoursBased = "hours", percentage = "percentage", equal = "equal", roleWeighted = "role_weighted", hybrid = "hybrid" }
    public var type: RuleType
    public var formula: String
    public var offTheTop: [OffTheTopRule]?
    public var roleWeights: [String: Double]?
    public var customLogic: String?
    public init(type: RuleType, formula: String = "", offTheTop: [OffTheTopRule]? = nil, roleWeights: [String: Double]? = nil, customLogic: String? = nil) {
        self.type = type
        self.formula = formula
        self.offTheTop = offTheTop
        self.roleWeights = roleWeights
        self.customLogic = customLogic
    }
}

public struct OffTheTopRule: Codable { public var role: String; public var percentage: Double; public init(role: String, percentage: Double) { self.role = role; self.percentage = percentage } }

public struct Participant: Codable, Identifiable {
    public var id = UUID()
    public var name: String
    public var role: String
    public var hours: Double?
    public var weight: Double?
    public var calculatedAmount: Double?
    public var actualAmount: Double?
    public init(id: UUID = UUID(), name: String, role: String, hours: Double? = nil, weight: Double? = nil, calculatedAmount: Double? = nil, actualAmount: Double? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.hours = hours
        self.weight = weight
        self.calculatedAmount = calculatedAmount
        self.actualAmount = actualAmount
    }
}

public struct DisplayConfig: Codable { public var primaryVisualization: String; public var accentColor: String; public var showPercentages: Bool; public var showComparison: Bool; public init(primaryVisualization: String, accentColor: String, showPercentages: Bool, showComparison: Bool) { self.primaryVisualization = primaryVisualization; self.accentColor = accentColor; self.showPercentages = showPercentages; self.showComparison = showComparison } }

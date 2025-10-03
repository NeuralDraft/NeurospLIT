// NeurospLIT.swift
// Complete App Store-Ready Implementation
// Copyright © 2025 NeurospLIT. All rights reserved.

import SwiftUI
import Combine
import Network
import UIKit
import StoreKit

// MARK: - App Entry Point

@main
struct NeurospLITApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var apiService = APIService()
    @StateObject private var whipCoinsManager = WhipCoinsManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.templateManager, templateManager)
                .environment(\.subscriptionManager, subscriptionManager)
                .environment(\.apiService, apiService)
                .environmentObject(whipCoinsManager)
                .preferredColorScheme(.dark)
                .task {
                    await subscriptionManager.updateSubscriptionStatus()
                }
        }
    }
}

// MARK: - Core Models

/// Represents the rules for splitting tips
struct TipRules: Codable, Equatable {
    enum RuleType: String, Codable, CaseIterable {
        case hoursBased = "hours"
        case percentage = "percentage"
        case equal = "equal"
        case roleWeighted = "roleWeighted"
        case hybrid = "hybrid"
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            
            // Handle legacy formats
            let mappings: [String: RuleType] = [
                "hours_based": .hoursBased,
                "equal_split": .equal,
                "role_weighted": .roleWeighted,
                "role-weighted": .roleWeighted,
                "hybrid_percentages": .hybrid
            ]
            
            if let mapped = mappings[raw] {
                self = mapped
            } else if let value = RuleType(rawValue: raw) {
                self = value
            } else {
                self = .equal // Default fallback
            }
        }
    }
    
    var type: RuleType
    var formula: String
    var offTheTop: [OffTheTopRule]?
    var roleWeights: [String: Double]?
    var customLogic: String?
}

/// Rule for off-the-top deductions
struct OffTheTopRule: Codable, Equatable {
    var role: String
    var percentage: Double
}

/// Represents a participant in the tip split
struct Participant: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var role: String
    var hours: Double?
    var weight: Double?
    var calculatedAmount: Double?
    var actualAmount: Double?
    
    var emoji: String {
        switch role.lowercased() {
        case "server", "waiter": return "🍽️"
        case "busser": return "🧹"
        case "host", "hostess": return "🎯"
        case "bartender": return "🍹"
        case "cook", "kitchen", "chef": return "👨‍🍳"
        case "manager": return "💼"
        case "runner": return "🏃"
        default: return "💰"
        }
    }
    
    var color: Color {
        switch role.lowercased() {
        case "server", "waiter": return .purple
        case "busser": return .blue
        case "host", "hostess": return .mint
        case "bartender": return .orange
        case "cook", "kitchen", "chef": return .pink
        case "manager": return .indigo
        case "runner": return .green
        default: return .gray
        }
    }
}

/// Display configuration for visualizations
struct DisplayConfig: Codable, Equatable {
    var primaryVisualization: String
    var accentColor: String
    var showPercentages: Bool
    var showComparison: Bool
}

/// Template for tip splitting rules
struct TipTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var createdDate: Date
    var rules: TipRules
    var participants: [Participant]
    var displayConfig: DisplayConfig
}

/// Result of a tip split calculation
struct SplitResult {
    var splits: [Participant]
    var warnings: [String]
}

// MARK: - Core Engine

/// Errors that can occur during tip calculation
enum TipCalculationError: Error, LocalizedError {
    case negativePool
    case noParticipants
    case negativeHours(participantName: String)
    case negativeWeight(participantName: String)
    case invalidOffTheTopPercentage(role: String, percentage: Double)
    case invalidRoleWeight(role: String, weight: Double)
    
    var errorDescription: String? {
        switch self {
        case .negativePool:
            return "The tip pool amount cannot be negative."
        case .noParticipants:
            return "At least one participant is required for splitting."
        case .negativeHours(let name):
            return "\(name) has negative hours. Please enter a valid positive number."
        case .negativeWeight(let name):
            return "\(name) has a negative weight. Please enter a valid positive number."
        case .invalidOffTheTopPercentage(let role, let pct):
            return "Invalid off-the-top percentage (\(pct)%) for \(role)."
        case .invalidRoleWeight(let role, let weight):
            return "Invalid weight (\(weight)) for role \(role)."
        }
    }
}

/// Main engine for computing tip splits
class TipSplitEngine {
    private static let weightNormalizationEpsilon = 0.001
    
    static func computeSplits(template: TipTemplate, pool: Double) -> SplitResult {
        do {
            let (splits, warnings) = try computeSplitsInternal(template: template, pool: pool)
            return SplitResult(splits: splits, warnings: warnings)
        } catch {
            return SplitResult(splits: template.participants, warnings: [error.localizedDescription])
        }
    }
    
    private static func computeSplitsInternal(template: TipTemplate, pool: Double) throws -> (splits: [Participant], warnings: [String]) {
        var warnings: [String] = []
        var participants = template.participants
        
        // Validation
        guard pool >= 0 else { throw TipCalculationError.negativePool }
        guard !participants.isEmpty else { throw TipCalculationError.noParticipants }
        
        for participant in participants {
            if let hours = participant.hours, hours < 0 {
                throw TipCalculationError.negativeHours(participantName: participant.name)
            }
            if let weight = participant.weight, weight < 0 {
                throw TipCalculationError.negativeWeight(participantName: participant.name)
            }
        }
        
        // Validate off-the-top rules
        if let offTheTopRules = template.rules.offTheTop {
            for rule in offTheTopRules where rule.percentage < 0 {
                throw TipCalculationError.invalidOffTheTopPercentage(role: rule.role, percentage: rule.percentage)
            }
        }
        
        // Validate role weights
        if let roleWeights = template.rules.roleWeights {
            for (role, weight) in roleWeights where weight < 0 {
                throw TipCalculationError.invalidRoleWeight(role: role, weight: weight)
            }
        }
        
        // Convert to cents for precise calculation
        let poolCents = Int(round(pool * 100))
        
        // Apply off-the-top deductions
        let (offTopPerID, remainderAfterOffTop, offTopWarnings) = allocateOffTheTop(
            participants: participants,
            poolCents: poolCents,
            rules: template.rules.offTheTop
        )
        warnings.append(contentsOf: offTopWarnings)
        
        // Apply main allocation rule
        let (mainPerID, mainWarnings) = allocateByRule(
            participants: participants,
            remainderCents: remainderAfterOffTop,
            rules: template.rules
        )
        warnings.append(contentsOf: mainWarnings)
        
        // Combine and fix penny rounding
        let combined = combineAndFixPennies(
            offTop: offTopPerID,
            main: mainPerID,
            targetTotal: poolCents,
            participants: participants
        )
        
        // Apply calculated amounts
        for i in participants.indices {
            participants[i].calculatedAmount = Double(combined[participants[i].id] ?? 0) / 100.0
        }
        
        return (participants, warnings)
    }
    
    // MARK: - Allocation Methods
    
    private static func allocateOffTheTop(participants: [Participant], poolCents: Int, rules: [OffTheTopRule]?) -> (perID: [UUID: Int], remainder: Int, warnings: [String]) {
        guard let rules = rules, !rules.isEmpty else { return ([:], poolCents, []) }
        
        var warnings: [String] = []
        let totalPercentage = rules.reduce(0.0) { $0 + max(0, $1.percentage) }
        guard totalPercentage > 0 else { return ([:], poolCents, []) }
        
        var scale = 1.0
        if totalPercentage > 100 {
            scale = 100 / totalPercentage
            warnings.append("Off-the-top percentages exceeded 100% and were scaled down.")
        }
        
        var perID: [UUID: Int] = [:]
        var totalAllocated = 0
        
        for rule in rules {
            let adjustedPercentage = rule.percentage * scale
            guard adjustedPercentage > 0 else { continue }
            
            let roleMembers = participants.filter { $0.role.lowercased() == rule.role.lowercased() }
            if roleMembers.isEmpty {
                warnings.append("No participants found for off-the-top role: \(rule.role)")
                continue
            }
            
            let targetCents = Int(round(Double(poolCents) * adjustedPercentage / 100.0))
            guard targetCents > 0 else { continue }
            
            let distribution = distributeEvenly(amount: targetCents, among: roleMembers)
            for (id, amount) in distribution {
                perID[id, default: 0] += amount
            }
            totalAllocated += targetCents
        }
        
        // Handle overflow
        if totalAllocated > poolCents {
            let overflow = totalAllocated - poolCents
            warnings.append("Adjusted \(overflow) cent(s) of rounding overflow.")
            perID = adjustForOverflow(perID, overflow: overflow, participants: participants)
            totalAllocated = poolCents
        }
        
        return (perID, max(0, poolCents - totalAllocated), warnings)
    }
    
    private static func allocateByRule(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
        guard remainderCents > 0 else { return ([:], []) }
        
        switch rules.type {
        case .equal:
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        case .percentage:
            return allocatePercentage(participants: participants, remainderCents: remainderCents, rules: rules)
        case .hoursBased:
            return allocateHours(participants: participants, remainderCents: remainderCents)
        case .roleWeighted:
            return allocateRoleWeighted(participants: participants, remainderCents: remainderCents, rules: rules)
        case .hybrid:
            return allocateHybrid(participants: participants, remainderCents: remainderCents, rules: rules)
        }
    }
    
    private static func allocateEqual(participants: [Participant], remainderCents: Int) -> (perID: [UUID: Int], warnings: [String]) {
        let distribution = distributeEvenly(amount: remainderCents, among: participants)
        return (distribution, [])
    }
    
    private static func allocatePercentage(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
        var warnings: [String] = []
        var weights: [UUID: Double] = [:]
        
        // Try participant weights first
        for participant in participants {
            if let weight = participant.weight {
                weights[participant.id] = max(0, weight)
            }
        }
        
        // Fall back to role weights if no participant weights
        if weights.isEmpty, let roleWeights = rules.roleWeights {
            let roleWeightsLower = roleWeights.reduce(into: [String: Double]()) {
                $0[$1.key.lowercased()] = $1.value
            }
            for participant in participants {
                weights[participant.id] = max(0, roleWeightsLower[participant.role.lowercased()] ?? 0)
            }
            
            let total = weights.values.reduce(0, +)
            if abs(total - 100) > weightNormalizationEpsilon {
                warnings.append("Weights did not sum to 100% and were normalized.")
            }
        }
        
        // Fall back to equal if still no weights
        if weights.isEmpty {
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        let distribution = distributeProportionally(
            amount: remainderCents,
            weights: weights,
            participants: participants
        )
        
        return (distribution, warnings)
    }
    
    private static func allocateHours(participants: [Participant], remainderCents: Int) -> (perID: [UUID: Int], warnings: [String]) {
        var warnings: [String] = []
        var hourMap: [UUID: Double] = [:]
        
        for participant in participants {
            hourMap[participant.id] = max(0, participant.hours ?? 0)
        }
        
        let totalHours = hourMap.values.reduce(0, +)
        if totalHours <= 0 {
            warnings.append("No hours recorded. Using equal split instead.")
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        let distribution = distributeProportionally(
            amount: remainderCents,
            weights: hourMap,
            participants: participants
        )
        
        return (distribution, warnings)
    }
    
    private static func allocateRoleWeighted(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
        var warnings: [String] = []
        
        guard let roleWeights = rules.roleWeights, !roleWeights.isEmpty else {
            warnings.append("No role weights defined. Using equal split.")
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        let roleWeightsLower = roleWeights.reduce(into: [String: Double]()) {
            $0[$1.key.lowercased()] = max(0, $1.value)
        }
        
        var roleAllocations: [(String, Double, [Participant])] = []
        var totalWeight = 0.0
        
        for (role, weight) in roleWeightsLower where weight > 0 {
            let members = participants.filter { $0.role.lowercased() == role }
            if !members.isEmpty {
                roleAllocations.append((role, weight, members))
                totalWeight += weight
            }
        }
        
        if roleAllocations.isEmpty {
            warnings.append("No matching roles found. Using equal split.")
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        if abs(totalWeight - 100) > weightNormalizationEpsilon {
            warnings.append("Role weights did not sum to 100% and were normalized.")
        }
        
        var perID: [UUID: Int] = [:]
        
        for (_, weight, members) in roleAllocations {
            let roleShare = Int(round(Double(remainderCents) * (weight / totalWeight)))
            let distribution = distributeEvenly(amount: roleShare, among: members)
            for (id, amount) in distribution {
                perID[id, default: 0] += amount
            }
        }
        
        return (perID, warnings)
    }
    
    private static func allocateHybrid(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
        var warnings: [String] = []
        
        let parsed = parseHybridFormula(rules.formula)
        if parsed.isEmpty {
            warnings.append("Invalid hybrid formula. Using equal split.")
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        var roleAllocations: [(String, Double, [Participant])] = []
        var totalPercentage = 0.0
        
        for (role, percentage) in parsed {
            let members = participants.filter { $0.role.lowercased() == role }
            if !members.isEmpty && percentage > 0 {
                roleAllocations.append((role, percentage, members))
                totalPercentage += percentage
            }
        }
        
        if roleAllocations.isEmpty {
            warnings.append("No valid roles in hybrid formula. Using equal split.")
            return allocateEqual(participants: participants, remainderCents: remainderCents)
        }
        
        if abs(totalPercentage - 100) > weightNormalizationEpsilon {
            warnings.append("Hybrid percentages did not sum to 100% and were normalized.")
        }
        
        var perID: [UUID: Int] = [:]
        
        for (_, percentage, members) in roleAllocations {
            let roleShare = Int(round(Double(remainderCents) * (percentage / totalPercentage)))
            let distribution = distributeEvenly(amount: roleShare, among: members)
            for (id, amount) in distribution {
                perID[id, default: 0] += amount
            }
        }
        
        return (perID, warnings)
    }
    
    // MARK: - Helper Methods
    
    private static func parseHybridFormula(_ formula: String) -> [(String, Double)] {
        formula.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: ":")
            guard parts.count == 2 else { return nil }
            
            let role = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let percentage = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            return (role, percentage)
        }
    }
    
    private static func distributeEvenly(amount: Int, among participants: [Participant]) -> [UUID: Int] {
        guard !participants.isEmpty else { return [:] }
        
        let baseAmount = amount / participants.count
        let remainder = amount % participants.count
        
        var distribution: [UUID: Int] = [:]
        
        // Sort participants for consistent penny distribution
        let sorted = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        for (index, participant) in sorted.enumerated() {
            distribution[participant.id] = baseAmount + (index < remainder ? 1 : 0)
        }
        
        return distribution
    }
    
    private static func distributeProportionally(amount: Int, weights: [UUID: Double], participants: [Participant]) -> [UUID: Int] {
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return [:] }
        
        var distribution: [UUID: Int] = [:]
        var allocated = 0
        
        // Calculate base amounts
        for (id, weight) in weights {
            let share = Int((Double(amount) * weight / totalWeight).rounded(.down))
            distribution[id] = share
            allocated += share
        }
        
        // Distribute remainder pennies
        let remainder = amount - allocated
        if remainder > 0 {
            let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
            let sortedIDs = weights.keys.sorted { id1, id2 in
                // Sort by fractional part descending, then by name
                let frac1 = (Double(amount) * (weights[id1] ?? 0) / totalWeight).truncatingRemainder(dividingBy: 1)
                let frac2 = (Double(amount) * (weights[id2] ?? 0) / totalWeight).truncatingRemainder(dividingBy: 1)
                
                if abs(frac1 - frac2) > 1e-9 {
                    return frac1 > frac2
                }
                
                let name1 = participantMap[id1]?.name.lowercased() ?? ""
                let name2 = participantMap[id2]?.name.lowercased() ?? ""
                return name1 < name2
            }
            
            for i in 0..<min(remainder, sortedIDs.count) {
                distribution[sortedIDs[i], default: 0] += 1
            }
        }
        
        return distribution
    }
    
    private static func combineAndFixPennies(offTop: [UUID: Int], main: [UUID: Int], targetTotal: Int, participants: [Participant]) -> [UUID: Int] {
        var combined = offTop
        
        for (id, amount) in main {
            combined[id, default: 0] += amount
        }
        
        let currentTotal = combined.values.reduce(0, +)
        let delta = targetTotal - currentTotal
        
        if delta == 0 {
            return combined
        }
        
        // Sort participants for consistent adjustment
        let sorted = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        if delta > 0 {
            // Add pennies
            for i in 0..<min(delta, sorted.count) {
                combined[sorted[i].id, default: 0] += 1
            }
        } else {
            // Remove pennies
            for i in 0..<min(-delta, sorted.count) {
                let id = sorted[sorted.count - 1 - i].id
                if let current = combined[id], current > 0 {
                    combined[id] = current - 1
                }
            }
        }
        
        return combined
    }
    
    private static func adjustForOverflow(_ distribution: [UUID: Int], overflow: Int, participants: [Participant]) -> [UUID: Int] {
        var adjusted = distribution
        var remaining = overflow
        
        // Sort participants in reverse order for removing overflow
        let sorted = participants.sorted { $0.name.lowercased() > $1.name.lowercased() }
        
        for participant in sorted {
            guard remaining > 0 else { break }
            
            if let current = adjusted[participant.id], current > 0 {
                let reduction = min(current, remaining)
                adjusted[participant.id] = current - reduction
                remaining -= reduction
            }
        }
        
        return adjusted
    }
}

// MARK: - Referral Manager

final class ReferralManager {
    static let shared = ReferralManager()
    private let bonusExpiryKey = "ReferralBonusExpiry"
    private init() {}
    
    func hasActiveBonus(now: Date = Date()) -> Bool {
        guard let expiry = UserDefaults.standard.object(forKey: bonusExpiryKey) as? Date else {
            return false
        }
        return expiry > now
    }
    
    func grantBonus(days: Int) {
        let expiry = Calendar.current.date(byAdding: .day, value: max(1, days), to: Date())
        if let expiry = expiry {
            UserDefaults.standard.set(expiry, forKey: bonusExpiryKey)
        }
    }
    
    func clearBonus() {
        UserDefaults.standard.removeObject(forKey: bonusExpiryKey)
    }
}

// MARK: - WhipCoins Manager

@MainActor
final class WhipCoinsManager: ObservableObject {
    @Published var whipCoins: Int = 0
    private let storageKey = "whipCoinsBalance"
    
    init() {
        whipCoins = UserDefaults.standard.integer(forKey: storageKey)
    }
    
    func consumeWhipCoins(_ amount: Int) -> Bool {
        guard whipCoins >= amount else { return false }
        whipCoins -= amount
        saveBalance()
        return true
    }
    
    func addWhipCoins(_ amount: Int) {
        whipCoins += amount
        saveBalance()
    }
    
    private func saveBalance() {
        UserDefaults.standard.set(whipCoins, forKey: storageKey)
    }
}

// MARK: - Template Manager

class TemplateManager: ObservableObject {
    @Published var templates: [TipTemplate] = []
    @Published var lastError: String?
    
    private let storageKey = "savedTemplates"
    
    init() {
        loadTemplates()
    }
    
    func loadTemplates() {
        do {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else {
                templates = []
                return
            }
            templates = try JSONDecoder().decode([TipTemplate].self, from: data)
            lastError = nil
        } catch {
            print("Failed to load templates: \(error)")
            templates = []
            lastError = "Failed to load saved templates."
        }
    }
    
    func saveTemplate(_ template: TipTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    func updateTemplate(_ template: TipTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }
    
    func deleteTemplate(_ template: TipTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }
    
    private func saveTemplates() {
        do {
            let encoded = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(encoded, forKey: storageKey)
            lastError = nil
        } catch {
            print("Failed to save templates: \(error)")
            lastError = "Failed to save templates."
        }
    }
}

// MARK: - Hours Store

final class HoursStore {
    static let shared = HoursStore()
    private init() {}
    private var hours: [UUID: Double] = [:]
    
    func set(id: UUID, hours value: Double?) {
        if let value = value, value >= 0 {
            hours[id] = value
        } else {
            hours.removeValue(forKey: id)
        }
    }
    
    func get(id: UUID) -> Double? {
        hours[id]
    }
    
    func apply(to template: TipTemplate) -> TipTemplate {
        var copy = template
        copy.participants = copy.participants.map { participant in
            var updated = participant
            if let hours = hours[participant.id] {
                updated.hours = hours
            }
            return updated
        }
        return copy
    }
}

// MARK: - Subscription Manager (StoreKit 2)

@MainActor
class SubscriptionManager: ObservableObject {
    // Product configuration
    private let productId = "com.neurosplit.pro.monthly"
    
    // Published state
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var product: Product?
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts = false
    @Published var hasFreeTrial = false
    @Published var trialDays = 3
    
    // Transaction listener
    private var updateListenerTask: Task<Void, Never>?
    
    enum SubscriptionStatus: String {
        case none = "Not Subscribed"
        case trial = "Free Trial"
        case active = "Active"
        case expired = "Expired"
        case pending = "Pending"
    }
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func loadProducts() async {
        await MainActor.run {
            isLoadingProducts = true
            purchaseError = nil
        }
        
        do {
            let products = try await Product.products(for: [productId])
            
            await MainActor.run {
                self.product = products.first
                if let subscription = products.first?.subscription {
                    self.hasFreeTrial = subscription.introductoryOffer != nil
                    if let intro = subscription.introductoryOffer,
                       intro.paymentMode == .freeTrial {
                        self.trialDays = Self.days(from: intro.period)
                    }
                }
                self.isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                self.purchaseError = "Could not load subscription options."
                self.isLoadingProducts = false
                print("Failed to load products: \(error)")
            }
        }
    }
    
    private static func days(from period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }
    
    func purchase() async {
        guard let product = product else {
            await MainActor.run {
                self.purchaseError = "Subscription product not available."
            }
            return
        }
        
        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await updateSubscriptionStatus()
                    await transaction.finish()
                    
                    await MainActor.run {
                        self.isPurchasing = false
                    }
                    
                case .unverified(_, let error):
                    await MainActor.run {
                        self.purchaseError = "Could not verify purchase."
                        self.isPurchasing = false
                        print("Transaction verification failed: \(error)")
                    }
                }
                
            case .userCancelled:
                await MainActor.run {
                    self.isPurchasing = false
                }
                
            case .pending:
                await MainActor.run {
                    self.subscriptionStatus = .pending
                    self.isPurchasing = false
                    self.purchaseError = "Purchase is pending approval."
                }
                
            @unknown default:
                await MainActor.run {
                    self.isPurchasing = false
                    self.purchaseError = "An unexpected error occurred."
                }
            }
        } catch {
            await MainActor.run {
                self.purchaseError = "Purchase failed: \(error.localizedDescription)"
                self.isPurchasing = false
                print("Purchase error: \(error)")
            }
        }
    }
    
    func restorePurchases() async {
        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
        }
        
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        
        await MainActor.run {
            isPurchasing = false
            
            if !isSubscribed {
                purchaseError = "No active subscription found."
            }
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var isInTrial = false
        
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == productId {
                    hasActiveSubscription = true
                    
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        let originalPurchaseDate = transaction.originalPurchaseDate
                        if transaction.purchaseDate == originalPurchaseDate,
                           let trialEnd = Calendar.current.date(byAdding: .day, value: trialDays, to: originalPurchaseDate),
                           Date() < trialEnd {
                            isInTrial = true
                        }
                    }
                }
                
            case .unverified(_, let error):
                print("Unverified transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.isSubscribed = hasActiveSubscription
            
            if hasActiveSubscription {
                self.subscriptionStatus = isInTrial ? .trial : .active
            } else {
                self.subscriptionStatus = .none
            }
            
            // Check referral bonus
            if !self.isSubscribed && ReferralManager.shared.hasActiveBonus() {
                self.isSubscribed = true
                self.subscriptionStatus = .trial
            }
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { continue }
                
                switch result {
                case .verified(let transaction):
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    print("Unverified transaction update: \(error)")
                }
            }
        }
    }
}

// MARK: - API Service

@MainActor
class APIService: ObservableObject {
    @Published var showOfflineAlert = false
    @Published var showMissingKeyAlert = false
    @Published var lastStatusMessage = "Idle"
    
    private let session: URLSession
    private let networkMonitor = NetworkMonitor()
    private let baseURL = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    private var effectiveAPIKey: String {
        // Try Info.plist first
        if let key = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        
        // Try UserDefaults override
        if let override = UserDefaults.standard.string(forKey: "DeepSeekAPIKeyOverride"),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        
        // Try environment variable
        if let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        
        return ""
    }
    
    func setAPIKeyOverride(_ key: String) {
        UserDefaults.standard.set(key, forKey: "DeepSeekAPIKeyOverride")
    }
    
    func clearAPIKeyOverride() {
        UserDefaults.standard.removeObject(forKey: "DeepSeekAPIKeyOverride")
    }
    
    private func checkNetworkConnection() throws {
        guard networkMonitor.isConnected else {
            showOfflineAlert = true
            throw APIError.noInternetConnection
        }
    }
    
    func sendOnboardingMessage(
        userInput: String,
        sessionId: String,
        turnNumber: Int
    ) async throws -> OnboardingResponse {
        let systemPrompt = """
        You are NeurospLIT's onboarding assistant. Help users set up tip splitting rules.
        Be concise and friendly. Ask clarifying questions when needed.
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userInput)
        ]
        
        do {
            let content = try await performChat(model: "deepseek-chat", messages: messages)
            
            return OnboardingResponse(
                status: turnNumber < 5 ? .inProgress : .complete,
                message: content,
                clarificationNeeded: turnNumber < 5,
                template: turnNumber >= 5 ? createSampleTemplate() : nil,
                suggestedQuestions: turnNumber < 5 ? generateSuggestedQuestions(turnNumber: turnNumber) : nil
            )
        } catch {
            if error.isNetworkError {
                return OnboardingResponse(
                    status: .inProgress,
                    message: "Let me help you set up your tip splitting rules.",
                    clarificationNeeded: true,
                    template: nil,
                    suggestedQuestions: ["We pool everything", "Each person keeps their own"]
                )
            }
            throw error
        }
    }
    
    func calculateSplit(template: TipTemplate, tipPool: Double) async throws -> CalculationResponse {
        let result = TipSplitEngine.computeSplits(template: template, pool: tipPool)
        
        return CalculationResponse(
            splits: result.splits,
            summary: "Split based on \(template.rules.type.rawValue) rules",
            warnings: result.warnings.isEmpty ? nil : result.warnings,
            visualizationHints: nil
        )
    }
    
    private func performChat(model: String, messages: [ChatMessage]) async throws -> String {
        lastStatusMessage = "Sending..."
        
        try checkNetworkConnection()
        
        let key = effectiveAPIKey
        guard !key.isEmpty else {
            showMissingKeyAlert = true
            throw APIError.missingCredentials
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let body = ChatRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            lastStatusMessage = "HTTP \(http.statusCode)"
            guard 200..<300 ~= http.statusCode else {
                throw APIError.serverError(http.statusCode)
            }
        }
        
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        lastStatusMessage = "Success"
        return content
    }
    
    private func createSampleTemplate() -> TipTemplate {
        TipTemplate(
            name: "Default Team Split",
            createdDate: Date(),
            rules: TipRules(
                type: .percentage,
                formula: "servers:70,support:30",
                offTheTop: nil,
                roleWeights: ["server": 35, "busser": 15, "host": 15],
                customLogic: nil
            ),
            participants: [
                Participant(name: "Alex", role: "Server", hours: nil, weight: 35),
                Participant(name: "Sam", role: "Server", hours: nil, weight: 35),
                Participant(name: "Jordan", role: "Busser", hours: nil, weight: 15),
                Participant(name: "Pat", role: "Host", hours: nil, weight: 15)
            ],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: true
            )
        )
    }
    
    private func generateSuggestedQuestions(turnNumber: Int) -> [String] {
        switch turnNumber {
        case 1:
            return ["We pool everything", "Everyone keeps their own", "It depends on the shift"]
        case 2:
            return ["Equal split", "Based on hours worked", "Based on role"]
        case 3:
            return ["Yes, we have managers", "No special deductions", "Bartenders get extra"]
        default:
            return ["That's correct", "Let me clarify", "Start over"]
        }
    }
}

// MARK: - API Models

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
}

struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
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

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case noInternetConnection
    case requestTimeout
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    case unknown(Error)
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint"
        case .noInternetConnection:
            return "Internet connection required. Please check your connection."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .invalidResponse:
            return "Received invalid response from server"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .missingCredentials:
            return "API key missing. Please add DEEPSEEK_API_KEY to Info.plist."
        }
    }
}

extension Error {
    var isNetworkError: Bool {
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain || nsError.domain == NSPOSIXErrorDomain
    }
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var isExpensive = false
    @Published var connectionType = NWInterface.InterfaceType.other
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.connectionType = self?.resolveType(path) ?? .other
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func resolveType(_ path: NWPath) -> NWInterface.InterfaceType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        return .other
    }
}

// MARK: - Pricing Policy

struct CreditsResult {
    var whipCoins: Int
    var breakdown: [CreditsBreakdownItem]
    var policyVersion: String
    var seed: String
}

struct CreditsBreakdownItem {
    var label: String
    var deltaWhipCoins: Int
}

struct PricingMeta {
    var instructionText: String?
    var seed: String?
}

enum PricingPolicy {
    static func calculateWhipCoins(template: TipTemplate, meta: PricingMeta? = nil) -> CreditsResult {
        var total = 200
        var breakdown: [CreditsBreakdownItem] = [
            CreditsBreakdownItem(label: "Base", deltaWhipCoins: 200)
        ]
        
        let roleCount = template.participants.count
        if (2...3).contains(roleCount) {
            total += 50
            breakdown.append(CreditsBreakdownItem(label: "Roles 2–3", deltaWhipCoins: 50))
        } else if (4...6).contains(roleCount) {
            total += 100
            breakdown.append(CreditsBreakdownItem(label: "Roles 4–6", deltaWhipCoins: 100))
        } else if roleCount >= 7 {
            total += 150
            breakdown.append(CreditsBreakdownItem(label: "Roles 7+", deltaWhipCoins: 150))
        }
        
        if !(template.rules.offTheTop?.isEmpty ?? true) {
            total += 75
            breakdown.append(CreditsBreakdownItem(label: "Off-the-top bonuses", deltaWhipCoins: 75))
        }
        
        if template.rules.type == .hoursBased {
            total += 50
            breakdown.append(CreditsBreakdownItem(label: "Hours-based modifiers", deltaWhipCoins: 50))
        }
        
        let hasPercent = !(template.rules.roleWeights?.isEmpty ?? true) || 
                        template.participants.contains { $0.weight != nil }
        let hasPerPerson = template.participants.contains { $0.hours != nil }
        
        if hasPercent && hasPerPerson {
            total += 80
            breakdown.append(CreditsBreakdownItem(label: "Hybrid rules", deltaWhipCoins: 80))
        }
        
        if let custom = template.rules.customLogic, !custom.isEmpty {
            total += 100
            breakdown.append(CreditsBreakdownItem(label: "Nested logic", deltaWhipCoins: 100))
        }
        
        let instructionSource = meta?.instructionText ?? template.rules.customLogic ?? template.rules.formula
        let tokenCount = instructionSource.split(whereSeparator: { $0.isWhitespace }).count
        if tokenCount > 300 {
            total += 40
            breakdown.append(CreditsBreakdownItem(label: "Long instructions", deltaWhipCoins: 40))
        }
        
        total = max(200, min(2000, total))
        
        return CreditsResult(
            whipCoins: total,
            breakdown: breakdown,
            policyVersion: "WC-1.0",
            seed: meta?.seed ?? UUID().uuidString
        )
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        
        let a, r, g, b: UInt64
        switch sanitized.count {
        case 3:
            (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8:
            (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

extension Double {
    func currencyFormatted(locale: Locale = .current, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        if let code = currencyCode {
            formatter.currencyCode = code
        }
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}

// MARK: - Environment Keys

private struct TemplateManagerKey: EnvironmentKey {
    static let defaultValue = TemplateManager()
}

private struct SubscriptionManagerKey: EnvironmentKey {
    @MainActor
    static var defaultValue: SubscriptionManager = {
        SubscriptionManager()
    }()
}

private struct APIServiceKey: EnvironmentKey {
    @MainActor
    static var defaultValue: APIService {
        APIService()
    }
}

extension EnvironmentValues {
    var templateManager: TemplateManager {
        get { self[TemplateManagerKey.self] }
        set { self[TemplateManagerKey.self] = newValue }
    }
    
    var subscriptionManager: SubscriptionManager {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }
    
    var apiService: APIService {
        get { self[APIServiceKey.self] }
        set { self[APIServiceKey.self] = newValue }
    }
}

// MARK: - Utility Functions

func formatTemplateJSON(_ template: TipTemplate) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    
    guard let data = try? encoder.encode(template),
          let json = String(data: data, encoding: .utf8) else {
        return "Unable to display template data"
    }
    
    return json
}

func buildCSV(for result: SplitResult) -> String {
    var rows: [String] = ["Name,Role,Amount"]
    
    for participant in result.splits {
        let amount = (participant.calculatedAmount ?? 0).currencyFormatted()
        let escapedName = csvEscape(participant.name)
        let escapedRole = csvEscape(participant.role)
        let escapedAmount = csvEscape(amount)
        rows.append("\(escapedName),\(escapedRole),\(escapedAmount)")
    }
    
    return rows.joined(separator: "\n")
}

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\n") || value.contains("\"") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

// MARK: - Views

struct RootView: View {
    @Environment(\.templateManager) private var templateManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.apiService) private var apiService
    
    @State private var showOnboarding = false
    @State private var selectedTemplate: TipTemplate?
    @State private var showWhipCoins = false
    
    var body: some View {
        NavigationView {
            if templateManager.templates.isEmpty && !showOnboarding {
                WelcomeView(showOnboarding: $showOnboarding)
            } else if showOnboarding {
                OnboardingFlowView(showOnboarding: $showOnboarding, showWhipCoins: $showWhipCoins)
            } else {
                MainDashboardView(
                    selectedTemplate: $selectedTemplate,
                    showOnboarding: $showOnboarding,
                    showWhipCoins: $showWhipCoins
                )
            }
        }
        .sheet(isPresented: $showWhipCoins) {
            WhipCoinsView(showWhipCoins: $showWhipCoins)
        }
        .alert(
            "Internet Connection Required",
            isPresented: Binding(
                get: { apiService.showOfflineAlert },
                set: { apiService.showOfflineAlert = $0 }
            )
        ) {
            Button("OK") { }
        } message: {
            Text("NeurospLIT requires an internet connection for setup and calculations.")
        }
        .sheet(isPresented: Binding(
            get: { apiService.showMissingKeyAlert },
            set: { apiService.showMissingKeyAlert = $0 }
        )) {
            CredentialsView(isPresented: Binding(
                get: { apiService.showMissingKeyAlert },
                set: { apiService.showMissingKeyAlert = $0 }
            ))
        }
    }
}

struct WelcomeView: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            logoSection
            titleSection
            
            Spacer()
            
            VStack(spacing: 20) {
                featuresSection
                setupButton
            }
            .padding()
        }
        .padding()
    }
    
    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            
            Text("💰")
                .font(.system(size: 60))
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 16) {
            Text("Welcome to NeurospLIT")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Fair tip splits in seconds.\nNo math. Total transparency.")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "mic.fill", text: "Describe your rules in plain English")
            FeatureRow(icon: "chart.pie.fill", text: "Instant visual breakdowns")
            FeatureRow(icon: "exclamationmark.triangle", text: "Spot discrepancies automatically")
            FeatureRow(icon: "square.and.arrow.up", text: "Share with your team instantly")
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var setupButton: some View {
        Button(action: { showOnboarding = true }) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("Set Up Your First Template")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// Additional views continue in NeurospLITViews.swift...
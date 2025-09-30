// WhipTipApp.swift
// Monolithic Single-File Build

import SwiftUI
import Combine
import Network
import UIKit
import StoreKit
import PDFKit
import AVFoundation
import Speech

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch sanitized.count {
        case 3: (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8: (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: Double(a) / 255.0)
    }
}

extension Double {
    private static var _cachedFormatters: [String: NumberFormatter] = [:]
    private static func formatter(locale: Locale, currencyCode: String?) -> NumberFormatter {
        let key = locale.identifier + (currencyCode ?? "")
        if let existing = _cachedFormatters[key] { return existing }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        if let code = currencyCode { f.currencyCode = code }
        _cachedFormatters[key] = f
        return f
    }

    func currencyFormatted(locale: Locale = .current, currencyCode: String? = nil) -> String {
        if !Thread.isMainThread {
            let temp = NumberFormatter(); temp.numberStyle = .currency; temp.locale = locale; if let code = currencyCode { temp.currencyCode = code }
            return temp.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
        }
        let formatter = Self.formatter(locale: locale, currencyCode: currencyCode)
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
}

extension Error { 
    var isNetworkError: Bool { 
        let ns = self as NSError; return ns.domain == NSURLErrorDomain || ns.domain == NSPOSIXErrorDomain 
    } 
}

private struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

private extension View {
    func keyboardDoneToolbar() -> some View { modifier(KeyboardDoneToolbar()) }
}

// MARK: - Errors

enum AppError: Error, LocalizedError, Identifiable {
    case network(NetworkError)
    case authentication(AuthenticationError)
    case api(ApiError)
    case general(title: String, message: String)
    
    enum NetworkError {
        case invalidURL
        case noInternetConnection
        case requestTimeout
        case serverError(Int)
        case networkError(Int)
        case serviceUnavailable
        case circuitOpen
    }
    
    enum AuthenticationError {
        case missingCredentials
        case unauthorized
        case forbidden
        case throttled
        case missingToken
        case invalidResponse
        case backendUnavailable
        case emptyToken
        case expired
        case networkFailure(String)
        case decodingFailure
    }
    
    enum ApiError {
        case invalidResponse
        case decodingError(Error)
        case unknown(Error)
    }
    
    var id: String {
        switch self {
        case .network(let error): return "network-\(error)"
        case .authentication(let error): return "auth-\(error)"
        case .api(let error): return "api-\(error)"
        case .general(let title, _): return "general-\(title)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            switch error {
            case .invalidURL: return "Invalid API endpoint"
            case .noInternetConnection: return "Internet connection required. Please check your connection."
            case .requestTimeout: return "Request timed out. Please try again."
            case .serverError(let code): return "Server error (HTTP \(code))"
            case .networkError(let code): return "Network error (HTTP \(code))"
            case .serviceUnavailable: return "Service temporarily unavailable. Please try again shortly."
            case .circuitOpen: return "Network temporarily disabled due to repeated failures. Retrying soon."
            }
            
        case .authentication(let error):
            switch error {
            case .missingCredentials: return "DeepSeek API key missing. Add DEEPSEEK_API_KEY to Info.plist."
            case .unauthorized: return "Unauthorized. Please verify your API key."
            case .forbidden: return "Access forbidden. Your key may not have access to this resource."
            case .throttled: return "You're sending requests too quickly. Please wait and try again."
            case .missingToken: return "Token provider returned no value."
            case .invalidResponse: return "Invalid token response."
            case .backendUnavailable: return "Token backend unavailable."
            case .emptyToken: return "Empty token returned."
            case .expired: return "Token expired."
            case .networkFailure(let message): return "Token network failure: \(message)"
            case .decodingFailure: return "Unable to decode token response."
            }
            
        case .api(let error):
            switch error {
            case .invalidResponse: return "Received invalid response from server"
            case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
            case .unknown(let error): return "An unexpected error occurred: \(error.localizedDescription)"
            }
            
        case .general(let title, let message):
            return "\(title): \(message)"
        }
    }
    
    var title: String {
        switch self {
        case .network(let error):
            switch error {
            case .invalidURL: return "Invalid URL"
            case .noInternetConnection: return "No Internet"
            case .requestTimeout: return "Timeout"
            case .serverError: return "Server Error"
            case .networkError: return "Network Error"
            case .serviceUnavailable: return "Service Unavailable"
            case .circuitOpen: return "Circuit Open"
            }
        case .authentication(let error):
            switch error {
            case .missingCredentials: return "Missing Credentials"
            case .unauthorized: return "Unauthorized"
            case .forbidden: return "Forbidden"
            case .throttled: return "Rate Limited"
            case .missingToken: return "Missing Token"
            case .invalidResponse: return "Invalid Response"
            case .backendUnavailable: return "Service Unavailable"
            case .emptyToken: return "Empty Token"
            case .expired: return "Expired Token"
            case .networkFailure: return "Network Failure"
            case .decodingFailure: return "Decoding Error"
            }
        case .api(let error):
            switch error {
            case .invalidResponse: return "Invalid Response"
            case .decodingError: return "Decoding Error"
            case .unknown: return "Unknown Error"
            }
        case .general(let title, _):
            return title
        }
    }
    
    var message: String {
        return self.errorDescription ?? "An unknown error occurred"
    }
    
    var recoveryAction: (() -> Void)? {
        return nil
    }
}

enum WhipCoreError: Error, LocalizedError, Equatable {
    case negativePool
    case noParticipants
    case negativeHours(participantName: String)
    case negativeWeight(participantName: String)
    case invalidOffTheTopPercentage(role: String, percentage: Double)
    case invalidRoleWeight(role: String, weight: Double)

    var errorDescription: String? {
        switch self {
        case .negativePool:
            return "Pool cannot be negative."
        case .noParticipants:
            return "No participants to split."
        case .negativeHours(let name):
            return "Negative hours for participant: \(name)."
        case .negativeWeight(let name):
            return "Negative weight for participant: \(name)."
        case .invalidOffTheTopPercentage(let role, let pct):
            return "Invalid off-the-top percentage \(pct) for role: \(role)."
        case .invalidRoleWeight(let role, let w):
            return "Invalid role weight \(w) for role: \(role)."
        }
    }
}

// MARK: - Models

struct TipRules: Codable {
    enum RuleType: String, Codable, CaseIterable {
        case hoursBased = "hours"
        case percentage = "percentage"
        case equal = "equal"
        case roleWeighted = "roleWeighted"
        case hybrid = "hybrid"

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
    var formula: String
    var offTheTop: [OffTheTopRule]?
    var roleWeights: [String: Double]?
    var customLogic: String?
}

struct OffTheTopRule: Codable { 
    var role: String
    var percentage: Double 
}

typealias OffTheTop = OffTheTopRule // legacy compatibility

struct Participant: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var hours: Double?
    var weight: Double?
    var calculatedAmount: Double?
    var actualAmount: Double?

    var emoji: String {
        switch role.lowercased() {
        case "server": return "👤"
        case "busser": return "🍽️"
        case "host": return "🎯"
        case "bartender": return "🍹"
        case "cook", "kitchen": return "👨‍🍳"
        case "manager": return "💼"
        default: return "💰"
        }
    }

    var color: Color {
        switch role.lowercased() {
        case "server": return .purple
        case "busser": return .blue
        case "host": return .mint
        case "bartender": return .orange
        case "cook", "kitchen": return .pink
        case "manager": return .indigo
        default: return .gray
        }
    }
}

struct DisplayConfig: Codable {
    var primaryVisualization: String
    var accentColor: String
    var showPercentages: Bool
    var showComparison: Bool
}

struct TipTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    var rules: TipRules
    var participants: [Participant]
    var displayConfig: DisplayConfig
    var schemaVersion: TemplateVersion = TemplateVersion(version: TemplateVersion.currentVersion, createdWith: TemplateVersion.currentAppVersion)
}

struct TemplateVersion: Codable {
    let version: Int
    let createdWith: String // app version

    static let currentVersion: Int = 1
    static var currentAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

struct TemplateMigrationService {
    struct MigrationNote: CustomStringConvertible { let description: String }

    static func migrate(templates: [TipTemplate]) -> (migrated: [TipTemplate], notes: [MigrationNote]) {
        var notes: [MigrationNote] = []
        var changed = false
        let migrated = templates.map { tpl -> TipTemplate in
            var t = tpl
            let currentVersion = TemplateVersion.currentVersion
            if t.schemaVersion.version < currentVersion {
                notes.append(MigrationNote(description: "Upgraded template '\(t.name)' schema from v\(t.schemaVersion.version) to v\(currentVersion)"))
                t.schemaVersion = TemplateVersion(version: currentVersion, createdWith: TemplateVersion.currentAppVersion)
                changed = true
            }
            return t
        }
        return (changed ? migrated : templates, notes)
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

    enum PurchaseResult { case success, userCancelled, pending }

    func purchase() async throws -> PurchaseResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        return .success
    }
}

// MARK: - Engine

private let weightNormalizationEpsilon = 0.001

func computeSplits(template: TipTemplate, pool: Double) -> SplitResult {
    do {
        let (splits, warnings) = try _computeSplitsInternal(template: template, pool: pool)
        return SplitResult(splits: splits, warnings: warnings)
    } catch {
        return SplitResult(splits: template.participants, warnings: [error.localizedDescription])
    }
}

private func _computeSplitsInternal(template: TipTemplate, pool: Double) throws -> (splits: [Participant], warnings: [String]) {
    var warnings: [String] = []
    var participants = template.participants
    if pool < 0 { throw WhipCoreError.negativePool }
    if participants.isEmpty { throw WhipCoreError.noParticipants }
    for p in participants {
        if let h = p.hours, h < 0 { throw WhipCoreError.negativeHours(participantName: p.name) }
        if let w = p.weight, w < 0 { throw WhipCoreError.negativeWeight(participantName: p.name) }
    }
    if let ott = template.rules.offTheTop {
        for r in ott where r.percentage < 0 {
            throw WhipCoreError.invalidOffTheTopPercentage(role: r.role, percentage: r.percentage)
        }
    }
    if let rw = template.rules.roleWeights {
        for (role, w) in rw where w < 0 { throw WhipCoreError.invalidRoleWeight(role: role, weight: w) }
    }
    let poolCents = Int(round(pool * 100))
    let (offTopPerID, remainderAfterOffTop, offTopWarnings) = _allocateOffTheTop(participants: participants, poolCents: poolCents, rules: template.rules.offTheTop)
    warnings.append(contentsOf: offTopWarnings)
    let (mainPerID, mainWarnings) = _allocateByRule(participants: participants, remainderCents: remainderAfterOffTop, rules: template.rules)
    warnings.append(contentsOf: mainWarnings)
    let combined = _combineAndFixPennies(offTop: offTopPerID, main: mainPerID, targetTotal: poolCents, participants: participants)
    for i in participants.indices { participants[i].calculatedAmount = Double(combined[participants[i].id] ?? 0) / 100.0 }
    return (participants, warnings)
}

private func _allocateOffTheTop(participants: [Participant], poolCents: Int, rules: [OffTheTopRule]?) -> (perID: [UUID:Int], remainder: Int, warnings: [String]) {
    guard let rules = rules, !rules.isEmpty else { return ([:], poolCents, []) }
    var warnings: [String] = []
    let rawSum = rules.reduce(0.0) { $0 + max(0,$1.percentage) }
    if rawSum <= 0 { return ([:], poolCents, []) }
    var scale = 1.0
    if rawSum > 100 { scale = 100 / rawSum; warnings.append("Off-the-top total percentage exceeded 100%; clamped.") }
    var perID: [UUID:Int] = [:]
    var totalAllocated = 0
    for rule in rules {
        let adjPct = rule.percentage * scale
        guard adjPct > 0 else { continue }
        let members = participants.filter { $0.role.lowercased() == rule.role.lowercased() }
        if members.isEmpty { warnings.append("Off-the-top role \(rule.role) has no participants"); continue }
        let target = Int(round(Double(poolCents) * adjPct / 100.0))
        guard target > 0 else { continue }
        let eachRaw = Double(target)/Double(members.count)
        var base:[UUID:Int] = [:]; var rema:[UUID:Double]=[:]; var floorSum=0
        for m in members { let f = Int(eachRaw); base[m.id]=f; floorSum+=f; rema[m.id]=eachRaw-Double(f) }
        let remaining = target - floorSum
        if remaining > 0 {
            let ordered = _orderForPennyDistribution(ids: members.map{ $0.id }, remainders: rema, participants: participants, context: .offTop)
            for i in 0..<remaining { base[ordered[i], default:0]+=1 }
        }
        for (k,v) in base { perID[k, default:0]+=v }
        totalAllocated += target
    }
    if totalAllocated > poolCents {
        let delta = totalAllocated - poolCents
        warnings.append("Off-the-top rounding overflow of \(delta) cents adjusted.")
        let ordered = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }.map{ $0.id }
        var remain = delta
        for id in ordered.reversed() where remain > 0 { if let cur = perID[id], cur > 0 { perID[id]=cur-1; remain-=1 } }
        totalAllocated = poolCents
    }
    let remainder = max(0, poolCents - totalAllocated)
    return (perID, remainder, warnings)
}

private func _allocateByRule(participants:[Participant], remainderCents:Int, rules: TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    guard remainderCents > 0 else { return ([:], []) }
    switch rules.type {
    case .equal: return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .equal)
    case .percentage: return _allocatePercentage(participants: participants, remainderCents: remainderCents, rules: rules)
    case .hoursBased: return _allocateHours(participants: participants, remainderCents: remainderCents)
    case .roleWeighted: return _allocateRoleWeighted(participants: participants, remainderCents: remainderCents, rules: rules)
    case .hybrid: return _allocateHybrid(participants: participants, remainderCents: remainderCents, rules: rules)
    }
}

private func _allocateEqual(participants:[Participant], remainderCents:Int, ruleType: TipRules.RuleType) -> (perID:[UUID:Int], warnings:[String]) {
    let rawEach = Double(remainderCents)/Double(participants.count)
    var base:[UUID:Int]=[:]; var rema:[UUID:Double]=[:]; var floorSum=0
    for p in participants { let f = Int(rawEach); base[p.id]=f; floorSum+=f; rema[p.id]=rawEach-Double(f) }
    let remaining = remainderCents - floorSum
    if remaining > 0 {
        let ordered = _orderForPennyDistribution(ids: participants.map{ $0.id }, remainders: rema, participants: participants, context: .equal(ruleType))
        for i in 0..<remaining { base[ordered[i], default:0]+=1 }
    }
    return (base, [])
}

private func _allocatePercentage(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    var weights:[UUID:Double]=[:]
    var usedRoleWeights = false
    let roleWeightsLower = rules.roleWeights?.reduce(into:[String:Double]()) { $0[$1.key.lowercased()] = $1.value }
    for p in participants { if let w = p.weight { weights[p.id]=max(0,w) } }
    if weights.isEmpty, let roleWeightsLower = roleWeightsLower {
        usedRoleWeights = true
        for p in participants { weights[p.id] = max(0, roleWeightsLower[p.role.lowercased()] ?? 0) }
    }
    if weights.isEmpty { return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .percentage) }
    let total = weights.values.reduce(0,+)
    if total <= 0 { return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .percentage) }
    if usedRoleWeights && abs(total - 100) > weightNormalizationEpsilon {
        warnings.append("Role weights for percentage did not sum to 100; normalized.")
    }
    var raw:[UUID:Double]=[:]
    for (id,w) in weights { raw[id] = Double(remainderCents) * (w/total) }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .percentage)
    return (rounded, warnings)
}

private func _allocateHours(participants:[Participant], remainderCents:Int) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    var hours:[UUID:Double]=[:]
    for p in participants { if let h = p.hours { hours[p.id]=max(0,h) } }
    if hours.isEmpty { 
        warnings.append("No participants have hours; using equal distribution.")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hoursBased)
    }
    let total = hours.values.reduce(0,+)
    if total <= 0 { 
        warnings.append("Total hours is zero or negative; using equal distribution.")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hoursBased)
    }
    var raw:[UUID:Double]=[:]
    for (id,h) in hours { raw[id] = Double(remainderCents) * (h/total) }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .hours)
    return (rounded, warnings)
}

private func _allocateRoleWeighted(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    guard let roleWeights = rules.roleWeights, !roleWeights.isEmpty else {
        warnings.append("No role weights defined; using equal distribution.")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted)
    }
    let roleWeightsLower = roleWeights.reduce(into:[String:Double]()) { $0[$1.key.lowercased()] = $1.value }
    var weights:[UUID:Double]=[:]
    for p in participants { weights[p.id] = max(0, roleWeightsLower[p.role.lowercased()] ?? 0) }
    let total = weights.values.reduce(0,+)
    if total <= 0 { 
        warnings.append("Total role weights sum to zero; using equal distribution.")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted)
    }
    if abs(total - 100) > weightNormalizationEpsilon {
        warnings.append("Role weights did not sum to 100; normalized.")
    }
    var raw:[UUID:Double]=[:]
    for (id,w) in weights { raw[id] = Double(remainderCents) * (w/total) }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .roleWeighted)
    return (rounded, warnings)
}

private func _allocateHybrid(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    let formula = rules.formula.trimmingCharacters(in: .whitespacesAndNewlines)
    if formula.isEmpty {
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hybrid)
    }
    do {
        let parsed = try _parseHybridFormula(formula: formula)
        return _processHybrid(allocations: parsed, participants: participants, remainderCents: remainderCents)
    } catch {
        return ([UUID:Int](), ["Hybrid formula error: \(error.localizedDescription)"])
    }
}

private enum _RoundingContext { 
    case percentage, hours, offTop, equal(TipRules.RuleType), roleWeighted, hybrid 
}

private func _parseHybridFormula(formula: String) throws -> [(role:String, weight:Double)] {
    let parts = formula.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    var result: [(role: String, weight: Double)] = []
    for part in parts {
        let pieces = part.split(separator: ":", omittingEmptySubsequences: true)
        guard pieces.count == 2,
              let role = pieces.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              let weight = Double(pieces.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") else {
            throw WhipCoreError.invalidRoleWeight(role: part, weight: 0)
        }
        result.append((role: role, weight: weight))
    }
    return result
}

private func _processHybrid(allocations: [(role:String, weight:Double)], participants: [Participant], remainderCents: Int) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings: [String] = []
    var totalAllocation = 0
    var result: [UUID:Int] = [:]
    for (role, pct) in allocations {
        var matches = participants.filter { $0.role.lowercased() == role.lowercased() }
        if matches.isEmpty { 
            warnings.append("Role '\(role)' in formula has no matching participants.")
            continue
        }
        let allocation = Int(round(Double(remainderCents) * pct / 100.0))
        if allocation <= 0 { continue }
        totalAllocation += allocation
        let equal = Double(allocation) / Double(matches.count)
        var base = Int(equal)
        var remainder = allocation - (base * matches.count)
        for p in matches {
            result[p.id] = base
        }
        matches.sort { $0.name < $1.name }
        for i in 0..<remainder {
            result[matches[i % matches.count].id, default: 0] += 1
        }
    }
    if totalAllocation < remainderCents {
        let remaining = remainderCents - totalAllocation
        warnings.append("Hybrid formula only allocated \(totalAllocation) of \(remainderCents) cents; distributing \(remaining) cents equally.")
        var others = participants.filter { result[$0.id] == nil }
        if others.isEmpty { others = participants }
        let equal = Double(remaining) / Double(others.count)
        var base = Int(equal)
        var remainder = remaining - (base * others.count)
        for p in others {
            result[p.id, default: 0] += base
        }
        others.sort { $0.name < $1.name }
        for i in 0..<remainder {
            result[others[i % others.count].id, default: 0] += 1
        }
    } else if totalAllocation > remainderCents {
        let excess = totalAllocation - remainderCents
        warnings.append("Hybrid formula allocated \(excess) cents too many; adjusting down.")
        let sortedEntries = result.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key.uuidString < $1.key.uuidString) }
        var remaining = excess
        for (id, _) in sortedEntries where remaining > 0 {
            result[id, default: 0] -= 1
            remaining -= 1
        }
    }
    return (result, warnings)
}

private func _finalizeRounding(raw:[UUID:Double], targetTotal:Int, participants:[Participant], context: _RoundingContext) -> (rounded:[UUID:Int], warnings:[String]) {
    var floorSum = 0
    var rounded:[UUID:Int]=[:]; var rema:[UUID:Double]=[:];
    for (id, amt) in raw {
        let floor = Int(amt)
        rounded[id] = floor
        floorSum += floor
        rema[id] = amt - Double(floor)
    }
    let remaining = targetTotal - floorSum
    guard remaining > 0 else { return (rounded, []) }
    let ordered = _orderForPennyDistribution(ids: Array(raw.keys), remainders: rema, participants: participants, context: context)
    for i in 0..<remaining where i < ordered.count { rounded[ordered[i], default:0] += 1 }
    return (rounded, [])
}

private func _combineAndFixPennies(offTop:[UUID:Int], main:[UUID:Int], targetTotal:Int, participants:[Participant]) -> [UUID:Int] {
    var combined:[UUID:Int] = [:]
    var totalAllocated = 0
    for p in participants {
        let amt = (offTop[p.id] ?? 0) + (main[p.id] ?? 0)
        combined[p.id] = amt
        totalAllocated += amt
    }
    if totalAllocated != targetTotal {
        let delta = targetTotal - totalAllocated
        if delta > 0 {
            let ordered = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }
            var remain = delta
            for p in ordered where remain > 0 { combined[p.id, default:0]+=1; remain-=1 }
        } else if delta < 0 {
            let ordered = participants.sorted { $0.name.lowercased() > $1.name.lowercased() }
            var remain = -delta
            for p in ordered where remain > 0 { if let cur = combined[p.id], cur > 0 { combined[p.id]=cur-1; remain-=1 } }
        }
    }
    return combined
}

private func _orderForPennyDistribution(ids:[UUID], remainders:[UUID:Double], participants:[Participant], context: _RoundingContext) -> [UUID] {
    let participantByID = participants.reduce(into: [UUID:Participant]()) { $0[$1.id] = $1 }
    return ids.sorted { a, b in
        let remainA = remainders[a] ?? 0
        let remainB = remainders[b] ?? 0
        if abs(remainA - remainB) > weightNormalizationEpsilon {
            return remainA > remainB
        }
        let nameA = participantByID[a]?.name.lowercased() ?? ""
        let nameB = participantByID[b]?.name.lowercased() ?? ""
        return nameA < nameB
    }
}

func computeSplitsCompat(template: TipTemplate, pool: Double) -> (splits: [Participant], warnings: [String]) {
    let r = computeSplits(template: template, pool: pool)
    return (r.splits, r.warnings)
}

func formatTemplateJSON(_ template: TipTemplate) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(template), let json = String(data: data, encoding: .utf8) else {
        return "Unable to display template data"
    }
    return json
}

private func _csvEscape(_ v: String) -> String {
    if v.contains(",") || v.contains("\n") || v.contains("\"") { return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    return v
}

func buildCSV(for result: SplitResult) -> String {
    var rows: [String] = ["Name,Role,Amount"]
    for p in result.splits { let amt = (p.calculatedAmount ?? 0).currencyFormatted(); rows.append("\(_csvEscape(p.name)),\(_csvEscape(p.role)),\(_csvEscape(amt))") }
    return rows.joined(separator: "\n")
}

// MARK: - Services

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

    deinit { monitor.cancel() }

    private func resolveType(_ path: NWPath) -> NWInterface.InterfaceType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        return .other
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
            lastError = "Failed to load saved templates. Starting fresh."
        }
    }
    
    func saveTemplate(_ template: TipTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    func saveTemplates() {
        do {
            let encoded = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(encoded, forKey: storageKey)
            lastError = nil
        } catch {
            print("Failed to save templates: \(error)")
            lastError = "Failed to save templates. Changes may not persist."
        }
    }
    
    func deleteTemplate(_ template: TipTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }
}

// MARK: - HoursStore
final class HoursStore {
    static let shared = HoursStore()
    private init() {}
    private var hours: [UUID: Double] = [:]
    
    func set(id: UUID, hours value: Double?) {
        if let v = value, v >= 0 { hours[id] = v } else { hours.removeValue(forKey: id) }
    }
    
    func apply(to template: TipTemplate) -> TipTemplate {
        var copy = template
        copy.participants = copy.participants.map { p in
            var np = p
            if let h = hours[p.id] { np.hours = h }
            return np
        }
        return copy
    }
}

// MARK: - WhipCoins Manager
@MainActor final class WhipCoinsManager: ObservableObject {
    @Published var whipCoins: Int = 0
    private let storageKey = "whipCoinsBalance"

    init() {
        if let savedBalance = UserDefaults.standard.value(forKey: storageKey) as? Int {
            whipCoins = savedBalance
        }
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

        if template.rules.offTheTop?.isEmpty == false {
            total += 75
            breakdown.append(CreditsBreakdownItem(label: "Off-the-top bonuses", deltaWhipCoins: 75))
        }

        if template.rules.type == .hoursBased {
            total += 50
            breakdown.append(CreditsBreakdownItem(label: "Hours-based modifiers", deltaWhipCoins: 50))
        }

        let hasPercent = (template.rules.roleWeights?.isEmpty == false) || template.participants.contains { $0.weight != nil }
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

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    // Product configuration
    private let productId = "com.whiptip.pro.monthly"
    
    // Published state
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var product: Product?
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts = false
    @Published var hasFreeTrial = false
    @Published var trialDays = 3  // Default, will be overridden by StoreKit
    
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
    
    // MARK: - Product Loading
    
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
                    if let offer = subscription.introductoryOffer {
                        self.trialDays = Self.days(from: offer.period)
                    }
                }
                self.isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                self.purchaseError = "Could not load subscription options. Please try again later."
                self.isLoadingProducts = false
                print("Failed to load products: \(error)")
            }
        }
    }

    private static func days(from period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30 // approximation
        case .year: return period.value * 365 // approximation
        @unknown default: return period.value
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase() async {
        guard let product = product else {
            await MainActor.run {
                self.purchaseError = "Subscription product not available. Please try again."
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
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    await MainActor.run {
                        isPurchasing = false
                    }
                    
                case .unverified(_, let error):
                    await MainActor.run {
                        isPurchasing = false
                        purchaseError = "Verification failed: \(error.localizedDescription)"
                        print("Transaction verification failed: \(error)")
                    }
                }
                
            case .userCancelled:
                await MainActor.run {
                    isPurchasing = false
                }
                
            case .pending:
                await MainActor.run {
                    isPurchasing = false
                    subscriptionStatus = .pending
                    purchaseError = "Purchase is pending approval. You'll get access when it's approved."
                    print("Purchase is pending approval")
                }
                
            @unknown default:
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Unknown purchase result. Please try again."
                    print("Unknown purchase result")
                }
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                purchaseError = "Purchase failed: \(error.localizedDescription)"
                print("Purchase error: \(error)")
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
        }
        
        // Force sync with App Store
        try? await AppStore.sync()
        
        // Update subscription status
        await updateSubscriptionStatus()
        
        await MainActor.run {
            isPurchasing = false
            
            if !isSubscribed {
                purchaseError = "No active subscription found to restore."
            }
        }
    }
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var isInTrial = false
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == self.productId && 
                   !transaction.isRevoked && 
                   (transaction.expirationDate == nil || 
                    transaction.expirationDate! > Date()) {
                    
                    hasActiveSubscription = true
                    
                    // Check if this is a trial
                    if let expirationDate = transaction.expirationDate,
                       let purchaseDate = transaction.purchaseDate {
                        let trialThreshold = 8 // if less than 8 days between purchase and expiration
                        let daysBetween = Calendar.current.dateComponents([.day], from: purchaseDate, to: expirationDate).day ?? 0
                        isInTrial = daysBetween <= trialThreshold
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
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            // Listen for transaction updates
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Update subscription status when transactions change
                    await self?.updateSubscriptionStatus()
                    await transaction.finish()
                    
                case .unverified:
                    // Transaction was unverified, no action needed
                    break
                }
            }
        }
    }
}

// MARK: - Token Provider
protocol TokenProvider {
    func getToken() async throws -> String
}

// MARK: - Local Secrets Provider
final class LocalSecretsProvider: TokenProvider {
    private let tokenKey: String
    private let expiryKey: String?
    private let bundle: Bundle
    private var cached: (value: String, expiry: Date?)?
    private let headroom: TimeInterval = 30

    init(tokenKey: String = "DEEPSEEK_API_KEY", expiryKey: String? = nil, bundle: Bundle = .main) {
        self.tokenKey = tokenKey
        self.expiryKey = expiryKey
        self.bundle = bundle
    }

    func getToken() async throws -> String {
        if let cached, let expiry = cached.expiry {
            if expiry.timeIntervalSinceNow > headroom {
                return cached.value
            }
        } else if let cached { return cached.value }

        guard let path = bundle.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw TokenProviderError.missingSecrets
        }
        guard let token = (dict[tokenKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw TokenProviderError.emptyToken
        }
        var expiryDate: Date? = nil
        if let expiryKey, let raw = dict[expiryKey] {
            expiryDate = parseDate(raw)
        }
        if let expiryDate, expiryDate.timeIntervalSinceNow < headroom { throw TokenProviderError.expired }
        cached = (token, expiryDate)
        return token
    }

    private func parseDate(_ raw: Any) -> Date? {
        if let str = raw as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: str) { return date }
            if let interval = TimeInterval(str) { return Date(timeIntervalSince1970: interval) }
        } else if let interval = raw as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        } else if let number = raw as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        return nil
    }
}

// MARK: - Ephemeral Token Provider
final class EphemeralTokenProvider: TokenProvider {
    private let endpoint: URL
    private let session: URLSession
    private var cached: (value: String, expiry: Date?)?
    private let headroom: TimeInterval = 30
    
    private struct TokenResponse: Decodable {
        let token: String
        let expires: String?
        let expiresAt: Double?
    }

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func getToken() async throws -> String {
        if let cached, let expiry = cached.expiry, expiry.timeIntervalSinceNow > headroom { return cached.value }
        if let cached, cached.expiry == nil { return cached.value }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TokenProviderError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw TokenProviderError.backendUnavailable
            }
            
            let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard !payload.token.isEmpty else { throw TokenProviderError.emptyToken }
            
            // Parse expiration
            var expiry: Date? = nil
            if let expiresAt = payload.expiresAt {
                expiry = Date(timeIntervalSince1970: expiresAt)
            } else if let expiresStr = payload.expires {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: expiresStr) {
                    expiry = date
                } else if let timeInterval = TimeInterval(expiresStr) {
                    expiry = Date(timeIntervalSince1970: timeInterval)
                }
            }
            
            if let expiry, expiry.timeIntervalSinceNow < headroom { throw TokenProviderError.expired }
            cached = (payload.token, expiry)
            return payload.token
            
        } catch let error as TokenProviderError {
            throw error
        } catch let error as DecodingError {
            throw TokenProviderError.decodingFailure
        } catch {
            throw TokenProviderError.networkFailure(error.localizedDescription)
        }
    }
}

// MARK: - DeepSeek Chat Service
struct ChatMessage: Codable { let role: String; let content: String }
struct ChatRequest: Codable { let model: String; let messages: [ChatMessage]; let stream: Bool }

struct ChatChunkDelta: Decodable { let content: String?; let reasoning_content: String? }
struct ChatChunkChoice: Decodable { let delta: ChatChunkDelta }
struct ChatChunk: Decodable { let id: String; let choices: [ChatChunkChoice] }

actor DeepSeekChatService {
    enum StreamEvent { case token(String); case reasoning(String); case done; case error(Error) }

    private let tokenProvider: TokenProvider
    private let session: URLSession
    private let baseURL: URL

    init(tokenProvider: TokenProvider, baseURL: URL = URL(string: "https://api.deepseek.com/v1")!, session: URLSession = .shared) {
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
        self.session = session
    }

    func streamChat(userPrompt: String, systemPrompt: String? = nil, model: String = "deepseek-chat") -> AsyncStream<StreamEvent> {
        let requestURL = baseURL.appendingPathComponent("chat/completions")
        return AsyncStream { continuation in
            Task {
                do {
                    // Get the API token
                    let token = try await tokenProvider.getToken()
                    
                    // Prepare messages
                    var messages: [ChatMessage] = []
                    if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                        messages.append(ChatMessage(role: "system", content: systemPrompt))
                    }
                    messages.append(ChatMessage(role: "user", content: userPrompt))
                    
                    // Create request
                    let requestBody = ChatRequest(
                        model: model,
                        messages: messages,
                        stream: true
                    )
                    
                    // Encode request
                    let jsonData = try JSONEncoder().encode(requestBody)
                    
                    // Setup request
                    var request = URLRequest(url: requestURL)
                    request.httpMethod = "POST"
                    request.httpBody = jsonData
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    
                    // Make the request
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    // Check response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.yield(.error(AppError.api(.invalidResponse)))
                        continuation.finish()
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        continuation.yield(.error(AppError.api(.invalidResponse)))
                        continuation.finish()
                        return
                    }
                    
                    // Parse the stream
                    for try await line in bytes.lines {
                        guard !line.isEmpty else { continue }
                        
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.yield(.done)
                                continuation.finish()
                                break
                            }
                            
                            do {
                                let jsonData = jsonString.data(using: .utf8)!
                                let chunk = try JSONDecoder().decode(ChatChunk.self, from: jsonData)
                                
                                if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                                    continuation.yield(.token(content))
                                }
                                
                                if let reasoning = chunk.choices.first?.delta.reasoning_content, !reasoning.isEmpty {
                                    continuation.yield(.reasoning(reasoning))
                                }
                            } catch {
                                print("Error decoding chunk: \(error)")
                                // Continue processing other chunks even if one fails
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish()
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
    @Published var lastStatusMessage: String = "Idle"
    
    private let session: URLSession
    private let networkMonitor = NetworkMonitor()
    
    private var bundleAPIKey: String {
        Bundle.main.infoDictionary?["DEEPSEEK_API_KEY"] as? String ?? ""
    }
    private let overrideUDKey = "DeepSeekAPIKeyOverride"
    private let baseURL = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        session = URLSession(configuration: configuration)
        
        networkMonitor.objectWillChange.sink { [weak self] _ in
            if self?.networkMonitor.isConnected == false {
                self?.showOfflineAlert = true
            }
        }.store(in: &subscriptions)
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    // Effective API key resolution prioritizing Info.plist, then runtime overrides
    private var effectiveAPIKey: String {
        if let override = UserDefaults.standard.string(forKey: overrideUDKey),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let key = bundleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            DispatchQueue.main.async {
                self.showMissingKeyAlert = true
            }
        }
        
        return key
    }
    
    // Public helpers to manage override at runtime
    func setAPIKeyOverride(_ key: String) {
        UserDefaults.standard.set(key, forKey: overrideUDKey)
    }
    
    func clearAPIKeyOverride() {
        UserDefaults.standard.removeObject(forKey: overrideUDKey)
    }
    
    private func checkNetworkConnection() throws {
        if !networkMonitor.isConnected {
            throw AppError.network(.noInternetConnection)
        }
    }
    
    // Internal DTOs
    struct ChatMessageDTO: Codable { let role: String; let content: String }
    struct ChatRequestDTO: Codable { let model: String; let messages: [ChatMessageDTO]; let stream: Bool }
    struct ChatChoiceDTO: Codable { struct Message: Codable { let role: String; let content: String }; let message: Message }
    struct ChatResponseDTO: Codable { let choices: [ChatChoiceDTO] }

    enum StreamPiece { case token(String); case done }

    // Send a prompt to the API and get streaming response
    func streamChatCompletion(
        prompt: String,
        systemPrompt: String? = nil,
        model: String = "deepseek-chat"
    ) -> AsyncThrowingStream<StreamPiece, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try checkNetworkConnection()
                    
                    guard !effectiveAPIKey.isEmpty else {
                        throw AppError.authentication(.missingCredentials)
                    }
                    
                    var messages: [ChatMessageDTO] = []
                    if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                        messages.append(ChatMessageDTO(role: "system", content: systemPrompt))
                    }
                    messages.append(ChatMessageDTO(role: "user", content: prompt))
                    
                    let requestBody = ChatRequestDTO(
                        model: model,
                        messages: messages,
                        stream: true
                    )
                    
                    let jsonData = try JSONEncoder().encode(requestBody)
                    
                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.httpBody = jsonData
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(effectiveAPIKey)", forHTTPHeaderField: "Authorization")
                    
                    await MainActor.run { lastStatusMessage = "Connecting..." }
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AppError.api(.invalidResponse)
                    }
                    
                    switch httpResponse.statusCode {
                    case 200:
                        await MainActor.run { lastStatusMessage = "Receiving response..." }
                        
                        for try await line in bytes.lines {
                            if Task.isCancelled {
                                continuation.finish()
                                break
                            }
                            
                            guard !line.isEmpty else { continue }
                            
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                
                                if jsonString == "[DONE]" {
                                    continuation.yield(.done)
                                    break
                                }
                                
                                do {
                                    let data = jsonString.data(using: .utf8)!
                                    let decoder = JSONDecoder()
                                    let response = try decoder.decode(ChatChunk.self, from: data)
                                    
                                    if let content = response.choices.first?.delta.content, !content.isEmpty {
                                        continuation.yield(.token(content))
                                    }
                                } catch {
                                    print("Error parsing chat chunk: \(error)")
                                    // Continue to next line even if error
                                }
                            }
                        }
                        
                        await MainActor.run { lastStatusMessage = "Response complete" }
                        
                    case 401:
                        throw AppError.authentication(.unauthorized)
                    case 403:
                        throw AppError.authentication(.forbidden)
                    case 429:
                        throw AppError.authentication(.throttled)
                    case 500...599:
                        throw AppError.network(.serverError(httpResponse.statusCode))
                    default:
                        throw AppError.network(.networkError(httpResponse.statusCode))
                    }
                    
                } catch let apiError as AppError {
                    await MainActor.run { lastStatusMessage = "Error: \(apiError.title)" }
                    continuation.finish(throwing: apiError)
                } catch let error where error.isNetworkError {
                    await MainActor.run { lastStatusMessage = "Network error" }
                    continuation.finish(throwing: AppError.network(.networkError(0)))
                } catch {
                    await MainActor.run { lastStatusMessage = "Unknown error" }
                    continuation.finish(throwing: AppError.api(.unknown(error)))
                }
            }
        }
    }

    // Helper computed properties for view bindings
    var offlineAlertBinding: Binding<Bool> {
        Binding(
            get: { self.showOfflineAlert },
            set: { self.showOfflineAlert = $0 }
        )
    }
    
    var missingKeyAlertBinding: Binding<Bool> {
        Binding(
            get: { self.showMissingKeyAlert },
            set: { self.showMissingKeyAlert = $0 }
        )
    }

    // Generate a template based on natural language description
    func generateTemplate(from description: String, systemPrompt: String) async throws -> OnboardingResponse {
        try checkNetworkConnection()
        
        guard !effectiveAPIKey.isEmpty else {
            throw AppError.authentication(.missingCredentials)
        }
        
        let messages = [
            ChatMessageDTO(role: "system", content: systemPrompt),
            ChatMessageDTO(role: "user", content: description)
        ]
        
        let requestBody = ChatRequestDTO(
            model: "deepseek-chat",
            messages: messages,
            stream: false
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(effectiveAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.api(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponseDTO.self, from: data)
                guard let content = chatResponse.choices.first?.message.content else {
                    throw AppError.api(.invalidResponse)
                }
                
                do {
                    let jsonData = content.data(using: .utf8)!
                    let response = try JSONDecoder().decode(OnboardingResponse.self, from: jsonData)
                    return response
                } catch let error as DecodingError {
                    print("Failed to parse onboarding response: \(error)")
                    throw AppError.api(.decodingError(error))
                }
            } catch {
                throw AppError.api(.decodingError(error))
            }
            
        case 401:
            throw AppError.authentication(.unauthorized)
        case 403:
            throw AppError.authentication(.forbidden)
        case 429:
            throw AppError.authentication(.throttled)
        case 500...599:
            throw AppError.network(.serverError(httpResponse.statusCode))
        default:
            throw AppError.network(.networkError(httpResponse.statusCode))
        }
    }

    // Calculate splits for a template
    func calculateSplits(for template: TipTemplate, pool: Double) async throws -> CalculationResponse {
        // Local calculation for reliability
        let result = computeSplits(template: template, pool: pool)
        
        return CalculationResponse(
            splits: result.splits,
            summary: "Tip of $\(pool.currencyFormatted(currencyCode: "USD")) split among \(result.splits.count) participants.",
            warnings: result.warnings,
            visualizationHints: nil
        )
    }

    // Analyze or explain an existing calculation
    func explainCalculation(template: TipTemplate, pool: Double, splits: [Participant]) async throws -> String {
        try checkNetworkConnection()
        
        guard !effectiveAPIKey.isEmpty else {
            throw AppError.authentication(.missingCredentials)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let templateData = try encoder.encode(template)
        let templateJson = String(data: templateData, encoding: .utf8)!
        
        let splitsData = try encoder.encode(splits)
        let splitsJson = String(data: splitsData, encoding: .utf8)!
        
        let prompt = """
        Explain the following tip calculation in simple language:
        
        Total Tip Amount: $\(pool)
        
        Template:
        \(templateJson)
        
        Result:
        \(splitsJson)
        
        Explain how the calculation works, what rules were applied, and why each person received their amount.
        """
        
        let messages = [
            ChatMessageDTO(role: "system", content: "You are a helpful assistant that explains tip calculations."),
            ChatMessageDTO(role: "user", content: prompt)
        ]
        
        let requestBody = ChatRequestDTO(
            model: "deepseek-chat",
            messages: messages,
            stream: false
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(effectiveAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.api(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponseDTO.self, from: data)
                guard let content = chatResponse.choices.first?.message.content else {
                    throw AppError.api(.invalidResponse)
                }
                return content
            } catch {
                throw AppError.api(.decodingError(error))
            }
            
        case 401:
            throw AppError.authentication(.unauthorized)
        case 403:
            throw AppError.authentication(.forbidden)
        case 429:
            throw AppError.authentication(.throttled)
        case 500...599:
            throw AppError.network(.serverError(httpResponse.statusCode))
        default:
            throw AppError.network(.networkError(httpResponse.statusCode))
        }
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

// MARK: - App Entry Point

@main
struct WhipTipApp: App {
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var apiService = APIService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.templateManager, templateManager)
                .environment(\.subscriptionManager, subscriptionManager)
                .environment(\.apiService, apiService)
                .preferredColorScheme(.dark)
                .task {
                    await subscriptionManager.updateSubscriptionStatus()
                }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(\.templateManager) private var templateManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.apiService) private var apiService
    
    @State private var showOnboarding = false
    @State private var selectedTemplate: TipTemplate?
    
    var body: some View {
        NavigationView {
            contentView
        }
        .sheet(isPresented: apiService.missingKeyAlertBinding) {
            CredentialsView(isPresented: apiService.missingKeyAlertBinding)
        }
        .alert(
            "Internet Connection Required",
            isPresented: apiService.offlineAlertBinding
        ) {
            Button("OK") { }
        } message: {
            Text("WhipTip requires an internet connection for template creation and subscriptions. Tip calculations work offline once templates are saved.")
        }
        .overlay(alignment: .top) {
            if let toast = apiService.currentToast {
                ToastView(item: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .alert(item: Binding(get: { apiService.appError }, set: { _ in apiService.appError = nil })) { appError in
            Alert(
                title: Text(appError.title),
                message: Text(appError.message),
                primaryButton: .default(Text("OK"), action: appError.recoveryAction),
                secondaryButton: .cancel()
            )
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if templateManager.templates.isEmpty && !showOnboarding {
            WelcomeView(templateManager: templateManager, subscriptionManager: subscriptionManager)
                .onTapGesture {
                    showOnboarding = true
                }
        } else if showOnboarding {
            OnboardingFlowView(templateManager: templateManager, isPresented: $showOnboarding)
        } else {
            MainDashboardView(
                templateManager: templateManager,
                selectedTemplate: $selectedTemplate,
                showOnboarding: $showOnboarding
            )
        }
    }
}

// MARK: - Credentials View

struct CredentialsView: View {
    @Environment(\.apiService) private var apiService
    @State private var key: String = UserDefaults.standard.string(forKey: "DeepSeekAPIKeyOverride") ?? ""
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("DeepSeek API Key")) {
                    SecureField("sk-...", text: $key)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                Section(footer: Text("Your key is stored locally on-device and used only for DeepSeek API calls.")) {
                    Button("Save & Continue") {
                        apiService.setAPIKeyOverride(key)
                        isPresented = false
                    }
                    
                    if !(UserDefaults.standard.string(forKey: "DeepSeekAPIKeyOverride") ?? "").isEmpty {
                        Button("Clear Saved Key", role: .destructive) {
                            apiService.clearAPIKeyOverride()
                            key = ""
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("API Credentials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let item: APIService.ToastItem
    
    var bgColor: Color {
        switch item.kind { 
        case .info: return .blue.opacity(0.9)
        case .success: return .green.opacity(0.9)
        case .warning: return .orange.opacity(0.9)
        case .error: return .red.opacity(0.9) 
        }
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.message).font(.caption)
                }
                Spacer()
            }
            .padding(12)
            .background(bgColor)
            .cornerRadius(10)
            .shadow(radius: 6)
        }
        .padding(.horizontal)
    }
}

extension APIService {
    struct ToastItem: Identifiable {
        enum Kind { case info, success, warning, error }
        let id = UUID()
        let title: String
        let message: String
        let kind: Kind
        let duration: TimeInterval
    }
    
    @MainActor
    @Published var currentToast: ToastItem?
    @MainActor
    @Published var appError: AppError?
    
    @MainActor
    func showToast(title: String, message: String, kind: ToastItem.Kind = .info, duration: TimeInterval = 3.0) {
        currentToast = ToastItem(title: title, message: message, kind: kind, duration: duration)
        let dismissAfter = duration
        Task { 
            try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
            if self.currentToast?.title == title { 
                self.currentToast = nil 
            }
        }
    }
    
    @MainActor
    func presentError(_ error: AppError) {
        self.appError = error
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @Environment(\.apiService) private var apiService
    @Environment(\.subscriptionManager) private var subscriptionManager
    @State private var keyPrefix: String = ""
    @State private var isConnected: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics").font(.title.bold())
            
            GroupBox(label: Label("Environment", systemImage: "gearshape")) {
                VStack(alignment: .leading) {
                    Text("API Key Present: \(keyPrefix.isEmpty ? "No" : "Yes (\(keyPrefix)…)")")
                    Text("Subscription Active: \(subscriptionManager.isSubscribed ? "Yes" : "No")")
                    Text("Last API Status: \(apiService.lastStatusMessage)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            let k = (Bundle.main.infoDictionary?["DEEPSEEK_API_KEY"] as? String)?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
            keyPrefix = String(k.prefix(6))
        }
    }
}

#if DEBUG
struct DiagnosticsGestureModifier: ViewModifier {
    @State private var showDiag = false
    
    func body(content: Content) -> some View {
        content
            .overlay(Color.clear.contentShape(Rectangle())
                .onTapGesture(count: 3) { showDiag = true })
            .sheet(isPresented: $showDiag) { DiagnosticsView() }
    }
}

extension View {
    func enableDiagnostics() -> some View {
        modifier(DiagnosticsGestureModifier())
    }
}
#endif

// MARK: - Views

// MARK: - Common UI Components
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var showLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if showLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                }
                
                Text(title)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(isDisabled ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isDisabled || showLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .foregroundColor(isDisabled ? .gray : .blue)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isDisabled ? Color.gray : Color.blue, lineWidth: 1)
                )
        }
        .disabled(isDisabled)
    }
}

struct CircleProgressView: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.2)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct ParticipantRowView: View {
    var participant: Participant
    var onTap: () -> Void
    var showAmount: Bool = false
    
    var body: some View {
        HStack {
            Text(participant.emoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(participant.color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(participant.name)
                    .font(.headline)
                
                Text(participant.role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showAmount, let amount = participant.calculatedAmount {
                Text(amount, format: .currency(code: "USD"))
                    .fontWeight(.medium)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct AmountInputView: View {
    @Binding var amount: Double
    var placeholder: String
    
    var body: some View {
        HStack {
            Text("$")
                .font(.title)
                .foregroundColor(.primary)
            
            TextField(placeholder, value: $amount, format: .number)
                .font(.title)
                .keyboardType(.decimalPad)
                .keyboardDoneToolbar()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct InfoCard: View {
    let title: String
    let description: String
    let iconName: String
    var color: Color = .blue
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 50)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @ObservedObject var templateManager: TemplateManager
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var isShowingOnboarding = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                
                Text("Welcome to WhipTip")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("The smart way to split tips fairly among restaurant staff")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                if subscriptionManager.isSubscribed {
                    Text("Premium Subscription Active")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.bottom)
                } else if subscriptionManager.isPurchasing {
                    ProgressView("Processing subscription...")
                        .padding(.bottom)
                }
                
                VStack(spacing: 16) {
                    PrimaryButton(title: "Create New Tip Split") {
                        isShowingOnboarding = true
                    }
                    
                    NavigationLink(destination: TemplateListView(templateManager: templateManager)) {
                        Text("View Saved Templates")
                            .fontWeight(.medium)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    if !subscriptionManager.isSubscribed {
                        NavigationLink(destination: SubscriptionView(subscriptionManager: subscriptionManager)) {
                            Text("Upgrade to Premium")
                                .fontWeight(.medium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.yellow.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingOnboarding) {
                OnboardingFlowView(templateManager: templateManager, isPresented: $isShowingOnboarding)
            }
        }
    }
}

// MARK: - Onboarding Flow
struct OnboardingFlowView: View {
    @ObservedObject var templateManager: TemplateManager
    @ObservedObject var viewModel = OnboardingViewModel()
    @ObservedObject var apiService = APIService()
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isGenerating {
                    ProgressView("Creating your custom template...")
                        .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Describe your tip split scenario")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            Text("For example: \"I'm a server and we have 3 servers, 2 bussers, and 1 bartender. We pool tips and distribute based on hours worked, but bartenders get 15% off the top.\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $viewModel.userPrompt)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
                            if !viewModel.messages.isEmpty {
                                Text("Conversation")
                                    .font(.headline)
                                    .padding(.top)
                                
                                ForEach(viewModel.messages) { message in
                                    ConversationBubble(message: message)
                                }
                                
                                if let template = viewModel.generatedTemplate, !viewModel.isAskingForClarification {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Template Created:")
                                            .font(.headline)
                                            .padding(.top)
                                        
                                        Text(template.name)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        
                                        Text("With \(template.participants.count) participants")
                                            .foregroundColor(.secondary)
                                        
                                        Text("Rule: \(template.rules.type.rawValue.capitalized)")
                                            .foregroundColor(.secondary)
                                        
                                        PrimaryButton(title: "Use This Template") {
                                            templateManager.saveTemplate(template)
                                            isPresented = false
                                        }
                                        .padding(.top)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            if viewModel.isAskingForClarification {
                                Text("Clarification Needed")
                                    .font(.headline)
                                    .padding(.top)
                                
                                Text(viewModel.clarificationPrompt)
                                    .padding()
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)
                                
                                if let suggestedQuestions = viewModel.suggestedQuestions, !suggestedQuestions.isEmpty {
                                    Text("Suggested clarifications:")
                                        .font(.subheadline)
                                        .padding(.top, 4)
                                    
                                    ForEach(suggestedQuestions, id: \.self) { question in
                                        Button(action: {
                                            viewModel.userPrompt = question
                                        }) {
                                            Text(question)
                                                .font(.subheadline)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                
                                PrimaryButton(title: "Send Clarification") {
                                    viewModel.sendClarification(apiService: apiService)
                                }
                                .padding(.top)
                            }
                        }
                        .padding()
                    }
                    
                    if viewModel.generatedTemplate == nil && !viewModel.isAskingForClarification {
                        VStack {
                            Divider()
                            
                            HStack {
                                PrimaryButton(title: "Generate Template") {
                                    viewModel.generateTemplate(apiService: apiService)
                                }
                                .disabled(viewModel.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("New Tip Split")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
            .alert(item: $viewModel.error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: apiService.offlineAlertBinding) {
                Alert(
                    title: Text("No Internet Connection"),
                    message: Text("Please check your network connection and try again."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: apiService.missingKeyAlertBinding) {
                Alert(
                    title: Text("API Key Missing"),
                    message: Text("DeepSeek API key is not configured."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ConversationBubble: View {
    let message: ChatMessage
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "Assistant")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
            }
            
            if !isUser { Spacer() }
        }
        .padding(.vertical, 4)
    }
}

class OnboardingViewModel: ObservableObject {
    @Published var userPrompt = ""
    @Published var isGenerating = false
    @Published var generatedTemplate: TipTemplate?
    @Published var error: AppError?
    @Published var messages: [ChatMessage] = []
    @Published var isAskingForClarification = false
    @Published var clarificationPrompt = ""
    @Published var suggestedQuestions: [String]?
    
    let systemPrompt = """
    You are an AI assistant that helps users create fair tip splitting templates for restaurant staff.
    Generate a TipTemplate JSON object based on the user's input.
    If the input is unclear, ask for clarification.
    
    The template should include:
    1. A list of participants with roles and names
    2. Rules for how tips are split (equal, hours-based, percentage, role-weighted, hybrid)
    3. Any special distribution rules (like off-the-top percentages)
    
    Response format:
    {
      "status": "complete"|"needs_clarification"|"in_progress",
      "message": "Description of the template or clarification needed",
      "clarificationNeeded": true|false,
      "template": { TipTemplate object if complete },
      "suggestedQuestions": ["Question 1", "Question 2"] // if clarification needed
    }
    """
    
    func generateTemplate(apiService: APIService) {
        guard !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isGenerating = true
        isAskingForClarification = false
        let currentPrompt = userPrompt
        
        // Add user message to conversation
        messages.append(ChatMessage(role: "user", content: currentPrompt))
        
        Task {
            do {
                let response = try await apiService.generateTemplate(from: currentPrompt, systemPrompt: systemPrompt)
                
                await MainActor.run {
                    switch response.status {
                    case .complete:
                        if let template = response.template {
                            self.generatedTemplate = template
                            self.messages.append(ChatMessage(role: "assistant", content: response.message))
                        } else {
                            self.error = AppError.general(title: "Template Error", message: "Received success response but no template data")
                        }
                    case .needsClarification:
                        self.isAskingForClarification = true
                        self.clarificationPrompt = response.message
                        self.suggestedQuestions = response.suggestedQuestions
                        self.messages.append(ChatMessage(role: "assistant", content: response.message))
                    case .inProgress, .error:
                        self.error = AppError.general(title: "Processing Error", message: response.message)
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    if let appError = error as? AppError {
                        self.error = appError
                    } else {
                        self.error = AppError.general(title: "Error", message: error.localizedDescription)
                    }
                    self.isGenerating = false
                }
            }
        }
    }
    
    func sendClarification(apiService: APIService) {
        guard !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isGenerating = true
        let clarificationText = userPrompt
        
        // Add clarification to conversation
        messages.append(ChatMessage(role: "user", content: clarificationText))
        
        Task {
            do {
                let response = try await apiService.generateTemplate(from: clarificationText, systemPrompt: systemPrompt)
                
                await MainActor.run {
                    switch response.status {
                    case .complete:
                        if let template = response.template {
                            self.generatedTemplate = template
                            self.isAskingForClarification = false
                            self.messages.append(ChatMessage(role: "assistant", content: response.message))
                        } else {
                            self.error = AppError.general(title: "Template Error", message: "Received success response but no template data")
                        }
                    case .needsClarification:
                        self.isAskingForClarification = true
                        self.clarificationPrompt = response.message
                        self.suggestedQuestions = response.suggestedQuestions
                        self.messages.append(ChatMessage(role: "assistant", content: response.message))
                    case .inProgress, .error:
                        self.error = AppError.general(title: "Processing Error", message: response.message)
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    if let appError = error as? AppError {
                        self.error = appError
                    } else {
                        self.error = AppError.general(title: "Error", message: error.localizedDescription)
                    }
                    self.isGenerating = false
                }
            }
        }
    }
}

// MARK: - Template List View
struct TemplateListView: View {
    @ObservedObject var templateManager: TemplateManager
    @State private var showingNewTemplateSheet = false
    
    var body: some View {
        List {
            ForEach(templateManager.templates) { template in
                NavigationLink(destination: TemplateDetailView(template: template, templateManager: templateManager)) {
                    VStack(alignment: .leading) {
                        Text(template.name)
                            .font(.headline)
                        
                        HStack {
                            Text("\(template.participants.count) participants")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(template.rules.type.rawValue.capitalized)
                                .font(.subheadline)
                                .padding(4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteTemplates)
        }
        .navigationTitle("Saved Templates")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingNewTemplateSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTemplateSheet) {
            OnboardingFlowView(templateManager: templateManager, isPresented: $showingNewTemplateSheet)
        }
    }
    
    func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            templateManager.deleteTemplate(templateManager.templates[index])
        }
    }
}

// MARK: - Template Detail View
struct TemplateDetailView: View {
    let template: TipTemplate
    @ObservedObject var templateManager: TemplateManager
    @State private var tipAmount: Double = 100.00
    @State private var calculationResult: CalculationResponse?
    @State private var isCalculating = false
    @State private var showingExplanation = false
    @State private var explanation: String = ""
    @State private var isExplaining = false
    @State private var error: AppError?
    @ObservedObject var apiService = APIService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tip Amount Input
                VStack(alignment: .leading) {
                    Text("Total Tip Amount")
                        .font(.headline)
                    
                    AmountInputView(amount: $tipAmount, placeholder: "Enter tip amount")
                }
                
                // Participants List
                VStack(alignment: .leading) {
                    Text("Participants")
                        .font(.headline)
                    
                    ForEach(template.participants) { participant in
                        ParticipantRowView(
                            participant: participant,
                            onTap: {},
                            showAmount: calculationResult != nil
                        )
                        .padding(.vertical, 4)
                    }
                }
                
                // Calculate Button
                PrimaryButton(title: "Calculate Split", action: calculateSplit)
                    .padding(.vertical)
                
                // Results Section
                if let result = calculationResult {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                        
                        Text(result.summary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if let warnings = result.warnings, !warnings.isEmpty {
                            ForEach(warnings, id: \.self) { warning in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.yellow)
                                    
                                    Text(warning)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Button(action: {
                            getExplanation()
                        }) {
                            HStack {
                                Text("Explain This Split")
                                
                                if isExplaining {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "questionmark.circle")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .disabled(isExplaining)
                    }
                    .padding(.vertical)
                }
            }
            .padding()
            .navigationTitle(template.name)
            .alert(item: $error) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingExplanation) {
                ExplanationView(explanation: explanation)
            }
        }
    }
    
    func calculateSplit() {
        isCalculating = true
        
        Task {
            do {
                let result = try await apiService.calculateSplits(for: template, pool: tipAmount)
                await MainActor.run {
                    calculationResult = result
                    isCalculating = false
                }
            } catch {
                await MainActor.run {
                    isCalculating = false
                    if let appError = error as? AppError {
                        self.error = appError
                    } else {
                        self.error = AppError.general(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func getExplanation() {
        guard let result = calculationResult else { return }
        isExplaining = true
        
        Task {
            do {
                let explanation = try await apiService.explainCalculation(
                    template: template,
                    pool: tipAmount,
                    splits: result.splits
                )
                
                await MainActor.run {
                    self.explanation = explanation
                    self.isExplaining = false
                    self.showingExplanation = true
                }
            } catch {
                await MainActor.run {
                    isExplaining = false
                    if let appError = error as? AppError {
                        self.error = appError
                    } else {
                        self.error = AppError.general(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }
}

struct ExplanationView: View {
    let explanation: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(explanation)
                    .padding()
            }
            .navigationTitle("Split Explanation")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Participant Hours Input View
struct ParticipantHoursInputView: View {
    let participants: [Participant]
    @ObservedObject private var hoursStore = HoursStore.shared
    
    var body: some View {
        List {
            ForEach(participants) { participant in
                HStack {
                    Text(participant.emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(participant.color.opacity(0.2))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(participant.name)
                            .font(.headline)
                        Text(participant.role)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HoursPicker(participant: participant)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Enter Hours")
    }
    
    struct HoursPicker: View {
        let participant: Participant
        @State private var hours: Double
        
        init(participant: Participant) {
            self.participant = participant
            self._hours = State(initialValue: participant.hours ?? 0)
        }
        
        var body: some View {
            HStack {
                Stepper(value: $hours, in: 0...24, step: 0.5) {
                    Text("\(hours, specifier: "%.1f") hrs")
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .onChange(of: hours) { newValue in
                HoursStore.shared.set(id: participant.id, hours: newValue)
            }
        }
    }
}

// MARK: - Calculation Results View
struct CalculationResultView: View {
    let tipAmount: Double
    let result: SplitResult
    let template: TipTemplate
    @State private var showingShareOptions = false
    @State private var shareText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tip Split Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("$\(tipAmount, specifier: "%.2f") split among \(result.splits.count) participants")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Participants results
                ForEach(result.splits) { participant in
                    HStack {
                        Text(participant.emoji)
                            .font(.title)
                            .frame(width: 50, height: 50)
                            .background(participant.color.opacity(0.2))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(participant.name)
                                .font(.headline)
                            
                            Text(participant.role)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(participant.calculatedAmount ?? 0, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // Warning messages if any
                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warnings")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(result.warnings, id: \.self) { warning in
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                
                                Text(warning)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Share button
                Button(action: {
                    shareText = buildCSV(for: result)
                    showingShareOptions = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Results")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle(template.name)
        .sheet(isPresented: $showingShareOptions) {
            ActivityViewController(activityItems: [shareText])
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Subscription View
struct SubscriptionView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .padding(.bottom)
                    
                    Text("WhipTip Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlock advanced features")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
                
                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(iconName: "person.3.fill", title: "Unlimited participants", description: "Add as many staff members as needed")
                    
                    FeatureRow(iconName: "function", title: "Advanced algorithms", description: "Complex calculations based on roles and hours")
                    
                    FeatureRow(iconName: "square.and.pencil", title: "Custom rule creation", description: "Create your own custom tip splitting rules")
                    
                    FeatureRow(iconName: "chart.pie.fill", title: "Detailed analytics", description: "Visualize your splits with advanced charts")
                    
                    FeatureRow(iconName: "icloud.and.arrow.up.fill", title: "Cloud backup", description: "Save your templates securely in the cloud")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Pricing
                VStack(spacing: 8) {
                    if let product = subscriptionManager.product {
                        Text(product.displayPrice)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("per month")
                            .foregroundColor(.secondary)
                        
                        if subscriptionManager.hasFreeTrial {
                            Text("\(subscriptionManager.trialDays)-day free trial")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                        }
                    } else {
                        Text("Loading price...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Subscribe button
                Button(action: {
                    Task {
                        await subscriptionManager.purchase()
                    }
                }) {
                    HStack {
                        if subscriptionManager.isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        }
                        
                        Text(subscriptionManager.hasFreeTrial ? "Start Free Trial" : "Subscribe")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(subscriptionManager.isPurchasing || subscriptionManager.product == nil)
                
                // Restore button
                Button(action: {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }) {
                    Text("Restore Purchases")
                        .foregroundColor(.blue)
                }
                .padding()
                .disabled(subscriptionManager.isPurchasing)
                
                if let error = subscriptionManager.purchaseError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                // Terms and privacy
                Text("Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. You can manage subscriptions in your App Store account settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
        .navigationTitle("Premium Subscription")
    }
    
    struct FeatureRow: View {
        let iconName: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}
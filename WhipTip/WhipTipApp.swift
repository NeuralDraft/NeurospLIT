// WhipTipApp.swift
// Monolithic Single-File Build - StoreKit 2 Integration
// CLEANED

import SwiftUI
import Combine
import Network
import UIKit
import StoreKit  // Added for StoreKit 2
// Monolithic build: core engine is inlined; no external WhipCore import

// CLEANED: Logic from Utilities/Color+Hex.swift now merged into monolith.
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

// MARK: - Unified Currency Formatting (Top-level extension)
extension Double {
    /// Reusable (main‑thread) currency formatter cache.
    /// NumberFormatter isn't thread-safe; access only from main/UI contexts.
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
    /// Localized currency string for the current locale, with optional override for `currencyCode`.
    func currencyFormatted(locale: Locale = .current, currencyCode: String? = nil) -> String {
        if !Thread.isMainThread { // Defensive: create a throwaway formatter off main thread
            let temp = NumberFormatter(); temp.numberStyle = .currency; temp.locale = locale; if let code = currencyCode { temp.currencyCode = code }
            return temp.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
        }
        let formatter = Self.formatter(locale: locale, currencyCode: currencyCode)
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
}

// MARK: - Core Models + Engine (Inlined - Monolithic)
// CLEANED: Logic from Models/DomainModels.swift now merged into monolith.

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

struct OffTheTopRule: Codable { var role: String; var percentage: Double }
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
}

struct SplitResult { var splits: [Participant]; var warnings: [String] }

// MARK: - Core Errors (inlined)
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

// MARK: - Core Engine (inlined)
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

// MARK: Allocation helpers (all amounts in cents)
// Disable legacy in-file engine implementation (now using WhipCore)
#if false
fileprivate func _allocateOffTheTop(participants: [Participant], poolCents: Int, rules: [OffTheTopRule]?) -> (perID: [UUID:Int], remainder: Int, warnings: [String]) {
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
    if totalAllocated > poolCents { // clamp overflow
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

fileprivate func _allocateByRule(participants:[Participant], remainderCents:Int, rules: TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    guard remainderCents > 0 else { return ([:], []) }
    switch rules.type {
    case .equal: return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .equal)
    case .percentage: return _allocatePercentage(participants: participants, remainderCents: remainderCents, rules: rules)
    case .hoursBased: return _allocateHours(participants: participants, remainderCents: remainderCents)
    case .roleWeighted: return _allocateRoleWeighted(participants: participants, remainderCents: remainderCents, rules: rules)
    case .hybrid: return _allocateHybrid(participants: participants, remainderCents: remainderCents, rules: rules)
    }
}

fileprivate func _allocateEqual(participants:[Participant], remainderCents:Int, ruleType: TipRules.RuleType) -> (perID:[UUID:Int], warnings:[String]) {
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

fileprivate func _allocatePercentage(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
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

fileprivate func _allocateHours(participants:[Participant], remainderCents:Int) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    var hourMap:[UUID:Double]=[:]
    for p in participants { hourMap[p.id]=max(0,p.hours ?? 0) }
    let totalHours = hourMap.values.reduce(0,+)
    if totalHours <= 0 { warnings.append("Total hours were zero; fell back to equal split."); return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hoursBased) }
    var raw:[UUID:Double]=[:]
    for (id,h) in hourMap { raw[id] = Double(remainderCents) * (h/totalHours) }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .hours)
    return (rounded, warnings)
}

fileprivate func _allocateRoleWeighted(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    guard let roleWeights = rules.roleWeights, !roleWeights.isEmpty else { warnings.append("No roleWeights provided for roleWeighted; fell back to equal."); return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted) }
    let lower = roleWeights.reduce(into:[String:Double]()) { $0[$1.key.lowercased()] = max(0,$1.value) }
    var validTotal = 0.0
    for (role,w) in lower where w > 0 { if participants.contains(where:{ $0.role.lowercased()==role }) { validTotal += w } }
    if validTotal <= 0 { warnings.append("All role weights invalid; fell back to equal."); return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted) }
    if abs(validTotal - 100) > weightNormalizationEpsilon {
        warnings.append("Role weights did not sum to 100; normalized.")
    }
    var raw:[UUID:Double]=[:]
    for (role,w) in lower where w > 0 {
        let members = participants.filter { $0.role.lowercased()==role }
        if members.isEmpty { continue }
        let roleShare = Double(remainderCents) * (w/validTotal)
        let each = roleShare / Double(members.count)
        for m in members { raw[m.id, default:0]+=each }
    }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .roleWeighted)
    return (rounded, warnings)
}

fileprivate func _allocateHybrid(participants:[Participant], remainderCents:Int, rules:TipRules) -> (perID:[UUID:Int], warnings:[String]) {
    var warnings:[String]=[]
    let parsed = _parseHybridFormula(rules.formula)
    if parsed.isEmpty { warnings.append("Hybrid formula empty or invalid; fell back to equal."); return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hybrid) }
    var valid:[(String,Double,[Participant])] = []
    var totalPctValid = 0.0
    for (role,pct) in parsed {
        let members = participants.filter { $0.role.lowercased()==role }
        if members.isEmpty { warnings.append("Hybrid role \(role) has no participants"); continue }
        if pct > 0 { valid.append((role,pct,members)); totalPctValid += pct }
    }
    if totalPctValid <= 0 { warnings.append("Hybrid formula produced no valid roles; fell back to equal."); return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hybrid) }
    if abs(totalPctValid - 100) > weightNormalizationEpsilon {
        warnings.append("Hybrid role percentages did not sum to 100; normalized.")
    }
    var raw:[UUID:Double]=[:]
    for (_,pct,members) in valid {
        let roleShare = Double(remainderCents) * (pct/totalPctValid)
        let each = roleShare / Double(members.count)
        for m in members { raw[m.id, default:0]+=each }
    }
    let (rounded, _) = _finalizeRounding(raw: raw, targetTotal: remainderCents, participants: participants, context: .hybrid)
    return (rounded, warnings)
}

fileprivate func _parseHybridFormula(_ formula:String) -> [(String,Double)] {
    formula.split(separator: ",").compactMap { pair in
        let parts = pair.split(separator: ":"); guard parts.count == 2 else { return nil }
        let role = parts[0].trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        let pct = Double(parts[1].trimmingCharacters(in:.whitespacesAndNewlines)) ?? 0
        return (role,pct)
    }
}

// MARK: Rounding helpers
fileprivate func _finalizeRounding(raw:[UUID:Double], targetTotal:Int, participants:[Participant], context:_RoundingContext) -> ([UUID:Int],[UUID:Double]) {
    if raw.isEmpty { return ([:],[:]) }
    var scaled = raw
    let rawSum = raw.values.reduce(0,+)
    if rawSum <= 0 { return ([:],[:]) }
    let scale = Double(targetTotal)/rawSum
    for (k,v) in raw { scaled[k] = v*scale }
    var base:[UUID:Int]=[:]; var rema:[UUID:Double]=[:]; var floorSum=0
    for (id,val) in scaled { let f = Int(val); base[id]=f; floorSum+=f; rema[id]=val-Double(f) }
    let remaining = targetTotal - floorSum
    if remaining > 0 {
        let ordered = _orderForPennyDistribution(ids:Array(raw.keys), remainders: rema, participants: participants, context: context)
        for i in 0..<remaining { base[ordered[i], default:0]+=1 }
    }
    return (base, rema)
}

fileprivate func _combineAndFixPennies(offTop:[UUID:Int], main:[UUID:Int], targetTotal:Int, participants:[Participant]) -> [UUID:Int] {
    var combined = offTop
    for (k,v) in main { combined[k, default:0]+=v }
    let sum = combined.values.reduce(0,+)
    if sum == targetTotal { return combined }
    var delta = targetTotal - sum
    if delta == 0 { return combined }
    let ordered = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }.map { $0.id }
    if delta > 0 {
        for id in ordered where delta > 0 { combined[id, default:0]+=1; delta -= 1 }
    } else {
        for id in ordered.reversed() where delta < 0 { if let cur = combined[id], cur > 0 { combined[id]=cur-1; delta += 1 } }
    }
    return combined
}

fileprivate func _orderForPennyDistribution(ids:[UUID], remainders:[UUID:Double], participants:[Participant], context:_RoundingContext) -> [UUID] {
    let map = Dictionary(uniqueKeysWithValues: participants.map { ($0.id,$0) })
    let eps = 1e-9
    func tie(_ a:Participant,_ b:Participant) -> Bool {
        switch context {
        case .offTop, .equal: if a.name.lowercased() != b.name.lowercased() { return a.name.lowercased() < b.name.lowercased() }; return a.id.uuidString < b.id.uuidString
        case .hours: let ha=a.hours ?? 0, hb=b.hours ?? 0; if abs(ha-hb) > eps { return ha > hb }; if a.name.lowercased() != b.name.lowercased() { return a.name.lowercased() < b.name.lowercased() }; return a.id.uuidString < b.id.uuidString
        case .percentage, .roleWeighted, .hybrid: let wa=a.weight ?? 0, wb=b.weight ?? 0; if abs(wa-wb) > eps { return wa > wb }; if a.name.lowercased() != b.name.lowercased() { return a.name.lowercased() < b.name.lowercased() }; return a.id.uuidString < b.id.uuidString
        }
    }
    return ids.sorted { l,r in
        let r1 = remainders[l] ?? 0, r2 = remainders[r] ?? 0
        if abs(r1-r2) > eps { return r1 > r2 }
        guard let pa = map[l], let pb = map[r] else { return l.uuidString < r.uuidString }
        return tie(pa,pb)
    }
}
#endif

// MARK: - Minimal Helpers Reintroduced (previously from core)
// CLEANED: Logic from Utilities/TemplateUtilities.swift now merged into monolith.
func formatTemplateJSON(_ template: TipTemplate) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(template), let json = String(data: data, encoding: .utf8) else {
        return "Unable to display template data"
    }
    return json
}

// Lightweight CSV builder stub (replaces prior csvw variable usage)
fileprivate func _csvEscape(_ v: String) -> String {
    if v.contains(",") || v.contains("\n") || v.contains("\"") { return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    return v
}
func buildCSV(for result: SplitResult) -> String {
    var rows: [String] = ["Name,Role,Amount"]
    for p in result.splits { let amt = (p.calculatedAmount ?? 0).currencyFormatted(); rows.append("\(_csvEscape(p.name)),\(_csvEscape(p.role)),\(_csvEscape(amt))") }
    return rows.joined(separator: "\n")
}

// Legacy tuple wrapper for tests expecting (splits:warnings)
func computeSplitsCompat(template: TipTemplate, pool: Double) -> (splits: [Participant], warnings: [String]) {
    let r = computeSplits(template: template, pool: pool)
    return (r.splits, r.warnings)
}


struct OnboardingResponse: Codable {
    var status: ResponseStatus
    var message: String
    var clarificationNeeded: Bool
    var template: TipTemplate?
    var suggestedQuestions: [String]?
    
    enum ResponseStatus: String, Codable { case inProgress = "in_progress", needsClarification = "needs_clarification", complete = "complete", error = "error" }
}

struct CalculationResponse: Codable { var splits: [Participant]; var summary: String; var warnings: [String]?; var visualizationHints: [String: String]? }

// CLEANED: MockProduct migrated from Models/DomainModels.swift.
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

// MARK: - [Previous Errors section remains unchanged]
// CLEANED: Logic from Models/Errors.swift now merged into monolith.

enum APIError: LocalizedError {
    case invalidURL
    case noInternetConnection
    case requestTimeout
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    case unknown(Error)
    case networkError(Int)
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API endpoint"
        case .noInternetConnection: return "Internet connection required. Please check your connection."
        case .requestTimeout: return "Request timed out. Please try again."
        case .invalidResponse: return "Received invalid response from server"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let code): return "Server error (HTTP \(code))"
        case .networkError(let code): return "Network error (HTTP \(code))"
        case .unknown(let error): return "An unexpected error occurred: \(error.localizedDescription)"
        case .missingCredentials: return "DeepSeek API key missing. Add DEEPSEEK_API_KEY to Info.plist."
        }
    }
}

enum TokenProviderError: LocalizedError {
    case missingSecrets
    case missingToken
    case invalidResponse
    case backendUnavailable
    case emptyToken
    case expired
    case networkFailure(String)
    case decodingFailure

    var errorDescription: String? {
        switch self {
        case .missingSecrets: return "Secrets.plist not found or API_TOKEN missing."
        case .missingToken: return "Token provider returned no value."
        case .invalidResponse: return "Invalid token response."
        case .backendUnavailable: return "Token backend unavailable."
        case .emptyToken: return "Empty token returned."
        case .expired: return "Token expired."
        case .networkFailure(let message): return "Token network failure: \(message)"
        case .decodingFailure: return "Unable to decode token response."
        }
    }
}

// CLEANED: Logic from Services/TokenProvider.swift now merged into monolith.
protocol TokenProvider {
    func getToken() async throws -> String
}

extension Error { var isNetworkError: Bool { let ns = self as NSError; return ns.domain == NSURLErrorDomain || ns.domain == NSPOSIXErrorDomain } }

// MARK: - Network Monitor utilities
// CLEANED: Logic from Utilities/NetworkMonitor.swift now merged into monolith.
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

// MARK: - Fairness-Aware Tip Split Engine (monolith)
// CLEANED

// MARK: - Template Manager [remains unchanged]

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

// MARK: - HoursStore (for persisting ad-hoc hours input without restructuring value types)
// This lightweight store allows hour inputs to survive view refreshes and be applied at calculation time.
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

// CLEANED: WhipCoins module - Manager + result types
@MainActor final class WhipCoinsManager: ObservableObject { // CLEANED
    @Published var whipCoins: Int = 0 // CLEANED
    private let storageKey = "whipCoinsBalance" // CLEANED

    init() { // CLEANED
        if let savedBalance = UserDefaults.standard.value(forKey: storageKey) as? Int { // CLEANED
            whipCoins = savedBalance // CLEANED
        } // CLEANED
    } // CLEANED

    func consumeWhipCoins(_ amount: Int) -> Bool { // CLEANED
        guard whipCoins >= amount else { return false } // CLEANED
        whipCoins -= amount // CLEANED
        saveBalance() // CLEANED
        return true // CLEANED
    } // CLEANED

    func addWhipCoins(_ amount: Int) { // CLEANED
        whipCoins += amount // CLEANED
        saveBalance() // CLEANED
    } // CLEANED

    private func saveBalance() { // CLEANED
        UserDefaults.standard.set(whipCoins, forKey: storageKey) // CLEANED
    } // CLEANED
} // CLEANED

struct CreditsResult { // CLEANED
    var whipCoins: Int // CLEANED
    var breakdown: [CreditsBreakdownItem] // CLEANED
    var policyVersion: String // CLEANED
    var seed: String // CLEANED
} // CLEANED

struct CreditsBreakdownItem { // CLEANED
    var label: String // CLEANED
    var deltaWhipCoins: Int // CLEANED
} // CLEANED

struct PricingMeta { // CLEANED
    var instructionText: String? // CLEANED
    var seed: String? // CLEANED
} // CLEANED

enum PricingPolicy { // CLEANED
    static func calculateWhipCoins(template: TipTemplate, meta: PricingMeta? = nil) -> CreditsResult { // CLEANED
        var total = 200 // CLEANED
        var breakdown: [CreditsBreakdownItem] = [ // CLEANED
            CreditsBreakdownItem(label: "Base", deltaWhipCoins: 200) // CLEANED
        ] // CLEANED

        let roleCount = template.participants.count // CLEANED
        if (2...3).contains(roleCount) { // CLEANED
            total += 50 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Roles 2–3", deltaWhipCoins: 50)) // CLEANED
        } else if (4...6).contains(roleCount) { // CLEANED
            total += 100 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Roles 4–6", deltaWhipCoins: 100)) // CLEANED
        } else if roleCount >= 7 { // CLEANED
            total += 150 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Roles 7+", deltaWhipCoins: 150)) // CLEANED
        } // CLEANED

        if template.rules.offTheTop?.isEmpty == false { // CLEANED
            total += 75 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Off-the-top bonuses", deltaWhipCoins: 75)) // CLEANED
        } // CLEANED

        if template.rules.type == .hoursBased { // CLEANED
            total += 50 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Hours-based modifiers", deltaWhipCoins: 50)) // CLEANED
        } // CLEANED

        let hasPercent = (template.rules.roleWeights?.isEmpty == false) || template.participants.contains { $0.weight != nil } // CLEANED
        let hasPerPerson = template.participants.contains { $0.hours != nil } // CLEANED
        if hasPercent && hasPerPerson { // CLEANED
            total += 80 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Hybrid rules", deltaWhipCoins: 80)) // CLEANED
        } // CLEANED

        if let custom = template.rules.customLogic, !custom.isEmpty { // CLEANED
            total += 100 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Nested logic", deltaWhipCoins: 100)) // CLEANED
        } // CLEANED

        let instructionSource = meta?.instructionText ?? template.rules.customLogic ?? template.rules.formula // CLEANED
        let tokenCount = instructionSource.split(whereSeparator: { $0.isWhitespace }).count // CLEANED
        if tokenCount > 300 { // CLEANED
            total += 40 // CLEANED
            breakdown.append(CreditsBreakdownItem(label: "Long instructions", deltaWhipCoins: 40)) // CLEANED
        } // CLEANED

        total = max(200, min(2000, total)) // CLEANED

        return CreditsResult( // CLEANED
            whipCoins: total, // CLEANED
            breakdown: breakdown, // CLEANED
            policyVersion: "WC-1.0", // CLEANED
            seed: meta?.seed ?? UUID().uuidString // CLEANED
        ) // CLEANED
    } // CLEANED
} // CLEANED

// MARK: - StoreKit 2 Subscription Manager (REPLACING MOCK)

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
                    if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial {
                        // Map period units to approximate days for consistent status messaging
                        self.trialDays = Self.days(from: intro.period)
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
                    // Unlock premium content
                    await updateSubscriptionStatus()
                    
                    // Always finish transactions
                    await transaction.finish()
                    
                    await MainActor.run {
                        self.isPurchasing = false
                    }
                    
                case .unverified(_, let error):
                    // Handle unverified transaction
                    await MainActor.run {
                        self.purchaseError = "Could not verify purchase. Please contact support."
                        self.isPurchasing = false
                        print("Transaction verification failed: \(error)")
                    }
                }
                
            case .userCancelled:
                // User cancelled the purchase
                await MainActor.run {
                    self.isPurchasing = false
                }
                
            case .pending:
                // Purchase is pending (e.g., waiting for parental approval)
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
                purchaseError = "No active subscription found."
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
                if transaction.productID == productId {
                    hasActiveSubscription = true
                    
                    // Check if in trial period
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        // Check if this is a trial transaction
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
            
            // TODO: Check for referral-based trial extension here
            // if referralManager.hasActiveBonus() { isSubscribed = true }
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Never> {
        // [fix] Avoid retain cycle: capture self weakly in detached task
        return Task.detached { [weak self] in
            // Listen for transaction updates
            for await result in Transaction.updates {
                guard let self else { continue }
                switch result {
                case .verified(let transaction):
                    // Update subscription status when transactions change
                    await self.updateSubscriptionStatus()
                    
                    // Always finish transactions
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    print("Unverified transaction update: \(error)")
                }
            }
        }
    }
}

// MARK: - Streaming Chat Service & Token Providers
// CLEANED: Logic from Services/APIService.swift now merged into monolith.

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
                    let token = try await tokenProvider.getToken()
                    var messages: [ChatMessage] = []
                    if let systemPrompt { messages.append(ChatMessage(role: "system", content: systemPrompt)) }
                    messages.append(ChatMessage(role: "user", content: userPrompt))
                    let body = ChatRequest(model: model, messages: messages, stream: true)
                    var request = URLRequest(url: requestURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(body)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                        throw APIError.networkError((response as? HTTPURLResponse)?.statusCode ?? -1)
                    }
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonPart = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                            if jsonPart == "[DONE]" { continuation.yield(.done); break }
                            if let data = jsonPart.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(ChatChunk.self, from: data)
                                    if let delta = chunk.choices.first?.delta {
                                        if let reasoning = delta.reasoning_content, !reasoning.isEmpty { continuation.yield(.reasoning(reasoning)) }
                                        if let tokenText = delta.content, !tokenText.isEmpty { continuation.yield(.token(tokenText)) }
                                    }
                                } catch {
                                    // ignore malformed chunk
                                }
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

// CLEANED: Logic from Services/LocalSecretsProvider.swift now merged into monolith.
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
            if expiry.timeIntervalSinceNow < headroom { throw TokenProviderError.expired }
            return cached.value
        } else if let cached { return cached.value }

        guard let path = bundle.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw TokenProviderError.missingSecrets
        }
        guard let token = (dict[tokenKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw TokenProviderError.missingToken
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
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: str) { return date }
            if let interval = TimeInterval(str) { return Date(timeIntervalSince1970: interval) }
        } else if let interval = raw as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        } else if let number = raw as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        return nil
    }
}

// CLEANED: Logic from Services/EphemeralTokenProvider.swift now merged into monolith.
final class EphemeralTokenProvider: TokenProvider {
    private let endpoint: URL
    private let session: URLSession
    private var cached: (value: String, expiry: Date?)?
    private let headroom: TimeInterval = 30

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func getToken() async throws -> String {
    if let cached, let expiry = cached.expiry, expiry.timeIntervalSinceNow > headroom { return cached.value }
    if let cached, cached.expiry == nil { return cached.value }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw TokenProviderError.networkFailure("Status code \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        struct Payload: Decodable { let token: String; let expiresAt: String? }
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw TokenProviderError.decodingFailure
        }
        guard !payload.token.isEmpty else { throw TokenProviderError.emptyToken }
        var expiry: Date? = nil
        if let raw = payload.expiresAt {
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: raw) { expiry = date }
            else if let interval = TimeInterval(raw) { expiry = Date(timeIntervalSince1970: interval) }
        }
    if let expiry, expiry.timeIntervalSinceNow < headroom { throw TokenProviderError.expired }
    cached = (payload.token, expiry)
        return payload.token
    }
}

// MARK: - [API Service]

@MainActor
class APIService: ObservableObject {
    @Published var showOfflineAlert = false
    @Published var showMissingKeyAlert = false
    @Published var lastStatusMessage: String = "Idle"
    
    private let session: URLSession
    private let networkMonitor = NetworkMonitor()
    // CLEANED
    private var bundleAPIKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String) ?? ""
    }
    private let overrideUDKey = "DeepSeekAPIKeyOverride"
    private let baseURL = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        #if DEBUG
        let bundleKey = bundleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let overrideKey = (UserDefaults.standard.string(forKey: overrideUDKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let effective = effectiveAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[APIService] Bundle key present? \(!bundleKey.isEmpty). Override present? \(!overrideKey.isEmpty). Effective present? \(!effective.isEmpty). Bundle: \(Bundle.main.bundleIdentifier ?? "(nil)")")
        #endif
    }
    
    // Effective API key resolution prioritizing UserDefaults override, then Info.plist
    // CLEANED
    private var effectiveAPIKey: String {
        if let override = UserDefaults.standard.string(forKey: overrideUDKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return override
        }
        let plistKey = bundleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plistKey.isEmpty {
            return plistKey
        }
        return ""
    }
    
    // Public helpers to manage override at runtime
    func setAPIKeyOverride(_ key: String) {
        UserDefaults.standard.set(key, forKey: overrideUDKey)
    }
    func clearAPIKeyOverride() {
        UserDefaults.standard.removeObject(forKey: overrideUDKey)
    }
    
    private func checkNetworkConnection() throws {
        guard networkMonitor.isConnected else {
            showOfflineAlert = true
            throw APIError.noInternetConnection
        }
    }
    
    // Internal DTOs
    struct ChatMessageDTO: Codable { let role: String; let content: String }
    struct ChatRequestDTO: Codable { let model: String; let messages: [ChatMessageDTO]; let stream: Bool }
    struct ChatChoiceDTO: Codable { struct Message: Codable { let role: String; let content: String }; let message: Message }
    struct ChatResponseDTO: Codable { let choices: [ChatChoiceDTO] }

    enum StreamPiece { case token(String); case done }

    /// Unified non-stream request returning full content
    private func performChat(model: String, messages: [ChatMessageDTO]) async throws -> String {
        lastStatusMessage = "Sending..."
        do {
            try checkNetworkConnection()
            let key = effectiveAPIKey
            if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showMissingKeyAlert = true
                throw APIError.missingCredentials
            }
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let body = ChatRequestDTO(model: model, messages: messages, stream: false)
            request.httpBody = try JSONEncoder().encode(body)
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugVerboseAPILogging") {
                let userCount = messages.filter { $0.role == "user" }.count
                print("[DEBUG] DeepSeek request: model=\(model), stream=false, messages=\(messages.count), userMsgs=\(userCount)")
            }
            #endif
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                lastStatusMessage = "HTTP \(http.statusCode)"
                guard 200..<300 ~= http.statusCode else { throw APIError.serverError(http.statusCode) }
            } else {
                lastStatusMessage = "Success"
            }
            let decoded = try JSONDecoder().decode(ChatResponseDTO.self, from: data)
            guard let content = decoded.choices.first?.message.content else { throw APIError.invalidResponse }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugVerboseAPILogging") {
                let preview = String(content.prefix(120))
                print("[DEBUG] DeepSeek response (first 120 chars): \(preview)")
            }
            #endif
            return content
        } catch {
            lastStatusMessage = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    /// Streaming request emitting partial tokens (SSE style)
    func streamChat(model: String, messages: [ChatMessageDTO]) async throws -> AsyncStream<StreamPiece> {
        lastStatusMessage = "Sending..."
        do {
            try checkNetworkConnection()
            let key = effectiveAPIKey
            if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showMissingKeyAlert = true
                throw APIError.missingCredentials
            }
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let body = ChatRequestDTO(model: model, messages: messages, stream: true)
            request.httpBody = try JSONEncoder().encode(body)
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugVerboseAPILogging") {
                let userCount = messages.filter { $0.role == "user" }.count
                print("[DEBUG] DeepSeek streaming request: model=\(model), stream=true, messages=\(messages.count), userMsgs=\(userCount)")
            }
            #endif
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse {
                lastStatusMessage = "HTTP \(http.statusCode)"
                guard 200..<300 ~= http.statusCode else { throw APIError.serverError(http.statusCode) }
            } else {
                lastStatusMessage = "Success"
            }
            return AsyncStream { continuation in
                let task = Task {
                    do {
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }
                            if line.hasPrefix("data: ") {
                                let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if payload == "[DONE]" {
                                    await MainActor.run { self.lastStatusMessage = "Success" }
                                    continuation.yield(.done)
                                    break
                                }
                                guard let data = payload.data(using: .utf8) else { continue }
                                if let chunk = try? JSONDecoder().decode(ChatResponseDTO.self, from: data),
                                   let token = chunk.choices.first?.message.content, !token.isEmpty {
                                    continuation.yield(.token(token))
                                }
                            }
                        }
                        await MainActor.run { self.lastStatusMessage = "Success" }
                        continuation.finish()
                    } catch {
                        await MainActor.run { self.lastStatusMessage = "Error: \(error.localizedDescription)" }
                        if !Task.isCancelled { continuation.finish() }
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            lastStatusMessage = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    func sendOnboardingMessage(
        userInput: String,
        sessionId: String,
        turnNumber: Int,
        useReasoning: Bool = false,
        streaming: Bool = false
    ) async throws -> OnboardingResponse {
        let systemPrompt = "You are WhipTip's onboarding assistant. Collect restaurant tip splitting rules succinctly." + (useReasoning ? " Focus on step-by-step reasoning then produce a concise final answer." : "")
        let model = useReasoning ? "deepseek-reasoner" : "deepseek-chat"
        let messages = [
            ChatMessageDTO(role: "system", content: systemPrompt),
            ChatMessageDTO(role: "user", content: userInput)
        ]
        var content: String = ""
        if streaming {
            // Accumulate streamed tokens
            let stream = try await streamChat(model: model, messages: messages)
            for await piece in stream {
                switch piece {
                case .token(let t): content += t
                case .done: break
                }
            }
            if content.isEmpty { content = "(No content received)" }
        } else {
            do {
                content = try await performChat(model: model, messages: messages).trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                if error.isNetworkError == false { throw error }
                content = "Let me help you set up your rules." // fallback
            }
        }
        return OnboardingResponse(
            status: turnNumber < 5 ? .inProgress : .complete,
            message: content,
            clarificationNeeded: turnNumber < 5,
            template: turnNumber >= 5 ? createSampleTemplate() : nil,
            suggestedQuestions: turnNumber < 5 ? ["We pool everything", "Each person keeps their own"] : nil
        )
    }
    
    func sendWithRetry(
        userInput: String,
        sessionId: String,
        turnNumber: Int,
        maxRetries: Int = 3,
        initialDelay: Double = 1.0
    ) async throws -> OnboardingResponse {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await sendOnboardingMessage(
                    userInput: userInput,
                    sessionId: sessionId,
                    turnNumber: turnNumber
                )
            } catch {
                lastError = error
                if !error.isNetworkError {
                    throw error
                }
                let delay = initialDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? APIError.requestTimeout
    }
    
    func calculateSplit(
        template: TipTemplate,
        tipPool: Double
    ) async throws -> CalculationResponse {
        // Allow offline calculations
        let result = computeSplits(template: template, pool: tipPool)
        
        return CalculationResponse(
            splits: result.splits,
            summary: "Split based on \(template.rules.type.rawValue)",
            warnings: result.warnings.isEmpty ? nil : result.warnings,
            visualizationHints: nil
        )
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
                accentColor: "purple",
                showPercentages: true,
                showComparison: true
            )
        )
    }
}

// MARK: - [Environment Keys remain the same]

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

// MARK: - Main App [updated to use real subscription manager]

@main
struct WhipTipApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var apiService = APIService()
    @StateObject private var whipCoinsManager = WhipCoinsManager() // CLEANED
    
    #if DEBUG
    @State private var showDebugInfoAlert: Bool = false
    @State private var debugInfoMessage: String = ""
    #endif
    
    #if DEBUG
    init() {
        let key = (Bundle.main.infoDictionary?["DEEPSEEK_API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let showAlertPref = (UserDefaults.standard.object(forKey: "DebugShowAPIKeyAlert") as? Bool) ?? true
        if !key.isEmpty {
            let prefix = String(key.prefix(6))
            print("✅ DeepSeek key found: \(prefix)…")
            // Initialize alert state for Debug builds
            self._debugInfoMessage = State(initialValue: "✅ DeepSeek key found: \(prefix)…")
            // Show once if enabled in Debug settings
            self._showDebugInfoAlert = State(initialValue: showAlertPref)
        } else {
            print("❌ DeepSeek key missing from Info.plist")
            // Initialize alert state for Debug builds
            self._debugInfoMessage = State(initialValue: "❌ DeepSeek key missing from Info.plist")
            // Show once if enabled in Debug settings
            self._showDebugInfoAlert = State(initialValue: showAlertPref)
        }
        // If we decided to show at launch, flip the flag off so it won't reappear until reset
        if showDebugInfoAlert { UserDefaults.standard.set(false, forKey: "DebugShowAPIKeyAlert") }
    }
    #endif
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.templateManager, templateManager)
                .environment(\.subscriptionManager, subscriptionManager)
                .environment(\.apiService, apiService)
                .environmentObject(whipCoinsManager) // CLEANED
                .preferredColorScheme(.dark)
                .task {
                    // Update subscription status on launch
                    await subscriptionManager.updateSubscriptionStatus()
                }
                .modifier(DiagnosticsGestureModifier())
                #if DEBUG
                .alert(
                    "Debug Info",
                    isPresented: $showDebugInfoAlert
                ) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(debugInfoMessage)
                }
                #endif
        }
    }
}

// MARK: - Diagnostics Panel
struct DiagnosticsView: View {
    @Environment(\.apiService) private var api
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager // CLEANED
    @Environment(\.subscriptionManager) private var subs
    @State private var keyPrefix: String = ""
    @State private var isConnected: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics").font(.title.bold())
            GroupBox(label: Label("Environment", systemImage: "gearshape")) {
                VStack(alignment: .leading) {
                    Text("API Key Present: \(keyPrefix.isEmpty ? "No" : "Yes (\(keyPrefix)…)")")
                    Text("Subscription Active: \(subs.isSubscribed ? "Yes" : "No")")
                    Text("WhipCoins Balance: \(whipCoinsManager.whipCoins)") // CLEANED
                    Text("Last API Status: \(api.lastStatusMessage)")
                }.frame(maxWidth: .infinity, alignment: .leading)
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

private struct DiagnosticsGestureModifier: ViewModifier {
    @State private var showDiag = false
    func body(content: Content) -> some View {
        content
            .overlay(Color.clear.contentShape(Rectangle())
                .onTapGesture(count: 3) { showDiag = true })
            .sheet(isPresented: $showDiag) { DiagnosticsView() }
    }
}

// MARK: - [Root View remains unchanged]

struct RootView: View {
    @Environment(\.templateManager) private var templateManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.apiService) private var apiService
    
    @State private var showOnboarding = false
    @State private var selectedTemplate: TipTemplate?
    @State private var showWhipCoins = false // CLEANED
    #if DEBUG
    @State private var showDebugDashboard = false
    #endif
    
    var body: some View {
        NavigationView {
            contentView
        }
    .sheet(isPresented: $showWhipCoins) { WhipCoinsView(showWhipCoins: $showWhipCoins) } // CLEANED
        .sheet(isPresented: missingKeyBinding) {
            CredentialsView(isPresented: missingKeyBinding)
        }
        // [fix]: Use computed Binding property offlineAlertBinding
        .alert(
            "Internet Connection Required",
            isPresented: offlineAlertBinding
        ) {
            Button("OK") { }
        } message: {
            Text("WhipTip requires an internet connection for setup and calculations. Please check your connection and try again.")
        }
        #if DEBUG
        .sheet(isPresented: $showDebugDashboard) {
            DebugDashboardView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDebugDashboard)) { _ in
            showDebugDashboard = true
        }
        #endif
    }

    // [fix]: Centralized binding accessor for apiService.showOfflineAlert
    private var offlineAlertBinding: Binding<Bool> {
        Binding(
            get: { apiService.showOfflineAlert },
            set: { apiService.showOfflineAlert = $0 }
        )
    }
    
    // Binding for missing API key sheet
    private var missingKeyBinding: Binding<Bool> {
        Binding(
            get: { apiService.showMissingKeyAlert },
            set: { apiService.showMissingKeyAlert = $0 }
        )
    }
    
    @ViewBuilder
    private var contentView: some View {
        if templateManager.templates.isEmpty && !showOnboarding {
            WelcomeView(showOnboarding: $showOnboarding)
        } else if showOnboarding {
            OnboardingFlowView(showOnboarding: $showOnboarding, showWhipCoins: $showWhipCoins) // CLEANED
        } else {
            MainDashboardView(
                selectedTemplate: $selectedTemplate,
                showOnboarding: $showOnboarding,
                showWhipCoins: $showWhipCoins // CLEANED
            )
        }
    }
}

#if DEBUG
extension Notification.Name {
    static let openDebugDashboard = Notification.Name("OpenDebugDashboard")
}
#endif

// Simple credentials prompt to enter runtime API key override
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
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
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

// MARK: - [All UI Views remain unchanged except SubscriptionView]
// [Welcome, Onboarding, MainDashboard, etc. views remain the same]

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
            Text("Welcome to WhipTip")
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
            Text("Top up WhipCoins anytime to collect new templates when you're ready.") // CLEANED
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center) // CLEANED
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

// MARK: - [Onboarding Flow and other views remain unchanged]
// [Keep all existing OnboardingFlowView, OnboardingViewModel, ConversationBubble, etc.]

struct OnboardingFlowView: View {
    @Binding var showOnboarding: Bool
    @Binding var showWhipCoins: Bool // CLEANED
    @Environment(\.apiService) private var apiService
    @Environment(\.templateManager) private var templateManager
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager // CLEANED
    
    @StateObject private var onboardingVM = OnboardingViewModel()
    @State private var userInput = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRawJSON = false
    @State private var showPricingReveal = false // CLEANED
    @State private var currentCreditsResult: CreditsResult? // CLEANED
    
    var body: some View {
        VStack(spacing: 0) {
            progressBar
            
            if onboardingVM.isConfirming {
                confirmationView
            } else {
                conversationView
                inputSection
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Try Again") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPricingReveal) {
            if let result = currentCreditsResult, let template = onboardingVM.finalTemplate {
                PricingRevealView(
                    creditsResult: result,
                    template: template,
                    onCollected: { finishOnboarding() },
                    onNeedWhipCoins: { handleWhipCoinsTopUp() }
                )
            }
        }
        .onAppear {
            if whipCoinsManager.whipCoins == 0 {
                showWhipCoins = true
            }
        }
    }
    
    private var progressBar: some View {
        ProgressView(value: Double(onboardingVM.turnNumber), total: 10)
            .tint(.purple)
            .padding()
    }
    
    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                confirmationHeader
                templateSummaryView
                technicalDetailsButton
                
                if showRawJSON, let template = onboardingVM.finalTemplate {
                    jsonPreview(template: template)
                }
                
                confirmationActions
            }
            .padding()
        }
    }
    
    private var confirmationHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Review Your Template")
                .font(.title.bold())
            
            Text("Here's what I understood from our conversation:")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
    
    private var templateSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(
                onboardingVM.templateSummary.components(separatedBy: "\n"),
                id: \.self
            ) { line in
                formatSummaryLine(line)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    @ViewBuilder
    private func formatSummaryLine(_ line: String) -> some View {
        if line.starts(with: "**") {
            Text(line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: ":", with: "")
            )
            .font(.headline)
            .foregroundColor(.white)
        } else if line.starts(with: "  •") {
            HStack(alignment: .top) {
                Text("•")
                    .foregroundColor(.purple)
                
                Text(line.replacingOccurrences(of: "  • ", with: ""))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        } else if !line.isEmpty {
            Text(line)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var technicalDetailsButton: some View {
        Button(action: { showRawJSON.toggle() }) {
            Label(
                showRawJSON ? "Hide Technical Details" : "View Technical Details",
                systemImage: showRawJSON ? "chevron.up" : "chevron.down"
            )
            .font(.caption)
            .foregroundColor(.gray)
        }
    }

    private func presentPricing() { // CLEANED
        guard let template = onboardingVM.finalTemplate else { return } // CLEANED
        onboardingVM.confirmTemplate() // CLEANED
        let meta = PricingMeta( // CLEANED
            instructionText: onboardingVM.templateSummary, // CLEANED
            seed: UUID().uuidString // CLEANED
        ) // CLEANED
        currentCreditsResult = PricingPolicy.calculateWhipCoins( // CLEANED
            template: template, // CLEANED
            meta: meta // CLEANED
        ) // CLEANED
        showPricingReveal = true // CLEANED
    } // CLEANED

    private func handleWhipCoinsTopUp() { // CLEANED
        showPricingReveal = false // CLEANED
        showWhipCoins = true // CLEANED
    } // CLEANED
    
    private func jsonPreview(template: TipTemplate) -> some View {
        ScrollView(.horizontal) {
            Text(formatTemplateJSON(template))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .padding()
                .background(Color.black)
                .cornerRadius(8)
        }
        .frame(maxHeight: 200)
    }
    
    private var confirmationActions: some View {
        VStack(spacing: 12) {
            Button(action: {
                presentPricing()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Yes, that's correct")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            
            Button(action: { onboardingVM.editTemplate() }) {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text("No, something needs to change")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                )
            }
            
            Button("Cancel Setup") {
                showOnboarding = false
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    conversationHistory
                    
                    if !onboardingVM.currentAIMessage.isEmpty {
                        ConversationBubble(
                            text: onboardingVM.currentAIMessage,
                            isUser: false,
                            timestamp: Date()
                        )
                        .id("current")
                    }
                    
                    if !onboardingVM.suggestedQuestions.isEmpty {
                        suggestedQuestionsView
                    }
                    
                    if isProcessing {
                        loadingIndicator
                    }
                }
                .padding()
                // [fix]: iOS 16/17 compatibility for onChange
                Group {
                    if #available(iOS 17.0, *) {
                        // iOS17+ two-parameter variant
                        EmptyView()
                            .onChange(of: onboardingVM.conversationHistory.count) { _, _ in
                                withAnimation {
                                    proxy.scrollTo("current", anchor: .bottom)
                                }
                            }
                    } else {
                        // iOS16 fallback original single-value variant (safe, not deprecated there)
                        EmptyView()
                            .onChange(of: onboardingVM.conversationHistory.count) { _ in
                                withAnimation {
                                    proxy.scrollTo("current", anchor: .bottom)
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var conversationHistory: some View {
        ForEach(
            Array(onboardingVM.conversationHistory.enumerated()),
            id: \.offset
        ) { index, turn in
            ConversationBubble(
                text: turn.text,
                isUser: turn.isUser,
                timestamp: turn.timestamp
            )
            .id(index)
        }
    }
    
    private var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick answers:")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(onboardingVM.suggestedQuestions, id: \.self) { question in
                Button(action: {
                    userInput = question
                    submitInput()
                }) {
                    Text(question)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(20)
                }
            }
        }
        .padding()
    }
    
    private var loadingIndicator: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Thinking...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                voiceInputButton
                textInput
                sendButton
            }
            
            HStack {
                Button("Cancel") {
                    showOnboarding = false
                }
                .foregroundColor(.gray)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private var voiceInputButton: some View {
        Button(action: startVoiceInput) {
            Image(systemName: onboardingVM.isRecording ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(onboardingVM.isRecording ? Color.red : Color.purple)
                )
        }
        .disabled(true) // Voice input not implemented
    }
    
    private var textInput: some View {
        TextField("Type your answer...", text: $userInput)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onSubmit {
                submitInput()
            }
    }
    
    private var sendButton: some View {
        Button(action: submitInput) {
            if isProcessing {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(.purple)
            }
        }
        .disabled(userInput.isEmpty || isProcessing)
    }
    
    private func startVoiceInput() {
        onboardingVM.toggleRecording()
    }
    
    private func submitInput() {
        guard !userInput.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let response = try await apiService.sendWithRetry(
                    userInput: userInput,
                    sessionId: onboardingVM.sessionId,
                    turnNumber: onboardingVM.turnNumber
                )
                
                await MainActor.run {
                    onboardingVM.processResponse(response)
                    userInput = ""
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func finishOnboarding() { // CLEANED
        guard let template = onboardingVM.finalTemplate else { return } // CLEANED
        templateManager.saveTemplate(template) // CLEANED
        currentCreditsResult = nil // CLEANED
        showPricingReveal = false // CLEANED
        showOnboarding = false // CLEANED
    } // CLEANED
}

// MARK: - [OnboardingViewModel and other supporting views remain unchanged]

class OnboardingViewModel: ObservableObject {
    @Published var conversationHistory: [ConversationTurn] = []
    @Published var currentAIMessage = "Hi! I'll help you set up your tip splitting rules. First, tell me: How does your team typically split tips?"
    @Published var suggestedQuestions: [String] = [
        "We pool everything",
        "Everyone keeps their own",
        "It depends on the shift"
    ]
    @Published var isRecording = false
    @Published var canFinish = false
    @Published var finalTemplate: TipTemplate?
    @Published var isConfirming = false
    @Published var templateSummary = ""
    
    let sessionId = UUID().uuidString
    var turnNumber = 0
    
    struct ConversationTurn {
        let text: String
        let isUser: Bool
        let timestamp: Date
    }
    
    func processResponse(_ response: OnboardingResponse) {
        if !currentAIMessage.isEmpty {
            conversationHistory.append(
                ConversationTurn(
                    text: currentAIMessage,
                    isUser: false,
                    timestamp: Date()
                )
            )
        }
        
        currentAIMessage = response.message
        suggestedQuestions = response.suggestedQuestions ?? []
        
        if response.status == .complete, let template = response.template {
            finalTemplate = template
            templateSummary = generateTemplateSummary(template: template)
            isConfirming = true
            currentAIMessage = ""
            suggestedQuestions = []
        }
        
        turnNumber += 1
    }
    
    func confirmTemplate() {
        canFinish = true
    }
    
    func editTemplate() {
        isConfirming = false
        currentAIMessage = "What would you like to change about these rules?"
        suggestedQuestions = [
            "Change the percentages",
            "Modify the roles",
            "Different calculation method"
        ]
    }
    
    func toggleRecording() {
        isRecording.toggle()
    }
    
    private func generateTemplateSummary(template: TipTemplate) -> String {
        var lines: [String] = []
        
        lines.append("📋 **Template Name:** \(template.name)\n")
        lines.append("🎯 **Split Method:** \(formatRuleType(template.rules.type))\n")
        
        if !template.participants.isEmpty {
            lines.append("👥 **Team Members:**")
            for participant in template.participants {
                var description = "  • \(participant.emoji) \(participant.name) - \(participant.role)"
                if let weight = participant.weight {
                    description += " (\(Int(weight))%)"
                }
                lines.append(description)
            }
            lines.append("")
        }
        
        if let weights = template.rules.roleWeights, !weights.isEmpty {
            lines.append("⚖️ **Role Distribution:**")
            for (role, weight) in weights.sorted(by: { $0.value > $1.value }) {
                lines.append("  • \(role.capitalized): \(Int(weight))%")
            }
            lines.append("")
        }
        
        if let offTheTop = template.rules.offTheTop, !offTheTop.isEmpty {
            lines.append("💸 **Off-The-Top Deductions:**")
            for item in offTheTop {
                lines.append("  • \(item.role.capitalized) gets \(Int(item.percentage))% first")
            }
            lines.append("")
        }
        
        if !template.rules.formula.isEmpty {
            lines.append("🔢 **Formula:** \(template.rules.formula)\n")
        }
        
        lines.append("📊 **Display Style:** \(template.displayConfig.primaryVisualization.capitalized) chart")
        if template.displayConfig.showPercentages {
            lines.append("  • Shows percentages")
        }
        if template.displayConfig.showComparison {
            lines.append("  • Includes comparison mode")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatRuleType(_ type: TipRules.RuleType) -> String {
        switch type {
        case .hoursBased:
            return "Hours-based (tips split by hours worked)"
        case .percentage:
            return "Fixed percentages for each role"
        case .equal:
            return "Equal split among all team members"
        case .roleWeighted:
            return "Weighted by role importance"
        case .hybrid:
            return "Hybrid calculation with custom rules"
        }
    }
}

struct ConversationBubble: View {
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding()
                    .background(bubbleBackground)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 280)
            
            if !isUser { Spacer() }
        }
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - [MainDashboard and other views remain unchanged]

struct MainDashboardView: View {
    @Binding var selectedTemplate: TipTemplate?
    @Binding var showOnboarding: Bool
    @Binding var showWhipCoins: Bool // CLEANED
    
    @Environment(\.templateManager) private var templateManager
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager // CLEANED
    
    @State private var showTemplateList = false
    @State private var tipAmount = ""
    @State private var showCalculation = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if let template = selectedTemplate {
                templateContent(template: template)
            } else {
                emptyStateView
            }
        }
        .sheet(isPresented: $showTemplateList) {
            TemplateListView(selectedTemplate: $selectedTemplate)
        }
        .sheet(isPresented: $showCalculation) {
            if let template = selectedTemplate {
                CalculationResultView(
                    template: template,
                    tipAmount: Double(tipAmount) ?? 0
                )
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("WhipTip")
                    .font(.title.bold())
                    #if DEBUG
                    .onTapGesture(count: 3) {
                        NotificationCenter.default.post(name: .openDebugDashboard, object: nil)
                    }
                    #endif
                
                if let template = selectedTemplate {
                    Text(template.name)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: { showTemplateList = true }) {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
            }
            
            Button(action: { showWhipCoins = true }) { // CLEANED
                HStack(spacing: 6) { // CLEANED
                    Image(systemName: "ticket") // CLEANED
                    Text("\(whipCoinsManager.whipCoins)") // CLEANED
                } // CLEANED
                .font(.headline) // CLEANED
                .padding(8) // CLEANED
                .background(Color.white.opacity(0.08)) // CLEANED
                .cornerRadius(12) // CLEANED
            } // CLEANED
        }
        .padding()
    }
    
    private func templateContent(template: TipTemplate) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                tipInputSection
                
                if template.rules.type == .hoursBased {
                    ParticipantHoursInputView(template: template)
                }
                
                calculateButton
            }
            .padding()
        }
    }
    
    private var tipInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tonight's Tips", systemImage: "dollarsign.circle.fill")
                .font(.headline)
            
            TextField("Enter amount", text: $tipAmount)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var calculateButton: some View {
        Button(action: {
            let amount = Double(tipAmount) ?? 0
            if amount < 0 { return }
            showCalculation = true
        }) {
            Label("Calculate Split", systemImage: "chart.pie.fill")
                .font(.headline)
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
        .disabled(tipAmount.isEmpty || (Double(tipAmount) ?? 0) < 0)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Select a Template")
                .font(.title2.bold())
            
            Text("Choose an existing template or create a new one")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Button(action: { showTemplateList = true }) {
                    Label("Browse Templates", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(12)
                }
                
                Button(action: { // CLEANED
                    if whipCoinsManager.whipCoins > 0 { // CLEANED
                        showOnboarding = true // CLEANED
                    } else { // CLEANED
                        showWhipCoins = true // CLEANED
                    } // CLEANED
                }) { // CLEANED
                    Label("Create New Template", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct WhipCoinsView: View { // CLEANED
    @EnvironmentObject var whipCoinsManager: WhipCoinsManager // CLEANED
    @Binding var showWhipCoins: Bool // CLEANED

    @State private var products: [Product] = [] // CLEANED
    @State private var isLoading = true // CLEANED
    @State private var errorMessage: String? // CLEANED

    private let productIDs = [ // CLEANED
        "com.whiptip.starter", // CLEANED
        "com.whiptip.standard", // CLEANED
        "com.whiptip.pro" // CLEANED
    ] // CLEANED

    var body: some View { // CLEANED
        VStack(spacing: 20) { // CLEANED
            Text("Top Up Your WhipCoins! ⚡") // CLEANED
                .font(.largeTitle).bold() // CLEANED

            if isLoading { // CLEANED
                ProgressView() // CLEANED
            } else if let error = errorMessage { // CLEANED
                Text(error).foregroundColor(.red) // CLEANED
            } else { // CLEANED
                ForEach(products) { product in // CLEANED
                    Button(action: { purchase(product) }) { // CLEANED
                        VStack { // CLEANED
                            Text(product.displayName) // CLEANED
                            Text(product.displayPrice) // CLEANED
                            Text(getCreditsDescription(for: product)) // CLEANED
                                .font(.subheadline) // CLEANED
                        } // CLEANED
                        .frame(maxWidth: .infinity) // CLEANED
                        .padding() // CLEANED
                        .background(Color.blue) // CLEANED
                        .foregroundColor(.white) // CLEANED
                        .cornerRadius(10) // CLEANED
                    } // CLEANED
                } // CLEANED
            } // CLEANED

            Button("Close") { // CLEANED
                showWhipCoins = false // CLEANED
            } // CLEANED
        } // CLEANED
        .padding() // CLEANED
        .onAppear(perform: loadProducts) // CLEANED
    } // CLEANED

    private func loadProducts() { // CLEANED
        Task { // CLEANED
            do { // CLEANED
                let fetched = try await Product.products(for: productIDs) // CLEANED
                await MainActor.run { // CLEANED
                    products = fetched // CLEANED
                    isLoading = false // CLEANED
                } // CLEANED
            } catch { // CLEANED
                await MainActor.run { // CLEANED
                    errorMessage = "Failed to load products: \(error.localizedDescription)" // CLEANED
                    isLoading = false // CLEANED
                } // CLEANED
            } // CLEANED
        } // CLEANED
    } // CLEANED

    private func purchase(_ product: Product) { // CLEANED
        Task { // CLEANED
            do { // CLEANED
                let result = try await product.purchase() // CLEANED
                switch result { // CLEANED
                case .success(let verification): // CLEANED
                    if case .verified(let transaction) = verification { // CLEANED
                        let coins = getCreditsAmount(for: product) // CLEANED
                        await MainActor.run { whipCoinsManager.addWhipCoins(coins) } // CLEANED
                        await transaction.finish() // CLEANED
                        await MainActor.run { showWhipCoins = false } // CLEANED
                    } // CLEANED
                default: break // CLEANED
                } // CLEANED
            } catch { // CLEANED
                await MainActor.run { // CLEANED
                    errorMessage = "Purchase failed: \(error.localizedDescription)" // CLEANED
                } // CLEANED
            } // CLEANED
        } // CLEANED
    } // CLEANED

    private func getCreditsAmount(for product: Product) -> Int { // CLEANED
        switch product.id { // CLEANED
        case "com.whiptip.starter": return 500 // CLEANED
        case "com.whiptip.standard": return 1100 // CLEANED
        case "com.whiptip.pro": return 2400 // CLEANED
        default: return 0 // CLEANED
        } // CLEANED
    } // CLEANED

    private func getCreditsDescription(for product: Product) -> String { // CLEANED
        "\(getCreditsAmount(for: product)) WhipCoins" // CLEANED
    } // CLEANED
} // CLEANED

struct PricingRevealView: View { // CLEANED
    let creditsResult: CreditsResult // CLEANED
    let template: TipTemplate // CLEANED
    let onCollected: () -> Void // CLEANED
    let onNeedWhipCoins: () -> Void // CLEANED

    @Environment(\.dismiss) private var dismiss // CLEANED
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager // CLEANED

    @State private var revealedItems: [Int] = [] // CLEANED
    @State private var showFinalPrice = false // CLEANED
    @State private var currentIndex = 0 // CLEANED

    var body: some View { // CLEANED
        VStack(spacing: 20) { // CLEANED
            Text("Analyzing your rules…") // CLEANED
                .font(.headline) // CLEANED
                .padding() // CLEANED

            ForEach(creditsResult.breakdown.indices, id: \.self) { index in // CLEANED
                if revealedItems.contains(index) { // CLEANED
                    let item = creditsResult.breakdown[index] // CLEANED
                    let sign = item.deltaWhipCoins > 0 ? "+" : (item.deltaWhipCoins < 0 ? "-" : "") // CLEANED
                    let absDelta = abs(item.deltaWhipCoins) // CLEANED
                    Text("\(item.label): \(sign)\(absDelta) WhipCoins") // CLEANED
                        .font(.body) // CLEANED
                        .transition(.opacity.combined(with: .slide)) // CLEANED
                } // CLEANED
            } // CLEANED

            if showFinalPrice { // CLEANED
                VStack { // CLEANED
                    Text("Your fair price is \(creditsResult.whipCoins) WhipCoins") // CLEANED
                        .font(.largeTitle) // CLEANED
                        .bold() // CLEANED
                        .foregroundColor(.green) // CLEANED
                        .scaleEffect(showFinalPrice ? 1.1 : 0.9) // CLEANED
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showFinalPrice) // CLEANED

                    HStack { // CLEANED
                        ForEach(0..<5) { _ in // CLEANED
                            Text("🎉") // CLEANED
                                .font(.title) // CLEANED
                                .offset(y: showFinalPrice ? -20 : 0) // CLEANED
                                .opacity(showFinalPrice ? 0 : 1) // CLEANED
                                .animation(.easeOut(duration: 1.0).delay(Double.random(in: 0...0.5)), value: showFinalPrice) // CLEANED
                        } // CLEANED
                    } // CLEANED
                } // CLEANED
                .transition(.scale) // CLEANED
            } // CLEANED

            if showFinalPrice { // CLEANED
                Button(action: collectTemplate) { // CLEANED
                    Text("🎉 Collect Template") // CLEANED
                        .font(.title2) // CLEANED
                        .padding() // CLEANED
                        .background(Color.blue) // CLEANED
                        .foregroundColor(.white) // CLEANED
                        .cornerRadius(10) // CLEANED
                } // CLEANED
                .transition(.opacity) // CLEANED
            } // CLEANED
        } // CLEANED
        .padding() // CLEANED
        .onAppear(perform: revealNext) // CLEANED
    } // CLEANED

    private func revealNext() { // CLEANED
        if currentIndex < creditsResult.breakdown.count { // CLEANED
            withAnimation(.easeIn(duration: 0.5)) { // CLEANED
                revealedItems.append(currentIndex) // CLEANED
            } // CLEANED
            currentIndex += 1 // CLEANED
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // CLEANED
                revealNext() // CLEANED
            } // CLEANED
        } else { // CLEANED
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // CLEANED
                withAnimation(.spring()) { // CLEANED
                    showFinalPrice = true // CLEANED
                } // CLEANED
            } // CLEANED
        } // CLEANED
    } // CLEANED

    private func collectTemplate() { // CLEANED
        if whipCoinsManager.consumeWhipCoins(creditsResult.whipCoins) { // CLEANED
            onCollected() // CLEANED
            dismiss() // CLEANED
        } else { // CLEANED
            onNeedWhipCoins() // CLEANED
            dismiss() // CLEANED
        } // CLEANED
    } // CLEANED
} // CLEANED

// MARK: - [Other UI components remain unchanged]
// [ParticipantHoursInputView, TemplateListView, CalculationResultView, etc. remain the same]

struct ParticipantHoursInputView: View {
    let template: TipTemplate
    @State private var hoursData: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Enter Hours Worked", systemImage: "clock")
                .font(.headline)
            
            ForEach(template.participants) { participant in
                HStack {
                    Text("\(participant.emoji) \(participant.name)")
                        .frame(width: 120, alignment: .leading)
                    
                    TextField("Hours", text: binding(for: participant.id.uuidString))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        // iOS 16 path: single-parameter onChange
        .modifier(HoursOnChangeModifier(hoursData: $hoursData, template: template))
    }
    
    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { hoursData[id] ?? "" },
            set: { hoursData[id] = $0 }
        )
    }
}

// Back-compat and iOS 17 compatible onChange handling for hoursData
private struct HoursOnChangeModifier: ViewModifier {
    @Binding var hoursData: [String: String]
    let template: TipTemplate

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .onChange(of: hoursData) { _, _ in
                    persist()
                }
        } else {
            content
                .onChange(of: hoursData) { _ in
                    persist()
                }
        }
    }

    private func persist() {
        for p in template.participants {
            if let val = Double(hoursData[p.id.uuidString] ?? "") { HoursStore.shared.set(id: p.id, hours: val) }
        }
    }
}

struct TemplateListView: View {
    @Binding var selectedTemplate: TipTemplate?
    @Environment(\.templateManager) private var templateManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(templateManager.templates) { template in
                    TemplateRow(template: template) {
                        selectedTemplate = template
                        dismiss()
                    }
                }
                .onDelete(perform: deleteTemplate)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func deleteTemplate(at offsets: IndexSet) {
        for index in offsets {
            templateManager.deleteTemplate(templateManager.templates[index])
        }
    }
}

struct TemplateRow: View {
    let template: TipTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.name)
                    .font(.headline)
                
                HStack {
                    Label(
                        template.rules.type.rawValue.capitalized,
                        systemImage: "chart.pie"
                    )
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(template.createdDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CalculationResultView: View {
    let template: TipTemplate
    let tipAmount: Double
    
    @Environment(\.apiService) private var apiService
    @Environment(\.dismiss) private var dismiss
    
    @State private var calculatedSplits: [Participant] = []
    @State private var isCalculating = true
    @State private var showExport = false
    @State private var showComparison = false
    @State private var calculationError: String?
    
    var body: some View {
        NavigationView {
            if isCalculating {
                loadingView
            } else {
                resultContent
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("Calculating...")
                .progressViewStyle(CircularProgressViewStyle())
            
            if let error = calculationError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .task {
            await calculateSplits()
        }
    }
    
    private var resultContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                totalAmountSection
                visualizationSection
                splitsSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Split Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showExport) {
            ExportView(splits: calculatedSplits, tipAmount: tipAmount)
        }
    }
    
    private var totalAmountSection: some View {
        VStack {
            Text(tipAmount, format: .currency(code: "USD")) // [fix]: use .currency format (replaces previous helper)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Total Pool")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var visualizationSection: some View {
        DynamicVisualizationView(
            splits: calculatedSplits,
            config: template.displayConfig,
            tipAmount: tipAmount
        )
        .frame(height: 300)
    }
    
    private var splitsSection: some View {
        VStack(spacing: 12) {
            ForEach(calculatedSplits) { split in
                DynamicSplitCard(
                    participant: split,
                    showComparison: showComparison
                )
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Toggle("Compare to Actual", isOn: $showComparison)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            
            HStack(spacing: 16) {
                Button(action: { showExport = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: shareSplit) {
                    Label("Share", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func calculateSplits() async {
        do {
            let effectiveTemplate = HoursStore.shared.apply(to: template)
            let response = try await apiService.calculateSplit(
                template: effectiveTemplate,
                tipPool: tipAmount
            )
            
            await MainActor.run {
                calculatedSplits = response.splits
                isCalculating = false
                calculationError = nil
            }
        } catch {
            await MainActor.run {
                calculationError = error.localizedDescription
                isCalculating = false
            }
        }
    }
    
    private func shareSplit() {
        let text = calculatedSplits
            .map { split -> String in
                let amount = (split.calculatedAmount ?? 0).currencyFormatted()
                return "\(split.emoji) \(split.name): \(amount)"
            }
            .joined(separator: "\n")
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - [Visualization Views remain unchanged]

struct DynamicVisualizationView: View {
    let splits: [Participant]
    let config: DisplayConfig
    let tipAmount: Double
    
    var body: some View {
        Group {
            switch config.primaryVisualization {
            case "pie":
                DynamicPieChart(splits: splits, tipAmount: tipAmount)
            case "bar":
                DynamicBarChart(splits: splits)
            case "flow":
                DynamicFlowDiagram(splits: splits, tipAmount: tipAmount)
            default:
                DynamicPieChart(splits: splits, tipAmount: tipAmount)
            }
        }
    }
}

struct DynamicPieChart: View {
    let splits: [Participant]
    let tipAmount: Double
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                    PieSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: split.color
                    )
                    .scaleEffect(animationProgress)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                        value: animationProgress
                    )
                }
                
                Circle()
                    .fill(Color.black)
                    .frame(width: geometry.size.width * 0.5)
                
                VStack {
                    Text("$\(Int(tipAmount))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("TOTAL")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            animationProgress = 1.0
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let total = splits.compactMap { $0.calculatedAmount }.reduce(0, +)
        guard total > 0 else { return .degrees(0) }
        
        let preceding = splits.prefix(index)
            .compactMap { $0.calculatedAmount }
            .reduce(0, +)
        
        return .degrees((preceding / total) * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let total = splits.compactMap { $0.calculatedAmount }.reduce(0, +)
        guard total > 0 else { return .degrees(0) }
        
        let preceding = splits.prefix(index + 1)
            .compactMap { $0.calculatedAmount }
            .reduce(0, +)
        
        return .degrees((preceding / total) * 360 - 90)
    }
}

struct DynamicBarChart: View {
    let splits: [Participant]
    @State private var animateChart = false
    
    private var maxAmount: Double {
        splits.compactMap { $0.calculatedAmount }.max() ?? 1
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(splits) { split in
                    VStack {
                        Text("$\(Int(split.calculatedAmount ?? 0))")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [split.color, split.color.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: barWidth(geometry: geometry),
                                height: barHeight(for: split, geometry: geometry)
                            )
                            .animation(.spring().delay(0.1), value: animateChart)
                        
                        VStack(spacing: 2) {
                            Text(split.emoji)
                            
                            Text(split.name)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            animateChart = true
        }
    }
    
    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let width = (geometry.size.width / CGFloat(splits.count)) - 16
        return max(width, 40)
    }
    
    private func barHeight(for split: Participant, geometry: GeometryProxy) -> CGFloat {
        guard animateChart else { return 0 }
        let amount = split.calculatedAmount ?? 0
        return CGFloat(amount / maxAmount) * (geometry.size.height - 60)
    }
}

struct DynamicFlowDiagram: View {
    let splits: [Participant]
    let tipAmount: Double
    @State private var showFlow = false
    
    var body: some View {
        VStack(spacing: 24) {
            poolSection
            
            Image(systemName: "arrow.down")
                .font(.title3)
                .foregroundColor(.purple)
                .opacity(showFlow ? 1.0 : 0)
            
            splitsGrid
        }
        .onAppear {
            showFlow = true
        }
    }
    
    private var poolSection: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            Text(tipAmount, format: .currency(code: "USD")) // [fix]: use .currency format
                .font(.title2.bold())
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .scaleEffect(showFlow ? 1.0 : 0.8)
        .opacity(showFlow ? 1.0 : 0)
    }
    
    private var splitsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                splitCard(split: split, index: index)
            }
        }
    }
    
    private func splitCard(split: Participant, index: Int) -> some View {
        VStack(spacing: 4) {
            Text(split.emoji)
                .font(.title2)
            
            Text(split.name)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(split.calculatedAmount ?? 0, format: .currency(code: "USD")) // [fix]: use .currency format
                .font(.subheadline.bold())
                .foregroundColor(.green)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .scaleEffect(showFlow ? 1.0 : 0.8)
        .opacity(showFlow ? 1.0 : 0)
        .animation(
            .spring().delay(Double(index) * 0.1 + 0.2),
            value: showFlow
        )
    }
}

struct DynamicSplitCard: View {
    let participant: Participant
    let showComparison: Bool
    
    @State private var actualAmount = ""
    
    private var discrepancy: Double? {
        guard showComparison,
              let actual = Double(actualAmount),
              let calculated = participant.calculatedAmount else { return nil }
        return actual - calculated
    }
    
    var body: some View {
        VStack(spacing: 12) {
            mainContent
            
            if showComparison {
                comparisonSection
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    discrepancyBorderColor,
                    lineWidth: 2
                )
        )
    }
    
    private var mainContent: some View {
        HStack {
            HStack(spacing: 12) {
                Text(participant.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                        .font(.headline)
                    
                    Text(participant.role)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(participant.calculatedAmount ?? 0, format: .currency(code: "USD")) // [fix]: use .currency format
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                if let weight = participant.weight {
                    Text("\(Int(weight))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if let hours = participant.hours {
                    Text(hours.formatted(.number.precision(.fractionLength(1))) + " hrs") // [fix]: direct hours formatting
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var comparisonSection: some View {
        HStack {
            Text("Actual:")
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField("Amount", text: $actualAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
            
            if let disc = discrepancy {
                Text(formatDiscrepancy(disc))
                    .font(.caption.bold())
                    .foregroundColor(disc == 0 ? .green : .red)
            }
            
            Spacer()
        }
    }
    
    private var discrepancyBorderColor: Color {
        guard let disc = discrepancy else { return .clear }
        return disc != 0 ? Color.red.opacity(0.5) : .clear
    }
    
    private func formatDiscrepancy(_ amount: Double) -> String {
        // [fix]: unified discrepancy formatting using formatter
        if amount == 0 { return 0.0.formatted(.currency(code: "USD")) } // [fix]: zero discrepancy formatting
        let absStr = abs(amount).formatted(.currency(code: "USD"))
        return (amount > 0 ? "+" : "-") + absStr
    }
}

struct ExportView: View {
    let splits: [Participant]
    let tipAmount: Double
    
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .csv
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case pdf = "PDF"
        case text = "Text"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                formatPicker
                previewSection
                Spacer()
                exportButton
            }
            .padding()
            .navigationTitle("Export Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(url: url)
            }
        }
    }
    
    private var formatPicker: some View {
        Picker("Format", selection: $exportFormat) {
            ForEach(ExportFormat.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            
            ScrollView {
                Text(generatePreview())
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
            .frame(maxHeight: 300)
        }
        .padding()
    }
    
    private var exportButton: some View {
        Button(action: exportData) {
            if isExporting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
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
        .disabled(isExporting)
    }
    
    private func generatePreview() -> String {
        switch exportFormat {
        case .csv:
            return generateCSV()
        case .text:
            return generateText()
        case .pdf:
            return "PDF Preview not available"
        }
    }
    
    private func generateCSV() -> String {
        // CLEANED
        var csv = "Name,Role,Amount,Percentage\n"
        let total = tipAmount > 0 ? tipAmount : nil
        for split in splits {
            let amount = split.calculatedAmount ?? 0
            let amountStr = amount.currencyFormatted()
            let percentageStr: String
            if let total = total, total > 0 {
                let pct = (amount / total) * 100
                percentageStr = String(format: "%.1f", pct)
            } else {
                percentageStr = "0.0" // Avoid misleading 100% when total is 0
            }
            csv += "\(split.name),\(split.role),\(amountStr),\(percentageStr)%\n"
        }
        return csv
    }
    
    private func generateText() -> String {
        let totalStr = tipAmount.currencyFormatted()
        var text = "Tip Split - Total: \(totalStr)\n"
        text += String(repeating: "-", count: 30) + "\n"
        for split in splits {
            let amountStr = (split.calculatedAmount ?? 0).currencyFormatted()
            text += "\(split.emoji) \(split.name) (\(split.role)): \(amountStr)\n"
        }
        return text
    }
    
    private func exportData() {
        isExporting = true
        Task {
            let content = generatePreview()
            // Decide extension based on selected format (PDF placeholder for future implementation)
            let ext: String
            switch exportFormat {
            case .csv: ext = "csv"
            case .text: ext = "txt"
            case .pdf: ext = "pdf" // TODO: Implement real PDF rendering
            }
            let fileName = "TipSplit_\(UInt(Date().timeIntervalSince1970)).\(ext)"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    exportedFileURL = url
                    showShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run { isExporting = false }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Subscription View (UPDATED with StoreKit 2)

struct SubscriptionView: View {
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    if subscriptionManager.isSubscribed {
                        subscribedSection
                    } else {
                        subscriptionOfferSection
                    }
                    
                    featureComparisonSection
                    
                    if !subscriptionManager.isSubscribed {
                        purchaseSection
                    }
                    
                    restoreButton
                }
                .padding()
            }
            .navigationTitle("WhipTip Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(subscriptionManager.$purchaseError) { error in
            if let error = error {
                errorMessage = error
                showError = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("WhipTip Pro")
                .font(.title.bold())
            
            Text("Unlock unlimited templates and premium features")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var subscribedSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're a Pro Member!")
                        .font(.headline)
                    
                    Text("Status: \(subscriptionManager.subscriptionStatus.rawValue)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
            
            if subscriptionManager.subscriptionStatus == .trial {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("You're currently in your free trial period")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var subscriptionOfferSection: some View {
        VStack(spacing: 12) {
            if let product = subscriptionManager.product {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Monthly Subscription")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Safe display price with fallback manual formatting
                        Text(productDisplayPrice(product))
                            .font(.title3.bold())
                    }
                    
                    if subscriptionManager.hasFreeTrial {
                        Label("\(subscriptionManager.trialDays)-day free trial included", systemImage: "gift")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple, lineWidth: 2)
                )
            } else if subscriptionManager.isLoadingProducts {
                ProgressView("Loading subscription options...")
                    .padding()
            } else {
                Text("Subscription options unavailable")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }

    // Clean price formatting without reflection
    private func productDisplayPrice(_ product: Product) -> String {
        if #available(iOS 15.0, *) {
            // StoreKit 2 exposes localized displayPrice
            return product.displayPrice
        } else {
            // Very old fallback: manual currency formatting
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = product.priceFormatStyle.currencyCode
            return formatter.string(from: product.price as NSDecimalNumber) ?? ""
        }
    }
    
    
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's included:")
                .font(.headline)
                .padding(.bottom, 8)
            
            FeatureComparisonRow(
                feature: "Templates",
                free: "1 template",
                pro: "Unlimited templates"
            )
            
            FeatureComparisonRow(
                feature: "Team Members",
                free: "Up to 5",
                pro: "Unlimited"
            )
            
            FeatureComparisonRow(
                feature: "Export Options",
                free: "Text only",
                pro: "CSV, PDF, Excel"
            )
            
            FeatureComparisonRow(
                feature: "Cloud Sync",
                free: "—",
                pro: "✓"
            )
            
            FeatureComparisonRow(
                feature: "Priority Support",
                free: "—",
                pro: "✓"
            )
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var purchaseSection: some View {
        Button(action: {
            Task {
                await subscriptionManager.purchase()
            }
        }) {
            if subscriptionManager.isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                HStack {
                    Image(systemName: "crown")
                    
                    if subscriptionManager.hasFreeTrial {
                        Text("Start Free Trial")
                            .font(.headline)
                    } else {
                        Text("Subscribe Now")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .background(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .disabled(subscriptionManager.isPurchasing || subscriptionManager.product == nil)
    }
    
    private var restoreButton: some View {
        Button(action: {
            Task {
                await subscriptionManager.restorePurchases()
            }
        }) {
            if subscriptionManager.isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Text("Restore Purchases")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .disabled(subscriptionManager.isPurchasing)
    }
}

struct FeatureComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            Text(free)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80)
            
            Text(pro)
                .font(.caption)
                .foregroundColor(.green)
                .frame(width: 100)
        }
    }
}

// MARK: - Pie Slice Shape

struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
            .shadow(color: color.opacity(0.3), radius: 10)
        }
    }
}

// TODO: Integrate referral system for 7-day trial override
// - Check ReferralManager.hasActiveBonus() in subscription gating
// - Add referral code redemption UI in onboarding flow
// - Wire up inviteCoworker() action for Pro subscribers

#if DEBUG
// MARK: - Debug Dashboard (DEBUG only)

@MainActor
struct DebugDashboardView: View {
    @AppStorage("DebugShowAPIKeyAlert") private var showAPIKeyAlert: Bool = true
    @AppStorage("DebugVerboseAPILogging") private var verboseAPILogging: Bool = false
    @AppStorage("DebugEnableMockData") private var enableMockData: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Developer Toggles")) {
                    Toggle("Show API Key Alert", isOn: $showAPIKeyAlert)
                    Toggle("Verbose API Logging", isOn: $verboseAPILogging)
                    Toggle("Enable Mock Data", isOn: $enableMockData)
                }

                Section(header: Text("Actions"), footer: Text("These settings only exist in Debug builds.")) {
                    Button {
                        showAPIKeyAlert = true
                    } label: {
                        Label("Reset API Key Alert", systemImage: "exclamationmark.bubble")
                    }
                }
            }
            .navigationTitle("Debug Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#endif
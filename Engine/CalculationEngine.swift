// CalculationEngine.swift
// WhipTip Engine

import Foundation

// [SUBSECTION: Calculation Engine]
// [NOTE: Engine lives here to keep core models and algorithms together; ready to split into Engine/ later]
// [ENTITY: CalculationEngine / computeSplits]
// [USES: TipTemplate, Participant, TipRules]
// [FEATURE: Export | Diagnostics]

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
    case .hybrid:
        if rules.formula.contains("hours") { return _allocateHoursHybrid(participants: participants, remainderCents: remainderCents) }
        do {
            let alloc = try _parseHybridPercentages(formula: rules.formula)
            return _processHybrid(allocations: alloc, participants: participants, remainderCents: remainderCents)
        } catch {
            return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hybrid)
        }
    case .custom:
        if let customLogic = rules.customLogic, !customLogic.isEmpty {
            // For demo purposes only - simulate a custom logic implementation
            var warnings: [String] = []
            warnings.append("Using custom business logic (demo)")
            
            // This is just a placeholder that mimics a role-weighted split
            var roleWeights: [String: Double] = [:]
            roleWeights["Server"] = 1.5
            roleWeights["Bartender"] = 1.25
            roleWeights["Busser"] = 0.75
            
            let (splits, splitWarnings) = _allocateByCustomRoleWeights(participants: participants, remainderCents: remainderCents, roleWeights: roleWeights)
            warnings.append(contentsOf: splitWarnings)
            return (splits, warnings)
        } else {
            return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .custom)
        }
    }
}

enum PennyDistributionContext { case offTop, main }

private func _orderForPennyDistribution(ids: [UUID], remainders: [UUID: Double], participants: [Participant], context: PennyDistributionContext) -> [UUID] {
    var weights: [(id: UUID, weight: Double)] = []
    
    // Map IDs to remainder weights
    for id in ids {
        weights.append((id: id, weight: remainders[id] ?? 0))
    }
    
    // Sort by remainder weight descending, then by participant name for consistency
    return weights
        .sorted { lhs, rhs in
            if abs(lhs.weight - rhs.weight) > weightNormalizationEpsilon {
                return lhs.weight > rhs.weight
            } else {
                let lhsName = participants.first(where: { $0.id == lhs.id })?.name ?? ""
                let rhsName = participants.first(where: { $0.id == rhs.id })?.name ?? ""
                return lhsName < rhsName
            }
        }
        .map { $0.id }
}

private func _combineAndFixPennies(offTop: [UUID: Int], main: [UUID: Int], targetTotal: Int, participants: [Participant]) -> [UUID: Int] {
    var combined: [UUID: Int] = [:]
    
    // Combine off-the-top and main allocations
    for (id, amount) in offTop {
        combined[id] = amount
    }
    
    for (id, amount) in main {
        combined[id, default: 0] += amount
    }
    
    // Calculate actual total
    let currentTotal = combined.values.reduce(0, +)
    let difference = targetTotal - currentTotal
    
    if difference != 0 {
        // If there's a difference due to rounding, distribute the pennies
        let allParticipantIDs = participants.map { $0.id }
        if difference > 0 {
            // Need to add pennies
            let sortedIDs = allParticipantIDs.sorted {
                let aName = participants.first(where: { $0.id == $0 })?.name ?? ""
                let bName = participants.first(where: { $0.id == $1 })?.name ?? ""
                return aName < bName
            }
            
            var remaining = difference
            var index = 0
            while remaining > 0 && index < sortedIDs.count {
                combined[sortedIDs[index], default: 0] += 1
                remaining -= 1
                index += 1
            }
        } else {
            // Need to remove pennies
            let sortedIDs = allParticipantIDs.sorted {
                let aName = participants.first(where: { $0.id == $0 })?.name ?? ""
                let bName = participants.first(where: { $0.id == $1 })?.name ?? ""
                return aName > bName // Reverse order for removing
            }
            
            var remaining = -difference
            var index = 0
            while remaining > 0 && index < sortedIDs.count {
                let id = sortedIDs[index]
                if let current = combined[id], current > 0 {
                    combined[id] = current - 1
                    remaining -= 1
                }
                index += 1
            }
        }
    }
    
    return combined
}

private func _allocateEqual(participants: [Participant], remainderCents: Int, ruleType: TipRules.RuleType) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    if participants.isEmpty {
        warnings.append("No participants to split among")
        return ([:], warnings)
    }
    
    let count = participants.count
    let baseAmount = remainderCents / count
    let remaining = remainderCents - (baseAmount * count)
    
    var perID: [UUID: Int] = [:]
    
    // Allocate base amount to each participant
    for p in participants {
        perID[p.id] = baseAmount
    }
    
    // Distribute remaining pennies
    if remaining > 0 {
        let sortedParticipants = participants.sorted { $0.name < $1.name }
        for i in 0..<remaining {
            let id = sortedParticipants[i % sortedParticipants.count].id
            perID[id, default: 0] += 1
        }
    }
    
    return (perID, warnings)
}

private func _allocateHours(participants: [Participant], remainderCents: Int) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    let participantsWithHours = participants.filter { $0.hours != nil && $0.hours! > 0 }
    
    if participantsWithHours.isEmpty {
        warnings.append("No participants with hours specified; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hoursBased)
    }
    
    // Calculate total hours
    let totalHours = participantsWithHours.reduce(0.0) { $0 + ($1.hours ?? 0) }
    
    if totalHours <= 0 {
        warnings.append("Total hours is zero; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hoursBased)
    }
    
    var perID: [UUID: Int] = [:]
    var allocated = 0
    var remainders: [UUID: Double] = [:]
    
    // Allocate based on hours
    for p in participantsWithHours {
        let hours = p.hours ?? 0
        let share = Double(remainderCents) * (hours / totalHours)
        let intShare = Int(share)
        
        perID[p.id] = intShare
        allocated += intShare
        remainders[p.id] = share - Double(intShare)
    }
    
    // Distribute remaining pennies based on fractional parts
    let remaining = remainderCents - allocated
    if remaining > 0 {
        let ordered = _orderForPennyDistribution(ids: participantsWithHours.map { $0.id }, remainders: remainders, participants: participants, context: .main)
        for i in 0..<remaining {
            perID[ordered[i % ordered.count], default: 0] += 1
        }
    }
    
    return (perID, warnings)
}

private func _allocatePercentage(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    let participantsWithWeights = participants.filter { $0.weight != nil && $0.weight! > 0 }
    
    if participantsWithWeights.isEmpty {
        warnings.append("No participants with weights specified; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .percentage)
    }
    
    // Calculate total weights
    let totalWeight = participantsWithWeights.reduce(0.0) { $0 + ($1.weight ?? 0) }
    
    if totalWeight <= 0 {
        warnings.append("Total weight is zero; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .percentage)
    }
    
    var perID: [UUID: Int] = [:]
    var allocated = 0
    var remainders: [UUID: Double] = [:]
    
    // Allocate based on weights
    for p in participantsWithWeights {
        let weight = p.weight ?? 0
        let share = Double(remainderCents) * (weight / totalWeight)
        let intShare = Int(share)
        
        perID[p.id] = intShare
        allocated += intShare
        remainders[p.id] = share - Double(intShare)
    }
    
    // Distribute remaining pennies based on fractional parts
    let remaining = remainderCents - allocated
    if remaining > 0 {
        let ordered = _orderForPennyDistribution(ids: participantsWithWeights.map { $0.id }, remainders: remainders, participants: participants, context: .main)
        for i in 0..<remaining {
            perID[ordered[i % ordered.count], default: 0] += 1
        }
    }
    
    return (perID, warnings)
}

private func _allocateRoleWeighted(participants: [Participant], remainderCents: Int, rules: TipRules) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    
    guard let roleWeights = rules.roleWeights, !roleWeights.isEmpty else {
        warnings.append("No role weights specified; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted)
    }
    
    return _allocateByCustomRoleWeights(participants: participants, remainderCents: remainderCents, roleWeights: roleWeights)
}

private func _allocateByCustomRoleWeights(participants: [Participant], remainderCents: Int, roleWeights: [String: Double]) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    var perID: [UUID: Int] = [:]
    var allocated = 0
    var participantsWithWeights: [Participant] = []
    var weightsByID: [UUID: Double] = [:]
    var totalWeight = 0.0
    
    // Assign weights based on roles
    for p in participants {
        if let weight = roleWeights[p.role] {
            participantsWithWeights.append(p)
            weightsByID[p.id] = weight
            totalWeight += weight
        } else {
            warnings.append("No weight specified for role '\(p.role)'")
        }
    }
    
    if participantsWithWeights.isEmpty {
        warnings.append("No participants with weighted roles; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted)
    }
    
    if totalWeight <= 0 {
        warnings.append("Total role weight is zero; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .roleWeighted)
    }
    
    var remainders: [UUID: Double] = [:]
    
    // Allocate based on role weights
    for p in participantsWithWeights {
        if let weight = weightsByID[p.id] {
            let share = Double(remainderCents) * (weight / totalWeight)
            let intShare = Int(share)
            
            perID[p.id] = intShare
            allocated += intShare
            remainders[p.id] = share - Double(intShare)
        }
    }
    
    // Distribute remaining pennies based on fractional parts
    let remaining = remainderCents - allocated
    if remaining > 0 {
        let ordered = _orderForPennyDistribution(ids: participantsWithWeights.map { $0.id }, remainders: remainders, participants: participants, context: .main)
        for i in 0..<remaining {
            perID[ordered[i % ordered.count], default: 0] += 1
        }
    }
    
    return (perID, warnings)
}

private func _allocateHoursHybrid(participants: [Participant], remainderCents: Int) -> (perID: [UUID: Int], warnings: [String]) {
    var warnings: [String] = []
    let participantsWithHours = participants.filter { $0.hours != nil && $0.hours! > 0 }
    
    if participantsWithHours.isEmpty {
        warnings.append("No participants with hours specified; using equal split")
        return _allocateEqual(participants: participants, remainderCents: remainderCents, ruleType: .hybrid)
    }
    
    // Group participants by role
    var participantsByRole: [String: [Participant]] = [:]
    for p in participantsWithHours {
        if participantsByRole[p.role] == nil {
            participantsByRole[p.role] = []
        }
        participantsByRole[p.role]!.append(p)
    }
    
    var perID: [UUID: Int] = [:]
    var warnings: [String] = []
    
    // Allocate for each role group
    for (role, groupParticipants) in participantsByRole {
        // Calculate total hours for this role
        let roleHours = groupParticipants.reduce(0.0) { $0 + ($1.hours ?? 0) }
        
        // Calculate share for this role group
        let roleShare = Double(remainderCents) * (roleHours / participantsWithHours.reduce(0.0) { $0 + ($1.hours ?? 0) })
        let roleShareCents = Int(roleShare)
        
        // Allocate among participants in this role
        var allocated = 0
        var remainders: [UUID: Double] = [:]
        
        for p in groupParticipants {
            let hours = p.hours ?? 0
            let share = Double(roleShareCents) * (hours / roleHours)
            let intShare = Int(share)
            
            perID[p.id] = intShare
            allocated += intShare
            remainders[p.id] = share - Double(intShare)
        }
        
        // Distribute remaining pennies based on fractional parts
        let remaining = roleShareCents - allocated
        if remaining > 0 {
            let ordered = _orderForPennyDistribution(ids: groupParticipants.map { $0.id }, remainders: remainders, participants: participants, context: .main)
            for i in 0..<remaining {
                perID[ordered[i % ordered.count], default: 0] += 1
            }
        }
    }
    
    return (perID, warnings)
}

private func _parseHybridPercentages(formula: String) throws -> [(role: String, weight: Double)] {
    let pattern = "([A-Za-z\\s]+):\\s*(\\d+(?:\\.\\d+)?)"
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let nsString = formula as NSString
    let matches = regex.matches(in: formula, options: [], range: NSRange(location: 0, length: nsString.length))
    
    if matches.isEmpty {
        throw WhipCoreError.invalidOffTheTopPercentage(role: "Unknown", percentage: 0)
    }
    
    var result: [(role: String, weight: Double)] = []
    for match in matches {
        guard match.numberOfRanges == 3,
              let roleRange = Range(match.range(at: 1), in: formula),
              let valueRange = Range(match.range(at: 2), in: formula),
              let value = Double(formula[valueRange]) else {
            continue
        }
        
        let role = String(formula[roleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        result.append((role: role, weight: value))
    }
    
    return result
}

private func _parseRoleWeightString(formula: String) throws -> [(role: String, weight: Double)] {
    let parts = formula.components(separatedBy: ";").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    if parts.isEmpty {
        throw WhipCoreError.invalidRoleWeight(role: formula, weight: 0)
    }
    
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
    }
    return (result, warnings)
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
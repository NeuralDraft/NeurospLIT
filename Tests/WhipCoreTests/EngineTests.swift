import XCTest
@testable import WhipCore

final class EngineTests: XCTestCase {
    // MARK: - Helpers
    private func buildTemplate(
        name: String = "Test",
        ruleType: TipRules.RuleType,
        participants: [Participant],
        roleWeights: [String: Double]? = nil,
        offTop: [OffTheTopRule]? = nil,
        formula: String = ""
    ) -> TipTemplate {
        TipTemplate(
            name: name,
            createdDate: Date(),
            rules: TipRules(type: ruleType, formula: formula, offTheTop: offTop, roleWeights: roleWeights, customLogic: nil),
            participants: participants,
            displayConfig: DisplayConfig(primaryVisualization: "pie", accentColor: "purple", showPercentages: true, showComparison: true)
        )
    }

    private func centsTotal(_ splits: [Participant]) -> Int {
        splits.compactMap { $0.calculatedAmount }.map { Int(round($0 * 100)) }.reduce(0, +)
    }

    // MARK: - Equal Split
    func testEqualSplit_basic() throws {
        let ps = [Participant(name: "A", role: "any"), Participant(name: "B", role: "any"), Participant(name: "C", role: "any")]
        let t = buildTemplate(ruleType: .equal, participants: ps)
        let (splits, warnings) = computeSplits(template: t, pool: 300)
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(Set(splits.compactMap { $0.calculatedAmount }), [100.0])
        XCTAssertEqual(centsTotal(splits), 30000)
    }

    func testEqualSplit_roundingFairness() throws {
        let ps = ["A","B","C"].map { Participant(name: $0, role: "any") }
        let t = buildTemplate(ruleType: .equal, participants: ps)
        let (splits, _) = computeSplits(template: t, pool: 100)
        let cents = splits.compactMap { $0.calculatedAmount }.map { Int(round($0 * 100)) }
        XCTAssertEqual(cents.reduce(0,+), 10000)
        let maxC = cents.max() ?? 0, minC = cents.min() ?? 0
        XCTAssertLessThanOrEqual(maxC - minC, 1)
        XCTAssertEqual(cents.filter { $0 == maxC }.count, 1)
    }

    func testEqualSplit_determinism() throws {
        let ps = ["A","B","C","D"].map { Participant(name: $0, role: "any") }
        let t = buildTemplate(ruleType: .equal, participants: ps)
        let (s1, _) = computeSplits(template: t, pool: 123.45)
        let (s2, _) = computeSplits(template: t, pool: 123.45)
        XCTAssertEqual(s1.compactMap { $0.calculatedAmount }, s2.compactMap { $0.calculatedAmount })
    }

    // TODO: testEqualSplit_emptyInput — should yield no splits and a warning
    // TODO: testEqualSplit_negativePool — should warn and/or clamp to zero

    // MARK: - Hours-Based
    func testHoursBased_basic() throws {
        let ps = [Participant(name: "A", role: "x", hours: 5), Participant(name: "B", role: "y", hours: 3)]
        let t = buildTemplate(ruleType: .hoursBased, participants: ps)
        let (splits, warnings) = computeSplits(template: t, pool: 80)
        XCTAssertTrue(warnings.isEmpty)
        let cents = splits.compactMap { $0.calculatedAmount }.map { Int(round($0 * 100)) }
        XCTAssertEqual(cents.reduce(0,+), 8000)
        XCTAssertGreaterThan(cents[0], cents[1])
    }

    func testHoursBased_zeroHoursFallback() throws {
        let ps = [Participant(name: "A", role: "x", hours: 0), Participant(name: "B", role: "y", hours: 0), Participant(name: "C", role: "z", hours: 0)]
        let t = buildTemplate(ruleType: .hoursBased, participants: ps)
        let (splits, warnings) = computeSplits(template: t, pool: 99)
        XCTAssertEqual(centsTotal(splits), 9900)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("hours") })
    }

    func testHoursBased_determinism() throws {
        let ps = [Participant(name: "A", role: "x", hours: 4), Participant(name: "B", role: "y", hours: 6)]
        let t = buildTemplate(ruleType: .hoursBased, participants: ps)
        let (s1, _ ) = computeSplits(template: t, pool: 77.31)
        let (s2, _ ) = computeSplits(template: t, pool: 77.31)
        XCTAssertEqual(s1.compactMap { $0.calculatedAmount }, s2.compactMap { $0.calculatedAmount })
    }

    // TODO: testHoursBased_allZeroHours — ensure equal fallback and warning
    // TODO: testHoursBased_largeRounding — stress random hours with large pool

    // MARK: - Percentage-Based
    func testPercentage_basedParticipantWeights() throws {
        var ps = [
            Participant(name: "A", role: "server", weight: 60),
            Participant(name: "B", role: "support", weight: 40)
        ]
        let t = buildTemplate(ruleType: .percentage, participants: ps)
        let (splits, warnings) = computeSplits(template: t, pool: 100)
        XCTAssertTrue(warnings.isEmpty)
        let amounts = splits.compactMap { $0.calculatedAmount }
        XCTAssertTrue(amounts.contains(60.0))
        XCTAssertTrue(amounts.contains(40.0))
        XCTAssertEqual(centsTotal(splits), 10000)
    }

    func testPercentage_roleWeightsNormalization() throws {
        let ps = [Participant(name: "A", role: "server"), Participant(name: "B", role: "support")]
        // Sum to 120 to trigger normalization path
        let t = buildTemplate(ruleType: .percentage, participants: ps, roleWeights: ["server": 90, "support": 30])
        let (splits, warnings) = computeSplits(template: t, pool: 50)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("normalized") })
        XCTAssertEqual(centsTotal(splits), 5000)
    }

    // TODO: testPercentage_missingRoles — ensure weights for non-existent roles are ignored
    // TODO: testPercentage_emptyWeights — fallback to equal

    // MARK: - Role-Weighted
    func testRoleWeighted_basic() throws {
        let ps = [Participant(name: "A", role: "server"), Participant(name: "B", role: "support")]
        let t = buildTemplate(ruleType: .roleWeighted, participants: ps, roleWeights: ["server": 70, "support": 30])
        let (splits, warnings) = computeSplits(template: t, pool: 100)
        XCTAssertTrue(warnings.isEmpty)
        let amounts = splits.compactMap { $0.calculatedAmount }
        XCTAssertTrue(amounts.contains(70.0))
        XCTAssertTrue(amounts.contains(30.0))
        XCTAssertEqual(centsTotal(splits), 10000)
    }

    func testRoleWeighted_normalizationAndMissingRole() throws {
        let ps = [Participant(name: "A", role: "server"), Participant(name: "B", role: "support")]
        // Include a role with no participants and weights not summing to 100
        let t = buildTemplate(ruleType: .roleWeighted, participants: ps, roleWeights: ["server": 60, "support": 30, "host": 30])
        let (splits, warnings) = computeSplits(template: t, pool: 90)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("normalized") })
        XCTAssertEqual(centsTotal(splits), 9000)
    }

    // TODO: testRoleWeighted_allZeroWeights — fallback to equal
    // TODO: testRoleWeighted_negativeWeights — clamp to zero and normalize

    // MARK: - Hybrid
    func testHybrid_basic() throws {
        let ps = [
            Participant(name: "A", role: "server"),
            Participant(name: "B", role: "server"),
            Participant(name: "C", role: "support")
        ]
        // 60% to server (2 members share), 40% to support
        let t = buildTemplate(ruleType: .hybrid, participants: ps, formula: "server:60, support:40")
        let (splits, warnings) = computeSplits(template: t, pool: 100)
        XCTAssertTrue(warnings.isEmpty)
        let cents = splits.compactMap { $0.calculatedAmount }.map { Int(round($0 * 100)) }
        // Expect two near 30% shares and one near 40%
        XCTAssertEqual(cents.reduce(0,+), 10000)
        XCTAssertEqual(cents.filter { $0 >= 3333 && $0 <= 3334 }.count, 0) // hybrid not equal across all
    }

    func testHybrid_normalizationAndMissingRole() throws {
        let ps = [Participant(name: "A", role: "server"), Participant(name: "B", role: "support")]
        let t = buildTemplate(ruleType: .hybrid, participants: ps, formula: "server:120, host:20")
        let (splits, warnings) = computeSplits(template: t, pool: 75)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("normalized") } || warnings.contains { $0.localizedCaseInsensitiveContains("no participants") })
        XCTAssertEqual(centsTotal(splits), 7500)
    }

    // TODO: testHybrid_emptyFormula — fallback to equal
    // TODO: testHybrid_nonNumericPercentages — robust parsing should treat as zero

    // MARK: - Off-the-Top (deduction first)
    func testOffTheTop_deductionAndClamp() throws {
        let ps = [
            Participant(name: "A", role: "server"),
            Participant(name: "B", role: "busser")
        ]
        let off = [OffTheTopRule(role: "server", percentage: 80), OffTheTopRule(role: "busser", percentage: 70)]
        let t = buildTemplate(ruleType: .equal, participants: ps, offTop: off)
        let (splits, warnings) = computeSplits(template: t, pool: 100)
        XCTAssertLessThanOrEqual(splits.compactMap { $0.calculatedAmount }.reduce(0,+), 100.0)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("clamped") })
    }

    func testOffTheTop_roleWithoutParticipants() throws {
        let ps = [Participant(name: "A", role: "server")] ; let off = [OffTheTopRule(role: "host", percentage: 10)]
        let t = buildTemplate(ruleType: .equal, participants: ps, offTop: off)
        let (_, warnings) = computeSplits(template: t, pool: 10)
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("no participants") })
    }

    // MARK: - Penny clamping & integrity
    func testPennyClamping_integrity() throws {
        let ps = [Participant(name: "A", role: "r"), Participant(name: "B", role: "r"), Participant(name: "C", role: "r")] 
        let t = buildTemplate(ruleType: .equal, participants: ps)
        for pool in stride(from: 1.01, through: 19.99, by: 0.37) {
            let totalCents = Int(round(pool * 100))
            let (splits, warnings) = computeSplits(template: t, pool: pool)
            XCTAssertTrue(warnings.isEmpty)
            XCTAssertEqual(centsTotal(splits), totalCents)
            XCTAssertTrue(splits.allSatisfy { ($0.calculatedAmount ?? 0) >= 0 })
        }
    }

    // MARK: - Determinism across rule types
    func testDeterminism_allRules() throws {
        let ps = [
            Participant(name: "Alice", role: "server", hours: 5, weight: 50),
            Participant(name: "Bob", role: "support", hours: 5, weight: 50),
            Participant(name: "Cara", role: "support", hours: 4)
        ]
        let rules: [(TipRules.RuleType, [String: Double]?, [OffTheTopRule]?, String)] = [
            (.equal, nil, nil, ""),
            (.hoursBased, nil, nil, ""),
            (.percentage, nil, nil, ""),
            (.roleWeighted, ["server": 60, "support": 40], nil, ""),
            (.hybrid, nil, nil, "server:50, support:50")
        ]
        for (rule, roleWeights, offTop, formula) in rules {
            XCTContext.runActivity(named: "Determinism for \(rule)") { _ in
                let t = buildTemplate(ruleType: rule, participants: ps, roleWeights: roleWeights, offTop: offTop, formula: formula)
                let (s1, _) = computeSplits(template: t, pool: 77.31)
                let (s2, _) = computeSplits(template: t, pool: 77.31)
                XCTAssertEqual(s1.compactMap { $0.calculatedAmount }, s2.compactMap { $0.calculatedAmount })
            }
        }
    }
}

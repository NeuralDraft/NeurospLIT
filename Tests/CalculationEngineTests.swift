// CalculationEngineTests.swift
// WhipTip Unit Tests

import XCTest
@testable import WhipTip

class CalculationEngineTests: XCTestCase {
    
    // MARK: - Equal Split Tests
    
    func testEqualSplit() {
        // Create a test template with 2 participants
        let template = TipTemplate(
            name: "Equal Split Test",
            rules: TipRules(type: .equal),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender")
            ]
        )
        
        // Test with an even amount
        let result100 = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result100.splits.count, 2)
        XCTAssertEqual(result100.splits[0].calculatedAmount, 50.0)
        XCTAssertEqual(result100.splits[1].calculatedAmount, 50.0)
        XCTAssertTrue(result100.warnings.isEmpty)
        
        // Test with an odd amount (should handle penny rounding)
        let result101 = computeSplits(template: template, pool: 101.0)
        XCTAssertEqual(result101.splits.count, 2)
        // Check total adds up correctly
        let total = (result101.splits[0].calculatedAmount ?? 0) + (result101.splits[1].calculatedAmount ?? 0)
        XCTAssertEqual(total, 101.0)
        // Check the extra penny went somewhere
        XCTAssertTrue(result101.splits.contains { ($0.calculatedAmount ?? 0) == 50.5 })
    }
    
    func testEqualSplitWithMoreParticipants() {
        // Create a test template with 3 participants
        let template = TipTemplate(
            name: "Equal Split Test",
            rules: TipRules(type: .equal),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender"),
                Participant(name: "Bob", role: "Host")
            ]
        )
        
        // Test with amount that doesn't divide evenly
        let result100 = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result100.splits.count, 3)
        
        // Check total adds up correctly
        let total = result100.splits.reduce(0.0) { $0 + ($1.calculatedAmount ?? 0) }
        XCTAssertEqual(total, 100.0)
        
        // Check distribution (33.33, 33.33, 33.34 or similar)
        let amounts = result100.splits.compactMap { $0.calculatedAmount }.sorted()
        XCTAssertEqual(amounts[0], amounts[1])  // First two should be equal
        XCTAssertEqual(amounts[0] + amounts[1] + amounts[2], 100.0)  // Total is correct
    }
    
    // MARK: - Hours-Based Split Tests
    
    func testHoursBasedSplit() {
        // Create a test template with 2 participants with hours
        let template = TipTemplate(
            name: "Hours Split Test",
            rules: TipRules(type: .hoursBased),
            participants: [
                Participant(name: "John", role: "Server", hours: 5.0),
                Participant(name: "Jane", role: "Bartender", hours: 3.0)
            ]
        )
        
        // Test the split
        let result = computeSplits(template: template, pool: 80.0)
        XCTAssertEqual(result.splits.count, 2)
        
        // John worked 5/(5+3) = 5/8 = 62.5% of hours
        // Jane worked 3/(5+3) = 3/8 = 37.5% of hours
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(johnAmount, 50.0, accuracy: 0.01) // 62.5% of $80 = $50
        XCTAssertEqual(janeAmount, 30.0, accuracy: 0.01) // 37.5% of $80 = $30
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    func testHoursBasedSplitWithZeroHours() {
        // Test with a participant with zero hours
        let template = TipTemplate(
            name: "Hours Split Test",
            rules: TipRules(type: .hoursBased),
            participants: [
                Participant(name: "John", role: "Server", hours: 5.0),
                Participant(name: "Jane", role: "Bartender", hours: 0.0)
            ]
        )
        
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 2)
        
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(johnAmount, 100.0) // All should go to John
        XCTAssertEqual(janeAmount, 0.0)   // None should go to Jane
        XCTAssertFalse(result.warnings.isEmpty) // Should warn about zero hours
    }
    
    func testHoursBasedSplitWithNoHours() {
        // Test with no hours specified - should fall back to equal split
        let template = TipTemplate(
            name: "Hours Split Test",
            rules: TipRules(type: .hoursBased),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender")
            ]
        )
        
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 2)
        
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        // Should fallback to equal split
        XCTAssertEqual(johnAmount, 50.0)
        XCTAssertEqual(janeAmount, 50.0)
        XCTAssertFalse(result.warnings.isEmpty) // Should warn about no hours
    }
    
    // MARK: - Percentage Split Tests
    
    func testPercentageSplit() {
        // Create a test template with percentage weights
        let template = TipTemplate(
            name: "Percentage Split Test",
            rules: TipRules(type: .percentage),
            participants: [
                Participant(name: "John", role: "Server", weight: 75.0),
                Participant(name: "Jane", role: "Bartender", weight: 25.0)
            ]
        )
        
        // Test the split
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 2)
        
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(johnAmount, 75.0) // 75% of $100
        XCTAssertEqual(janeAmount, 25.0) // 25% of $100
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    func testPercentageSplitWithInvalidWeights() {
        // Test with a zero total weight - should fall back to equal split
        let template = TipTemplate(
            name: "Invalid Percentage Test",
            rules: TipRules(type: .percentage),
            participants: [
                Participant(name: "John", role: "Server", weight: 0.0),
                Participant(name: "Jane", role: "Bartender", weight: 0.0)
            ]
        )
        
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 2)
        
        // Should fallback to equal split
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        XCTAssertEqual(johnAmount, 50.0)
        XCTAssertEqual(janeAmount, 50.0)
        XCTAssertFalse(result.warnings.isEmpty) // Should warn about total weight
    }
    
    // MARK: - Role-Weighted Split Tests
    
    func testRoleWeightedSplit() {
        // Create a test template with role weights
        let template = TipTemplate(
            name: "Role-Weighted Split Test",
            rules: TipRules(
                type: .roleWeighted,
                roleWeights: ["Server": 2.0, "Bartender": 1.0]
            ),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Sarah", role: "Server"),
                Participant(name: "Jane", role: "Bartender")
            ]
        )
        
        // Test the split
        let result = computeSplits(template: template, pool: 120.0)
        XCTAssertEqual(result.splits.count, 3)
        
        // Verify role weights were applied correctly
        let serverAmounts = result.splits.filter { $0.role == "Server" }.compactMap { $0.calculatedAmount }
        let bartenderAmount = result.splits.first { $0.role == "Bartender" }?.calculatedAmount ?? 0
        
        // Each server should get twice what the bartender gets
        XCTAssertEqual(serverAmounts.count, 2)
        XCTAssertEqual(serverAmounts[0], serverAmounts[1]) // Both servers get the same amount
        XCTAssertEqual(serverAmounts[0], 2 * bartenderAmount) // Server gets twice bartender amount
        
        // Total should be correct
        let total = result.splits.reduce(0.0) { $0 + ($1.calculatedAmount ?? 0) }
        XCTAssertEqual(total, 120.0)
    }
    
    func testRoleWeightedSplitWithMissingRoles() {
        // Test with a role that has no weight
        let template = TipTemplate(
            name: "Missing Role-Weight Test",
            rules: TipRules(
                type: .roleWeighted,
                roleWeights: ["Server": 1.0]
            ),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender") // No weight for bartender
            ]
        )
        
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 2)
        
        // Should give all to server with weight
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(johnAmount, 100.0)
        XCTAssertEqual(janeAmount, 0.0)
        XCTAssertFalse(result.warnings.isEmpty) // Should warn about missing role weight
    }
    
    // MARK: - Hybrid Rules Tests
    
    func testHybridSplit() {
        // Create a test template with hybrid rules (using hours)
        let template = TipTemplate(
            name: "Hybrid Split Test",
            rules: TipRules(
                type: .hybrid,
                formula: "hours"
            ),
            participants: [
                Participant(name: "John", role: "Server", hours: 4.0),
                Participant(name: "Sarah", role: "Server", hours: 2.0),
                Participant(name: "Jane", role: "Bartender", hours: 4.0)
            ]
        )
        
        // Test the split
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 3)
        
        // John: 4/10 = 40%, Sarah: 2/10 = 20%, Jane: 4/10 = 40%
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let sarahAmount = result.splits.first { $0.name == "Sarah" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(johnAmount, 40.0, accuracy: 0.01)
        XCTAssertEqual(sarahAmount, 20.0, accuracy: 0.01)
        XCTAssertEqual(janeAmount, 40.0, accuracy: 0.01)
        
        // Total should be correct
        let total = result.splits.reduce(0.0) { $0 + ($1.calculatedAmount ?? 0) }
        XCTAssertEqual(total, 100.0)
    }
    
    // MARK: - Off-the-Top Tests
    
    func testOffTheTopPercentages() {
        // Create a test template with off-the-top rules
        let template = TipTemplate(
            name: "Off-the-Top Test",
            rules: TipRules(
                type: .equal,
                offTheTop: [
                    OffTheTopRule(role: "Manager", percentage: 10.0)
                ]
            ),
            participants: [
                Participant(name: "Bob", role: "Manager"),
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender")
            ]
        )
        
        // Test the split
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 3)
        
        // Manager should get 10% off the top, rest split equally
        let bobAmount = result.splits.first { $0.name == "Bob" }?.calculatedAmount ?? 0
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        let janeAmount = result.splits.first { $0.name == "Jane" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(bobAmount, 10.0) // 10% off the top
        XCTAssertEqual(johnAmount, 45.0) // Equal split of remaining 90%
        XCTAssertEqual(janeAmount, 45.0) // Equal split of remaining 90%
        
        // Total should be correct
        let total = result.splits.reduce(0.0) { $0 + ($1.calculatedAmount ?? 0) }
        XCTAssertEqual(total, 100.0)
    }
    
    func testOffTheTopWithExcessivePercentages() {
        // Test with off-the-top percentages that exceed 100%
        let template = TipTemplate(
            name: "Excessive Off-the-Top Test",
            rules: TipRules(
                type: .equal,
                offTheTop: [
                    OffTheTopRule(role: "Manager", percentage: 80.0),
                    OffTheTopRule(role: "Chef", percentage: 40.0)
                ]
            ),
            participants: [
                Participant(name: "Bob", role: "Manager"),
                Participant(name: "Alice", role: "Chef"),
                Participant(name: "John", role: "Server")
            ]
        )
        
        let result = computeSplits(template: template, pool: 100.0)
        XCTAssertEqual(result.splits.count, 3)
        
        // Should normalize to 100% total
        // Manager: 80/120 = 66.67%, Chef: 40/120 = 33.33%, Server: 0%
        let bobAmount = result.splits.first { $0.name == "Bob" }?.calculatedAmount ?? 0
        let aliceAmount = result.splits.first { $0.name == "Alice" }?.calculatedAmount ?? 0
        let johnAmount = result.splits.first { $0.name == "John" }?.calculatedAmount ?? 0
        
        XCTAssertEqual(bobAmount, 66.67, accuracy: 0.01)
        XCTAssertEqual(aliceAmount, 33.33, accuracy: 0.01)
        XCTAssertEqual(johnAmount, 0.0)
        
        // Should warn about excessive percentages
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("exceeded 100%") })
    }
    
    // MARK: - Error Handling Tests
    
    func testNegativePool() {
        let template = TipTemplate(
            name: "Error Test",
            rules: TipRules(type: .equal),
            participants: [
                Participant(name: "John", role: "Server"),
                Participant(name: "Jane", role: "Bartender")
            ]
        )
        
        let result = computeSplits(template: template, pool: -100.0)
        
        // Should have an error in warnings
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("negative") })
    }
}
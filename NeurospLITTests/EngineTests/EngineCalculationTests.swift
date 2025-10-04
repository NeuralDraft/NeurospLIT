import XCTest
@testable import NeurospLIT

final class EngineCalculationTests: XCTestCase {
    
    // MARK: - Equal Split Tests
    
    func testEqualSplitBasic() {
        let template = TipTemplate(
            name: "Equal Split Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [
                Participant(name: "Alice", role: "Server"),
                Participant(name: "Bob", role: "Server"),
                Participant(name: "Charlie", role: "Server")
            ],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 300)
        
        XCTAssertEqual(result.splits.count, 3)
        for participant in result.splits {
            XCTAssertEqual(participant.calculatedAmount, 100, accuracy: 0.01, "Each participant should get 100")
        }
        XCTAssertEqual(result.warnings.count, 0, "No warnings expected for equal split")
    }
    
    func testEqualSplitWithPennyRounding() {
        let template = TipTemplate(
            name: "Penny Rounding Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [
                Participant(name: "Alice", role: "Server"),
                Participant(name: "Bob", role: "Server"),
                Participant(name: "Charlie", role: "Server")
            ],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 100)
        
        // 100 / 3 = 33.33..., so we need to handle penny rounding
        let total = result.splits.reduce(0.0) { $0 + $1.calculatedAmount }
        XCTAssertEqual(total, 100, accuracy: 0.01, "Total should equal pool amount")
        
        // At least one person gets 33.34, others get 33.33
        let amounts = result.splits.map { $0.calculatedAmount }.sorted()
        XCTAssertTrue(amounts[0] >= 33.33 && amounts[0] <= 33.34)
        XCTAssertTrue(amounts[2] >= 33.33 && amounts[2] <= 33.34)
    }
    
    // MARK: - Hours-Based Tests
    
    func testHoursBasedSplit() {
        var participants = [
            Participant(name: "Alice", role: "Server"),
            Participant(name: "Bob", role: "Server"),
            Participant(name: "Charlie", role: "Server")
        ]
        participants[0].hours = 8
        participants[1].hours = 4
        participants[2].hours = 4
        
        let template = TipTemplate(
            name: "Hours Test",
            createdDate: Date(),
            rules: TipRules(type: .hoursBased, formula: "Hours-based"),
            participants: participants,
            displayConfig: DisplayConfig(
                primaryVisualization: "bar",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 160)
        
        // Alice worked 8/16 = 50%, Bob and Charlie each 4/16 = 25%
        XCTAssertEqual(result.splits[0].calculatedAmount, 80, accuracy: 0.01, "Alice should get 80")
        XCTAssertEqual(result.splits[1].calculatedAmount, 40, accuracy: 0.01, "Bob should get 40")
        XCTAssertEqual(result.splits[2].calculatedAmount, 40, accuracy: 0.01, "Charlie should get 40")
    }
    
    func testHoursBasedWithZeroHours() {
        var participants = [
            Participant(name: "Alice", role: "Server"),
            Participant(name: "Bob", role: "Server")
        ]
        participants[0].hours = 8
        participants[1].hours = 0
        
        let template = TipTemplate(
            name: "Zero Hours Test",
            createdDate: Date(),
            rules: TipRules(type: .hoursBased, formula: "Hours-based"),
            participants: participants,
            displayConfig: DisplayConfig(
                primaryVisualization: "bar",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 100)
        
        // Person with 0 hours should get nothing
        XCTAssertEqual(result.splits[0].calculatedAmount, 100, accuracy: 0.01, "Alice should get everything")
        XCTAssertEqual(result.splits[1].calculatedAmount, 0, accuracy: 0.01, "Bob should get nothing")
    }
    
    // MARK: - Percentage Tests
    
    func testPercentageSplit() {
        var participants = [
            Participant(name: "Alice", role: "Manager"),
            Participant(name: "Bob", role: "Server"),
            Participant(name: "Charlie", role: "Busser")
        ]
        participants[0].weight = 50  // 50%
        participants[1].weight = 30  // 30%
        participants[2].weight = 20  // 20%
        
        let template = TipTemplate(
            name: "Percentage Test",
            createdDate: Date(),
            rules: TipRules(type: .percentage, formula: "Percentage"),
            participants: participants,
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 200)
        
        XCTAssertEqual(result.splits[0].calculatedAmount, 100, accuracy: 0.01, "Alice should get 100")
        XCTAssertEqual(result.splits[1].calculatedAmount, 60, accuracy: 0.01, "Bob should get 60")
        XCTAssertEqual(result.splits[2].calculatedAmount, 40, accuracy: 0.01, "Charlie should get 40")
    }
    
    // MARK: - Role-Weighted Tests
    
    func testRoleWeightedSplit() {
        let participants = [
            Participant(name: "Alice", role: "Manager"),
            Participant(name: "Bob", role: "Server"),
            Participant(name: "Charlie", role: "Server"),
            Participant(name: "Dave", role: "Busser")
        ]
        
        let template = TipTemplate(
            name: "Role Weighted Test",
            createdDate: Date(),
            rules: TipRules(
                type: .roleWeighted,
                formula: "Role-weighted",
                roleWeights: ["Manager": 2.0, "Server": 1.5, "Busser": 1.0]
            ),
            participants: participants,
            displayConfig: DisplayConfig(
                primaryVisualization: "bar",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 600)
        
        // Total weights: 2.0 + 1.5 + 1.5 + 1.0 = 6.0
        XCTAssertEqual(result.splits[0].calculatedAmount, 200, accuracy: 1, "Manager should get 200")
        XCTAssertEqual(result.splits[1].calculatedAmount, 150, accuracy: 1, "Server 1 should get 150")
        XCTAssertEqual(result.splits[2].calculatedAmount, 150, accuracy: 1, "Server 2 should get 150")
        XCTAssertEqual(result.splits[3].calculatedAmount, 100, accuracy: 1, "Busser should get 100")
    }
    
    // MARK: - Edge Cases
    
    func testNegativePoolAmount() {
        let template = TipTemplate(
            name: "Negative Pool Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [Participant(name: "Alice", role: "Server")],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: -100)
        
        // Should handle negative pool gracefully with warnings
        XCTAssertTrue(result.warnings.count > 0, "Should have warning for negative pool")
    }
    
    func testEmptyParticipants() {
        let template = TipTemplate(
            name: "Empty Participants Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 100)
        
        XCTAssertEqual(result.splits.count, 0, "Should return empty splits")
        XCTAssertTrue(result.warnings.count > 0, "Should have warning for no participants")
    }
    
    func testVeryLargePoolAmount() {
        let template = TipTemplate(
            name: "Large Pool Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [
                Participant(name: "Alice", role: "Server"),
                Participant(name: "Bob", role: "Server")
            ],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let largeAmount = 1_000_000.0
        let result = computeSplits(template: template, pool: largeAmount)
        
        XCTAssertEqual(result.splits[0].calculatedAmount, 500_000, accuracy: 0.01)
        XCTAssertEqual(result.splits[1].calculatedAmount, 500_000, accuracy: 0.01)
    }
    
    func testZeroPoolAmount() {
        let template = TipTemplate(
            name: "Zero Pool Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [
                Participant(name: "Alice", role: "Server"),
                Participant(name: "Bob", role: "Server")
            ],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 0)
        
        XCTAssertEqual(result.splits[0].calculatedAmount, 0, "Should get 0 from 0 pool")
        XCTAssertEqual(result.splits[1].calculatedAmount, 0, "Should get 0 from 0 pool")
    }
    
    // MARK: - Off-the-Top Tests
    
    func testOffTheTopCalculation() {
        let participants = [
            Participant(name: "Alice", role: "Manager"),
            Participant(name: "Bob", role: "Server"),
            Participant(name: "Charlie", role: "Busser")
        ]
        
        let template = TipTemplate(
            name: "Off-the-Top Test",
            createdDate: Date(),
            rules: TipRules(
                type: .equal,
                formula: "Equal with off-the-top",
                offTheTop: [
                    OffTheTopRule(role: "Manager", percentage: 10)
                ]
            ),
            participants: participants,
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let result = computeSplits(template: template, pool: 1000)
        
        // Manager gets 10% off the top (100) + share of remaining 900/3 = 300
        // Others get 900/3 = 300 each
        let managerAmount = result.splits[0].calculatedAmount
        XCTAssertEqual(managerAmount, 400, accuracy: 1, "Manager should get 400 (100 + 300)")
    }
}

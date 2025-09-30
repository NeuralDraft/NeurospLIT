// ValidationServiceTests.swift
// WhipTip Unit Tests

import XCTest
@testable import WhipTip

class ValidationServiceTests: XCTestCase {
    
    // MARK: - Template Name Tests
    
    func testValidateNonEmptyTemplateName() {
        // Valid name
        let result = ValidationService.validateTemplateName("Test Template")
        XCTAssertTrue(result.isSuccess)
        
        // Empty name
        let emptyResult = ValidationService.validateTemplateName("")
        XCTAssertFalse(emptyResult.isSuccess)
        
        // Whitespace only name
        let whitespaceResult = ValidationService.validateTemplateName("   ")
        XCTAssertFalse(whitespaceResult.isSuccess)
    }
    
    // MARK: - Participant Tests
    
    func testValidateAtLeastOneParticipant() {
        // Valid case - one participant
        let validResult = ValidationService.validateParticipantsDomain([Participant(name: "John", role: "Server")])
        XCTAssertTrue(validResult.isSuccess)
        
        // Valid case - multiple participants
        let multipleResult = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server"),
            Participant(name: "Jane", role: "Bartender")
        ])
        XCTAssertTrue(multipleResult.isSuccess)
        
        // Invalid case - empty participants
        let emptyResult = ValidationService.validateParticipantsDomain([])
        XCTAssertFalse(emptyResult.isSuccess)
        if case .failure(let error) = emptyResult {
            XCTAssertEqual(error, WhipCoreError.noParticipants)
        } else {
            XCTFail("Expected noParticipants error")
        }
    }
    
    func testValidateNonNegativeHoursWeights() {
        // Valid cases
        let validHours = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server", hours: 8.0)
        ])
        XCTAssertTrue(validHours.isSuccess)
        
        let validWeights = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server", weight: 1.5)
        ])
        XCTAssertTrue(validWeights.isSuccess)
        
        let validZero = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server", hours: 0)
        ])
        XCTAssertTrue(validZero.isSuccess)
        
        // Invalid cases
        let negativeHours = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server", hours: -2.0)
        ])
        XCTAssertFalse(negativeHours.isSuccess)
        if case .failure(let error) = negativeHours {
            XCTAssertEqual(error, WhipCoreError.negativeHours(participantName: "John"))
        } else {
            XCTFail("Expected negativeHours error")
        }
        
        let negativeWeights = ValidationService.validateParticipantsDomain([
            Participant(name: "John", role: "Server", weight: -1.0)
        ])
        XCTAssertFalse(negativeWeights.isSuccess)
        if case .failure(let error) = negativeWeights {
            XCTAssertEqual(error, WhipCoreError.negativeWeight(participantName: "John"))
        } else {
            XCTFail("Expected negativeWeight error")
        }
    }
    
    // MARK: - Rules Tests
    
    func testValidatePercentageBasedTotals() {
        // Test valid role weights
        let validRoleWeights = TipRules(
            type: .percentage,
            roleWeights: ["Server": 1.5, "Bartender": 2.0]
        )
        
        let validResult = ValidationService.validateRulesDomain(validRoleWeights)
        XCTAssertTrue(validResult.isSuccess)
        
        // Test invalid (negative) role weights
        let negativeRoleWeights = TipRules(
            type: .percentage,
            roleWeights: ["Server": -1.5, "Bartender": 2.0]
        )
        
        let negativeResult = ValidationService.validateRulesDomain(negativeRoleWeights)
        XCTAssertFalse(negativeResult.isSuccess)
        if case .failure(let error) = negativeResult {
            XCTAssertEqual(error, WhipCoreError.invalidRoleWeight(role: "Server", weight: -1.5))
        } else {
            XCTFail("Expected invalidRoleWeight error")
        }
        
        // Test zero total weight
        let zeroTotalWeights = TipRules(
            type: .percentage,
            roleWeights: ["Server": 0.0, "Bartender": 0.0]
        )
        
        let zeroResult = ValidationService.validateRulesDomain(zeroTotalWeights)
        XCTAssertFalse(zeroResult.isSuccess)
        if case .failure(let error) = zeroResult {
            XCTAssertEqual(error, WhipCoreError.invalidTotalWeight(total: 0.0))
        } else {
            XCTFail("Expected invalidTotalWeight error")
        }
    }
    
    func testValidateOffTheTopPercentages() {
        // Valid off-the-top rules
        let validOffTheTop = TipRules(
            type: .equal,
            offTheTop: [
                OffTheTopRule(role: "Manager", percentage: 10.0),
                OffTheTopRule(role: "Chef", percentage: 5.0)
            ]
        )
        
        let validResult = ValidationService.validateRulesDomain(validOffTheTop)
        XCTAssertTrue(validResult.isSuccess)
        
        // Invalid negative percentage
        let negativeOffTheTop = TipRules(
            type: .equal,
            offTheTop: [
                OffTheTopRule(role: "Manager", percentage: -10.0)
            ]
        )
        
        let negativeResult = ValidationService.validateRulesDomain(negativeOffTheTop)
        XCTAssertFalse(negativeResult.isSuccess)
        if case .failure(let error) = negativeResult {
            XCTAssertEqual(error, WhipCoreError.invalidOffTheTopPercentage(role: "Manager", percentage: -10.0))
        } else {
            XCTFail("Expected invalidOffTheTopPercentage error")
        }
        
        // Total exceeding 100%
        let excessiveOffTheTop = TipRules(
            type: .equal,
            offTheTop: [
                OffTheTopRule(role: "Manager", percentage: 80.0),
                OffTheTopRule(role: "Chef", percentage: 30.0)
            ]
        )
        
        let excessiveResult = ValidationService.validateRulesDomain(excessiveOffTheTop)
        XCTAssertFalse(excessiveResult.isSuccess)
        if case .failure(let error) = excessiveResult {
            XCTAssertEqual(error, WhipCoreError.invalidTotalPercentage(total: 110.0))
        } else {
            XCTFail("Expected invalidTotalPercentage error")
        }
    }
    
    // MARK: - Template Edit Tests
    
    func testValidateTemplateEdit() {
        // Valid template
        let validTemplate = ValidationService.validateTemplateEdit(
            name: "Test Template",
            participants: [
                Participant(name: "John", role: "Server", hours: 8.0),
                Participant(name: "Jane", role: "Bartender", weight: 1.5)
            ],
            rules: TipRules(type: .equal)
        )
        XCTAssertTrue(validTemplate.isSuccess)
        
        // Invalid - empty name
        let emptyName = ValidationService.validateTemplateEdit(
            name: "",
            participants: [Participant(name: "John", role: "Server")],
            rules: TipRules(type: .equal)
        )
        XCTAssertFalse(emptyName.isSuccess)
        
        // Invalid - no participants
        let noParticipants = ValidationService.validateTemplateEdit(
            name: "Test Template",
            participants: [],
            rules: TipRules(type: .equal)
        )
        XCTAssertFalse(noParticipants.isSuccess)
        
        // Invalid - negative hours
        let negativeHours = ValidationService.validateTemplateEdit(
            name: "Test Template",
            participants: [Participant(name: "John", role: "Server", hours: -2.0)],
            rules: TipRules(type: .equal)
        )
        XCTAssertFalse(negativeHours.isSuccess)
        
        // Invalid - excessive off-the-top
        let excessiveOffTheTop = ValidationService.validateTemplateEdit(
            name: "Test Template",
            participants: [Participant(name: "John", role: "Server")],
            rules: TipRules(
                type: .equal,
                offTheTop: [
                    OffTheTopRule(role: "Manager", percentage: 80.0),
                    OffTheTopRule(role: "Chef", percentage: 30.0)
                ]
            )
        )
        XCTAssertFalse(excessiveOffTheTop.isSuccess)
    }
}
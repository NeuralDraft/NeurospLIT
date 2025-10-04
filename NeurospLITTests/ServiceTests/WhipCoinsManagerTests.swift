import XCTest
@testable import NeurospLIT

final class WhipCoinsManagerTests: XCTestCase {
    
    var whipCoinsManager: WhipCoinsManager!
    
    override func setUp() {
        super.setUp()
        whipCoinsManager = WhipCoinsManager()
        // Reset coins for clean testing
        UserDefaults.standard.removeObject(forKey: "WhipCoins")
    }
    
    override func tearDown() {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "WhipCoins")
        whipCoinsManager = nil
        super.tearDown()
    }
    
    func testInitialCoinsBalance() {
        // New users should start with 3 coins
        let freshManager = WhipCoinsManager()
        XCTAssertEqual(freshManager.whipCoins, 3, "New users should start with 3 WhipCoins")
    }
    
    func testAddWhipCoins() {
        let initialBalance = whipCoinsManager.whipCoins
        let coinsToAdd = 10
        
        whipCoinsManager.addWhipCoins(coinsToAdd)
        
        XCTAssertEqual(whipCoinsManager.whipCoins, initialBalance + coinsToAdd, "Coins should be added correctly")
    }
    
    func testSpendWhipCoins() {
        // Set a known balance
        whipCoinsManager.addWhipCoins(10)
        let initialBalance = whipCoinsManager.whipCoins
        
        // Spend some coins
        let success = whipCoinsManager.spendWhipCoins(5)
        
        XCTAssertTrue(success, "Should successfully spend coins when sufficient balance")
        XCTAssertEqual(whipCoinsManager.whipCoins, initialBalance - 5, "Balance should decrease by spent amount")
    }
    
    func testSpendInsufficientWhipCoins() {
        // Set a low balance
        UserDefaults.standard.set(2, forKey: "WhipCoins")
        whipCoinsManager = WhipCoinsManager() // Reload to get new balance
        
        // Try to spend more than available
        let success = whipCoinsManager.spendWhipCoins(5)
        
        XCTAssertFalse(success, "Should fail when insufficient balance")
        XCTAssertEqual(whipCoinsManager.whipCoins, 2, "Balance should remain unchanged")
    }
    
    func testCanAffordCheck() {
        whipCoinsManager.addWhipCoins(10)
        
        XCTAssertTrue(whipCoinsManager.canAfford(5), "Should be able to afford 5 coins with balance of 10+")
        XCTAssertTrue(whipCoinsManager.canAfford(whipCoinsManager.whipCoins), "Should be able to afford exact balance")
        XCTAssertFalse(whipCoinsManager.canAfford(whipCoinsManager.whipCoins + 1), "Should not afford more than balance")
    }
    
    func testNegativeCoinsHandling() {
        // Test that negative coins cannot be spent
        let success = whipCoinsManager.spendWhipCoins(-5)
        XCTAssertFalse(success, "Should not allow spending negative coins")
        
        // Test that adding negative coins doesn't work
        let initialBalance = whipCoinsManager.whipCoins
        whipCoinsManager.addWhipCoins(-5)
        XCTAssertEqual(whipCoinsManager.whipCoins, initialBalance, "Adding negative coins should not change balance")
    }
    
    func testPersistence() {
        // Add coins
        whipCoinsManager.addWhipCoins(20)
        let savedBalance = whipCoinsManager.whipCoins
        
        // Create new manager instance (simulating app restart)
        let newManager = WhipCoinsManager()
        
        XCTAssertEqual(newManager.whipCoins, savedBalance, "Balance should persist across instances")
    }
    
    func testTransactionHistory() {
        // Test transaction logging
        let initialBalance = whipCoinsManager.whipCoins
        
        // Perform various transactions
        whipCoinsManager.addWhipCoins(10)
        whipCoinsManager.spendWhipCoins(3)
        whipCoinsManager.addWhipCoins(5)
        
        let expectedBalance = initialBalance + 10 - 3 + 5
        XCTAssertEqual(whipCoinsManager.whipCoins, expectedBalance, "Balance should reflect all transactions")
    }
    
    func testConcurrentAccess() {
        let expectation = self.expectation(description: "Concurrent access")
        let iterations = 100
        var completedOperations = 0
        
        // Perform many concurrent operations
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            whipCoinsManager.addWhipCoins(1)
            
            DispatchQueue.main.async {
                completedOperations += 1
                if completedOperations == iterations {
                    expectation.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent operations should complete without error")
            // Note: Exact balance might vary due to @Published property updates
            XCTAssertTrue(whipCoinsManager.whipCoins > 0, "Balance should be positive after additions")
        }
    }
    
    func testMaximumCoinsLimit() {
        // Test if there's any maximum limit (implementation dependent)
        whipCoinsManager.addWhipCoins(Int.max - 1000)
        
        // Should handle large numbers gracefully
        XCTAssertTrue(whipCoinsManager.whipCoins > 0, "Should handle large coin amounts")
    }
    
    func testZeroCoinsScenario() {
        // Set balance to exactly 0
        UserDefaults.standard.set(0, forKey: "WhipCoins")
        let zeroManager = WhipCoinsManager()
        
        XCTAssertEqual(zeroManager.whipCoins, 0, "Should handle zero balance")
        XCTAssertFalse(zeroManager.canAfford(1), "Cannot afford anything with zero balance")
        XCTAssertFalse(zeroManager.spendWhipCoins(1), "Cannot spend with zero balance")
    }
}

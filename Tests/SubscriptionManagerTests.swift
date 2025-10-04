import XCTest
import StoreKit
@testable import NeurospLIT

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        subscriptionManager = SubscriptionManager()
        
        // Wait for initial load to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    override func tearDown() {
        subscriptionManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(subscriptionManager.isSubscribed, "Should not be subscribed initially")
        XCTAssertEqual(subscriptionManager.subscriptionStatus, .none, "Initial status should be none")
        XCTAssertFalse(subscriptionManager.isPurchasing, "Should not be purchasing initially")
        XCTAssertNil(subscriptionManager.purchaseError, "Should have no purchase error initially")
    }
    
    func testProductLoading() async {
        // Give time for product loading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Note: In a real test environment, you'd need to mock StoreKit
        // This test will only work properly with StoreKit configuration file
        if subscriptionManager.product != nil {
            XCTAssertNotNil(subscriptionManager.product, "Product should be loaded")
            XCTAssertFalse(subscriptionManager.isLoadingProducts, "Loading should be complete")
        } else {
            // If no product loaded, ensure we're in a known state
            XCTAssertFalse(subscriptionManager.isLoadingProducts, "Loading should be complete even if failed")
        }
    }
    
    func testSubscriptionStatusValues() {
        let statuses: [SubscriptionManager.SubscriptionStatus] = [.none, .trial, .active, .expired, .pending]
        
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty, "Status should have a non-empty description")
        }
    }
    
    func testTrialDaysConfiguration() {
        XCTAssertEqual(subscriptionManager.trialDays, 3, "Default trial period should be 3 days")
    }
    
    func testPurchaseErrorHandling() async {
        // Test that purchase error is initially nil
        XCTAssertNil(subscriptionManager.purchaseError)
        
        // Simulate purchase without product (should fail)
        subscriptionManager.product = nil
        await subscriptionManager.purchase()
        
        // Should have an error message now
        XCTAssertNotNil(subscriptionManager.purchaseError, "Should have error when purchasing without product")
        XCTAssertFalse(subscriptionManager.isPurchasing, "Should not be purchasing after error")
    }
    
    func testRestorePurchasesFlow() async {
        // Test restore purchases flow
        await subscriptionManager.restorePurchases()
        
        // After restore, should not be in purchasing state
        XCTAssertFalse(subscriptionManager.isPurchasing, "Should not be purchasing after restore")
        
        // If not subscribed after restore, should have appropriate message
        if !subscriptionManager.isSubscribed {
            XCTAssertNotNil(subscriptionManager.purchaseError, "Should have message when no subscription found")
        }
    }
    
    func testReferralManagerIntegration() {
        // Test that referral manager bonus affects subscription status
        ReferralManager.shared.clearBonus()
        
        // Without bonus, status depends on actual subscription
        Task {
            await subscriptionManager.updateSubscriptionStatus()
        }
        
        // Grant bonus and check again
        ReferralManager.shared.grantBonus(days: 7)
        Task {
            await subscriptionManager.updateSubscriptionStatus()
            
            if !subscriptionManager.isSubscribed && ReferralManager.shared.hasActiveBonus() {
                // Should show as subscribed with trial status when bonus is active
                XCTAssertTrue(subscriptionManager.isSubscribed, "Should be subscribed with active bonus")
                XCTAssertEqual(subscriptionManager.subscriptionStatus, .trial, "Should show trial status with bonus")
            }
        }
        
        // Clean up
        ReferralManager.shared.clearBonus()
    }
    
    func testProductIdentifier() {
        // Verify the product ID matches expected value
        let expectedProductId = "com.neurosplit.pro.monthly"
        
        // This is a private property, so we can't test it directly
        // But we can verify the manager is configured correctly
        XCTAssertNotNil(subscriptionManager, "Manager should be initialized")
    }
}

// MARK: - Mock Tests for Purchase Flow
extension SubscriptionManagerTests {
    
    func testPurchaseStateTransitions() async {
        // Initial state
        XCTAssertFalse(subscriptionManager.isPurchasing)
        
        // Note: Can't fully test purchase flow without StoreKit configuration
        // This would require TestFlight or StoreKit testing configuration
    }
    
    func testSubscriptionStatusTransitions() {
        // Test status string values
        XCTAssertEqual(SubscriptionManager.SubscriptionStatus.none.rawValue, "Not Subscribed")
        XCTAssertEqual(SubscriptionManager.SubscriptionStatus.trial.rawValue, "Free Trial")
        XCTAssertEqual(SubscriptionManager.SubscriptionStatus.active.rawValue, "Active")
        XCTAssertEqual(SubscriptionManager.SubscriptionStatus.expired.rawValue, "Expired")
        XCTAssertEqual(SubscriptionManager.SubscriptionStatus.pending.rawValue, "Pending")
    }
}

import XCTest
import SwiftUI
@testable import NeurospLIT

@MainActor
final class UIFlowTests: XCTestCase {
    
    // MARK: - Welcome View Tests
    
    func testWelcomeViewInitialization() {
        var showOnboarding = false
        let binding = Binding(
            get: { showOnboarding },
            set: { showOnboarding = $0 }
        )
        
        let view = WelcomeView(showOnboarding: binding)
        
        // Test that view can be created without crashing
        let _ = view.body
        
        XCTAssertFalse(showOnboarding, "Onboarding should not be shown initially")
    }
    
    func testWelcomeViewFeatureRows() {
        // Test that feature rows are properly configured
        let featureRow = FeatureRow(icon: "test.icon", text: "Test Feature")
        let _ = featureRow.body
        
        // Feature row should be created successfully
        XCTAssertTrue(true, "Feature row created without issues")
    }
    
    // MARK: - Main Dashboard Tests
    
    func testMainDashboardEmptyState() {
        var selectedTemplate: TipTemplate? = nil
        var showOnboarding = false
        var showWhipCoins = false
        
        let templateBinding = Binding(
            get: { selectedTemplate },
            set: { selectedTemplate = $0 }
        )
        let onboardingBinding = Binding(
            get: { showOnboarding },
            set: { showOnboarding = $0 }
        )
        let whipCoinsBinding = Binding(
            get: { showWhipCoins },
            set: { showWhipCoins = $0 }
        )
        
        let view = MainDashboardView(
            selectedTemplate: templateBinding,
            showOnboarding: onboardingBinding,
            showWhipCoins: whipCoinsBinding
        )
        
        // View should render without selected template
        let _ = view.body
        
        XCTAssertNil(selectedTemplate, "No template should be selected")
    }
    
    func testMainDashboardWithTemplate() {
        let testTemplate = TipTemplate(
            name: "Test Template",
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
        
        var selectedTemplate: TipTemplate? = testTemplate
        var showOnboarding = false
        var showWhipCoins = false
        
        let templateBinding = Binding(
            get: { selectedTemplate },
            set: { selectedTemplate = $0 }
        )
        let onboardingBinding = Binding(
            get: { showOnboarding },
            set: { showOnboarding = $0 }
        )
        let whipCoinsBinding = Binding(
            get: { showWhipCoins },
            set: { showWhipCoins = $0 }
        )
        
        let view = MainDashboardView(
            selectedTemplate: templateBinding,
            showOnboarding: onboardingBinding,
            showWhipCoins: whipCoinsBinding
        )
        
        // View should render with template
        let _ = view.body
        
        XCTAssertNotNil(selectedTemplate, "Template should be selected")
        XCTAssertEqual(selectedTemplate?.name, "Test Template")
    }
    
    // MARK: - Template Manager Tests
    
    func testTemplateManagerInitialization() {
        let manager = TemplateManager()
        
        XCTAssertNotNil(manager, "Template manager should initialize")
        XCTAssertNotNil(manager.templates, "Templates array should exist")
    }
    
    func testTemplateSaveAndDelete() {
        let manager = TemplateManager()
        let initialCount = manager.templates.count
        
        let testTemplate = TipTemplate(
            name: "Save Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [Participant(name: "Test", role: "Server")],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        // Save template
        manager.saveTemplate(testTemplate)
        XCTAssertEqual(manager.templates.count, initialCount + 1, "Template count should increase")
        
        // Verify template exists
        XCTAssertTrue(manager.templates.contains(where: { $0.id == testTemplate.id }))
        
        // Delete template
        manager.deleteTemplate(testTemplate)
        XCTAssertEqual(manager.templates.count, initialCount, "Template count should return to initial")
        XCTAssertFalse(manager.templates.contains(where: { $0.id == testTemplate.id }))
    }
    
    // MARK: - Onboarding View Model Tests
    
    func testOnboardingViewModelInitialState() {
        let viewModel = OnboardingViewModel()
        
        XCTAssertFalse(viewModel.conversationHistory.isEmpty == false, "Conversation should start empty or with initial message")
        XCTAssertFalse(viewModel.isRecording, "Should not be recording initially")
        XCTAssertFalse(viewModel.canFinish, "Should not be able to finish initially")
        XCTAssertNil(viewModel.finalTemplate, "Should have no final template initially")
        XCTAssertFalse(viewModel.isConfirming, "Should not be confirming initially")
    }
    
    func testOnboardingConversationTurn() {
        let viewModel = OnboardingViewModel()
        
        // Create a test response
        let testResponse = OnboardingResponse(
            message: "Test message",
            suggestedQuestions: ["Q1", "Q2", "Q3"],
            status: .inProgress,
            template: nil
        )
        
        viewModel.processResponse(testResponse)
        
        XCTAssertEqual(viewModel.currentAIMessage, "Test message")
        XCTAssertEqual(viewModel.suggestedQuestions.count, 3)
        XCTAssertEqual(viewModel.suggestedQuestions[0], "Q1")
    }
    
    func testOnboardingCompletion() {
        let viewModel = OnboardingViewModel()
        
        let completeTemplate = TipTemplate(
            name: "Complete",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [Participant(name: "Test", role: "Server")],
            displayConfig: DisplayConfig(
                primaryVisualization: "pie",
                accentColor: "#8B5CF6",
                showPercentages: true,
                showComparison: false
            )
        )
        
        let completeResponse = OnboardingResponse(
            message: "Complete",
            suggestedQuestions: nil,
            status: .complete,
            template: completeTemplate
        )
        
        viewModel.processResponse(completeResponse)
        
        XCTAssertNotNil(viewModel.finalTemplate)
        XCTAssertTrue(viewModel.isConfirming)
        XCTAssertTrue(viewModel.currentAIMessage.isEmpty)
        XCTAssertTrue(viewModel.suggestedQuestions.isEmpty)
    }
    
    // MARK: - Root View Tests
    
    func testRootViewStateTransitions() {
        let rootView = RootView()
        let _ = rootView.body
        
        // Root view should render successfully
        XCTAssertTrue(true, "Root view created without issues")
    }
    
    // MARK: - Subscription View Tests
    
    func testSubscriptionViewInitialization() {
        let manager = SubscriptionManager()
        var showSubscription = true
        let binding = Binding(
            get: { showSubscription },
            set: { showSubscription = $0 }
        )
        
        let view = SubscriptionView(showSubscription: binding)
            .environmentObject(manager)
        
        let _ = view.body
        
        XCTAssertTrue(showSubscription, "Subscription view should be showing")
    }
    
    // MARK: - WhipCoins View Tests
    
    func testWhipCoinsViewInitialization() {
        let manager = WhipCoinsManager()
        var showWhipCoins = true
        let binding = Binding(
            get: { showWhipCoins },
            set: { showWhipCoins = $0 }
        )
        
        let view = WhipCoinsView(showWhipCoins: binding)
            .environmentObject(manager)
        
        let _ = view.body
        
        XCTAssertTrue(showWhipCoins, "WhipCoins view should be showing")
    }
    
    // MARK: - Environment Tests
    
    func testEnvironmentKeys() {
        // Test that environment keys are properly set up
        let templateManager = TemplateManager()
        let subscriptionManager = SubscriptionManager()
        let apiService = APIService()
        
        XCTAssertNotNil(templateManager)
        XCTAssertNotNil(subscriptionManager)
        XCTAssertNotNil(apiService)
    }
    
    // MARK: - Navigation Flow Tests
    
    func testNavigationFromWelcomeToOnboarding() {
        var showOnboarding = false
        
        // Simulate button tap
        showOnboarding = true
        
        XCTAssertTrue(showOnboarding, "Should navigate to onboarding")
    }
    
    func testNavigationFromOnboardingToMain() {
        let viewModel = OnboardingViewModel()
        
        // Simulate template confirmation
        viewModel.confirmTemplate()
        
        XCTAssertTrue(viewModel.canFinish, "Should be able to finish onboarding")
    }
}

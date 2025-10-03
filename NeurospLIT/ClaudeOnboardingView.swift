// ClaudeOnboardingView.swift
// Claude-powered onboarding experience for NeurospLIT
// Copyright © 2025 NeurospLIT. All rights reserved.

import SwiftUI
import Foundation

// MARK: - Chat Message for Claude Onboarding (different from API ChatMessage)
struct ClaudeOnboardingMessage: Identifiable, Codable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case claude = "assistant"
        case system = "system"
    }
    
    init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Template Draft State
struct TemplateDraft: Codable {
    var name: String
    var rules: TipRules
    var participants: [Participant]
    var displayConfig: DisplayConfig
    
    init() {
        self.name = "New Template"
        self.rules = TipRules(type: .equal, formula: "Equal split", offTheTop: nil, roleWeights: nil, customLogic: nil)
        self.participants = []
        self.displayConfig = DisplayConfig(
            primaryVisualization: "pie",
            accentColor: "#8B5CF6",
            showPercentages: true,
            showComparison: false
        )
    }
}

// MARK: - JSON Extraction and Decoding
struct ClaudeTemplateExtractor {
    static func extractJSON(from text: String) -> String? {
        // Look for fenced code blocks with json language identifier
        let pattern = #"```json\s*\n(.*?)\n```"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            if let jsonRange = Range(match.range(at: 1), in: text) {
                return String(text[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Fallback: look for any fenced code block
        let fallbackPattern = #"```\s*\n(.*?)\n```"#
        let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [.dotMatchesLineSeparators])
        
        if let match = fallbackRegex?.firstMatch(in: text, options: [], range: range) {
            if let jsonRange = Range(match.range(at: 1), in: text) {
                let content = String(text[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Check if it looks like JSON
                if content.hasPrefix("{") && content.hasSuffix("}") {
                    return content
                }
            }
        }
        
        return nil
    }
    
    static func decodeTemplate(from jsonString: String) -> Result<TipTemplate, TemplateDecodingError> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(.invalidData)
        }
        
        do {
            let template = try JSONDecoder().decode(TipTemplate.self, from: data)
            return .success(template)
        } catch {
            print("Template decoding error: \(error)")
            print("Raw JSON: \(jsonString)")
            return .failure(.decodingFailed(error.localizedDescription))
        }
    }
}

enum TemplateDecodingError: LocalizedError {
    case invalidData
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid JSON data"
        case .decodingFailed(let message):
            return "Failed to decode template: \(message)"
        }
    }
}

// MARK: - Claude Onboarding View Model
@MainActor
class ClaudeOnboardingViewModel: ObservableObject {
    @Published var messages: [ClaudeOnboardingMessage] = []
    @Published var currentInput: String = ""
    @Published var isProcessing: Bool = false
    @Published var templateDraft: TemplateDraft = TemplateDraft()
    @Published var errorMessage: String?
    @Published var extractedTemplate: TipTemplate?
    @Published var showUseTemplateButton: Bool = false
    
    private let claudeService: ClaudeService
    private let systemPrompt = """
    You are Claude, an AI assistant helping users create tip splitting templates for NeurospLIT. 
    
    Your role is to:
    1. Ask questions to understand their tip splitting needs
    2. Help them define participants, roles, and splitting rules
    3. Suggest appropriate tip splitting strategies
    4. When you have enough information, provide a complete template as JSON
    
    Keep responses conversational and helpful. Ask one question at a time to avoid overwhelming the user.
    Focus on understanding their specific situation: restaurant type, team structure, tip distribution preferences.
    
    When you have gathered enough information to create a complete template, provide it in the following JSON format:
    
    ```json
    {
        "name": "Template Name",
        "createdDate": "2024-01-01T00:00:00Z",
        "rules": {
            "type": "equal|hours|percentage|roleWeighted|hybrid",
            "formula": "Description or formula",
            "offTheTop": [{"role": "Role", "percentage": 10.0}],
            "roleWeights": {"role": 50.0},
            "customLogic": "Optional custom logic"
        },
        "participants": [
            {"name": "Name", "role": "Role", "hours": 8.0, "weight": 50.0}
        ],
        "displayConfig": {
            "primaryVisualization": "pie|bar|list",
            "accentColor": "#8B5CF6",
            "showPercentages": true,
            "showComparison": true
        }
    }
    ```
    """
    
    init(claudeService: ClaudeService = ClaudeService()) {
        self.claudeService = claudeService
        startConversation()
    }
    
    private func startConversation() {
        let welcomeMessage = ClaudeOnboardingMessage(
            role: .claude,
            content: "Hi! I'm Claude, and I'm here to help you create a tip splitting template. Let's start by understanding your restaurant or business. What type of establishment are you working with?"
        )
        messages.append(welcomeMessage)
    }
    
    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ClaudeOnboardingMessage(role: .user, content: currentInput)
        messages.append(userMessage)
        
        let input = currentInput
        currentInput = ""
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let claudeMessages = messages.map { 
                    ClaudeMessage(role: $0.role.rawValue, content: $0.content) 
                }
                let response = try await claudeService.sendMessage(
                    system: systemPrompt,
                    messages: claudeMessages,
                    maxTokens: 512
                )
                
                let claudeResponse = ClaudeOnboardingMessage(role: .claude, content: response)
                await MainActor.run {
                    messages.append(claudeResponse)
                    isProcessing = false
                    updateTemplateDraft(from: response)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to get response from Claude: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func updateTemplateDraft(from claudeResponse: String) {
        // First, try to extract JSON template from the response
        if let jsonString = ClaudeTemplateExtractor.extractJSON(from: claudeResponse) {
            switch ClaudeTemplateExtractor.decodeTemplate(from: jsonString) {
            case .success(let template):
                extractedTemplate = template
                showUseTemplateButton = true
                return
            case .failure(let error):
                errorMessage = error.localizedDescription
                print("Failed to extract template from JSON: \(error)")
            }
        }
        
        // Fallback to simple keyword-based template updates
        let response = claudeResponse.lowercased()
        
        if response.contains("equal") || response.contains("split equally") {
            templateDraft.rules.type = .equal
            templateDraft.rules.formula = "Equal split among all participants"
        } else if response.contains("hours") || response.contains("time") {
            templateDraft.rules.type = .hoursBased
            templateDraft.rules.formula = "Split based on hours worked"
        } else if response.contains("percentage") || response.contains("percent") {
            templateDraft.rules.type = .percentage
            templateDraft.rules.formula = "Split based on percentage of total work"
        }
        
        // Extract participant names if mentioned
        let participantKeywords = ["server", "waiter", "waitress", "bartender", "host", "manager", "cook", "chef", "busser", "runner"]
        for keyword in participantKeywords {
            if response.contains(keyword) && !templateDraft.participants.contains(where: { $0.role.lowercased().contains(keyword) }) {
                let participant = Participant(
                    name: "New \(keyword.capitalized)",
                    role: keyword.capitalized
                )
                templateDraft.participants.append(participant)
            }
        }
    }
    
    func useExtractedTemplate() {
        guard let template = extractedTemplate else { return }
        
        // Convert the extracted template to a template draft
        templateDraft.name = template.name
        templateDraft.rules = template.rules
        templateDraft.participants = template.participants
        templateDraft.displayConfig = template.displayConfig
        
        // Clear the extracted template state
        extractedTemplate = nil
        showUseTemplateButton = false
    }
    
    func resetConversation() {
        messages.removeAll()
        templateDraft = TemplateDraft()
        extractedTemplate = nil
        showUseTemplateButton = false
        startConversation()
    }
}

// MARK: - Claude Onboarding View
struct ClaudeOnboardingView: View {
    @StateObject private var viewModel: ClaudeOnboardingViewModel
    @Binding var isPresented: Bool
    @Environment(\.templateManager) private var templateManager
    
    init(isPresented: Binding<Bool>, claudeService: ClaudeService = ClaudeService()) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: ClaudeOnboardingViewModel(claudeService: claudeService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ClaudeChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isProcessing {
                                ClaudeTypingIndicatorView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Template Draft Preview
                if !viewModel.templateDraft.participants.isEmpty {
                    templateDraftPreview
                }
                
                // Use This Template Button (when JSON template is extracted)
                if viewModel.showUseTemplateButton {
                    useTemplateButton
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage, !viewModel.showUseTemplateButton {
                    errorMessageView(errorMessage)
                }
                
                // Input Section
                inputSection
            }
            .navigationTitle("Create with Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Template") {
                        saveTemplate()
                    }
                    .disabled(viewModel.templateDraft.participants.isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Let's create your tip splitting template together!")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("I'll ask you questions about your team and preferences")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var templateDraftPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template Preview")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Name: \(viewModel.templateDraft.name)")
                    .font(.subheadline)
                
                Text("Rule: \(viewModel.templateDraft.rules.formula)")
                    .font(.subheadline)
                
                if !viewModel.templateDraft.participants.isEmpty {
                    Text("Participants: \(viewModel.templateDraft.participants.map { $0.name }.joined(separator: ", "))")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var useTemplateButton: some View {
        VStack(spacing: 12) {
            if let template = viewModel.extractedTemplate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Generated Template")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name: \(template.name)")
                            .font(.subheadline)
                        
                        Text("Rule: \(template.rules.formula)")
                            .font(.subheadline)
                        
                        if !template.participants.isEmpty {
                            Text("Participants: \(template.participants.map { $0.name }.joined(separator: ", "))")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            
            Button(action: viewModel.useExtractedTemplate) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Use This Template")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Type your response...", text: $viewModel.currentInput, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: viewModel.sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func saveTemplate() {
        let template = TipTemplate(
            name: viewModel.templateDraft.name,
            createdDate: Date(),
            rules: viewModel.templateDraft.rules,
            participants: viewModel.templateDraft.participants,
            displayConfig: viewModel.templateDraft.displayConfig
        )
        
        templateManager.saveTemplate(template)
        isPresented = false
    }
}

// MARK: - Chat Bubble View
struct ClaudeChatBubbleView: View {
    let message: ClaudeOnboardingMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                userBubble
            } else {
                claudeBubble
                Spacer()
            }
        }
    }
    
    private var userBubble: some View {
        Text(message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(18)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
    }
    
    private var claudeBubble: some View {
        Text(message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(18)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
    }
}

// MARK: - Typing Indicator
struct ClaudeTypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(18)
            
            Spacer()
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Preview
#Preview {
    ClaudeOnboardingView(isPresented: .constant(true))
        .environment(\.templateManager, TemplateManager())
}
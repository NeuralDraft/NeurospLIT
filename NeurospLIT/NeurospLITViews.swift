// NeurospLITViews.swift
// UI Components and Views
// Copyright © 2025 NeurospLIT. All rights reserved.

import SwiftUI
import StoreKit

// MARK: - Onboarding Flow

struct OnboardingFlowView: View {
    @Binding var showOnboarding: Bool
    @Binding var showWhipCoins: Bool
    
    @Environment(\.apiService) private var apiService
    @Environment(\.templateManager) private var templateManager
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager
    
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var userInput = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPricingReveal = false
    @State private var currentCreditsResult: CreditsResult?
    
    var body: some View {
        VStack(spacing: 0) {
            progressBar
            
            if viewModel.isConfirming {
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
            if let result = currentCreditsResult, let template = viewModel.finalTemplate {
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
        ProgressView(value: Double(viewModel.turnNumber), total: 10)
            .tint(.purple)
            .padding()
    }
    
    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                confirmationHeader
                templateSummaryView
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
            
            Text("Here's what I understood:")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
    
    private var templateSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(
                viewModel.templateSummary.components(separatedBy: "\n"),
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
    
    private var confirmationActions: some View {
        VStack(spacing: 12) {
            Button(action: presentPricing) {
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
            
            Button(action: { viewModel.editTemplate() }) {
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
                    
                    if !viewModel.currentAIMessage.isEmpty {
                        ConversationBubble(
                            text: viewModel.currentAIMessage,
                            isUser: false,
                            timestamp: Date()
                        )
                        .id("current")
                    }
                    
                    if !viewModel.suggestedQuestions.isEmpty {
                        suggestedQuestionsView
                    }
                    
                    if isProcessing {
                        loadingIndicator
                    }
                }
                .padding()
                .onChange(of: viewModel.conversationHistory.count) { _ in
                    withAnimation {
                        proxy.scrollTo("current", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var conversationHistory: some View {
        ForEach(
            Array(viewModel.conversationHistory.enumerated()),
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
            
            ForEach(viewModel.suggestedQuestions, id: \.self) { question in
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
    
    private func submitInput() {
        guard !userInput.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let response = try await apiService.sendOnboardingMessage(
                    userInput: userInput,
                    sessionId: viewModel.sessionId,
                    turnNumber: viewModel.turnNumber
                )
                
                await MainActor.run {
                    viewModel.processResponse(response)
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
    
    private func presentPricing() {
        guard let template = viewModel.finalTemplate else { return }
        viewModel.confirmTemplate()
        
        let meta = PricingMeta(
            instructionText: viewModel.templateSummary,
            seed: UUID().uuidString
        )
        
        currentCreditsResult = PricingPolicy.calculateWhipCoins(
            template: template,
            meta: meta
        )
        
        showPricingReveal = true
    }
    
    private func handleWhipCoinsTopUp() {
        showPricingReveal = false
        showWhipCoins = true
    }
    
    private func finishOnboarding() {
        guard let template = viewModel.finalTemplate else { return }
        templateManager.saveTemplate(template)
        currentCreditsResult = nil
        showPricingReveal = false
        showOnboarding = false
    }
}

// MARK: - Onboarding View Model

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

// MARK: - Conversation Bubble

struct ConversationBubble: View {
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
            
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

// MARK: - Main Dashboard

struct MainDashboardView: View {
    @Binding var selectedTemplate: TipTemplate?
    @Binding var showOnboarding: Bool
    @Binding var showWhipCoins: Bool
    
    @Environment(\.templateManager) private var templateManager
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager
    
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
                Text("NeurospLIT")
                    .font(.title.bold())
                
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
            
            Button(action: { showWhipCoins = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "ticket")
                    Text("\(whipCoinsManager.whipCoins)")
                }
                .font(.headline)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
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
            if amount > 0 {
                showCalculation = true
            }
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
        .disabled(tipAmount.isEmpty || (Double(tipAmount) ?? 0) <= 0)
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
                
                Button(action: {
                    if whipCoinsManager.whipCoins > 0 {
                        showOnboarding = true
                    } else {
                        showWhipCoins = true
                    }
                }) {
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

// MARK: - Additional Views

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
        .onChange(of: hoursData) { _ in
            persist()
        }
    }
    
    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { hoursData[id] ?? "" },
            set: { hoursData[id] = $0 }
        )
    }
    
    private func persist() {
        for participant in template.participants {
            if let value = Double(hoursData[participant.id.uuidString] ?? "") {
                HoursStore.shared.set(id: participant.id, hours: value)
            }
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
            Text(tipAmount, format: .currency(code: "USD"))
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
    
    private var splitsSection: some View {
        VStack(spacing: 12) {
            ForEach(calculatedSplits) { split in
                SplitCard(participant: split)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
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

struct SplitCard: View {
    let participant: Participant
    
    var body: some View {
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
                Text(participant.calculatedAmount ?? 0, format: .currency(code: "USD"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                if let weight = participant.weight {
                    Text("\(Int(weight))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if let hours = participant.hours {
                    Text(hours.formatted(.number.precision(.fractionLength(1))) + " hrs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
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
        var csv = "Name,Role,Amount\n"
        for split in splits {
            let amount = (split.calculatedAmount ?? 0).currencyFormatted()
            csv += "\(split.name),\(split.role),\(amount)\n"
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
            let fileNameBase = "NeurospLIT_\(UInt(Date().timeIntervalSince1970))"
            let tempDir = FileManager.default.temporaryDirectory
            do {
                switch exportFormat {
                case .csv:
                    let url = tempDir.appendingPathComponent("\(fileNameBase).csv")
                    try generateCSV().write(to: url, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        exportedFileURL = url
                        showShareSheet = true
                        isExporting = false
                    }
                case .text:
                    let url = tempDir.appendingPathComponent("\(fileNameBase).txt")
                    try generateText().write(to: url, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        exportedFileURL = url
                        showShareSheet = true
                        isExporting = false
                    }
                case .pdf:
                    // PDF generation would go here
                    await MainActor.run {
                        isExporting = false
                    }
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

// MARK: - WhipCoins & Pricing

struct WhipCoinsView: View {
    @EnvironmentObject var whipCoinsManager: WhipCoinsManager
    @Binding var showWhipCoins: Bool
    
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let productIDs = [
        "com.neurosplit.starter",
        "com.neurosplit.standard",
        "com.neurosplit.pro"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Top Up Your WhipCoins! ⚡")
                .font(.largeTitle).bold()
            
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                ForEach(products) { product in
                    Button(action: { purchase(product) }) {
                        VStack {
                            Text(product.displayName)
                            Text(product.displayPrice)
                            Text(getCreditsDescription(for: product))
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            
            Button("Close") {
                showWhipCoins = false
            }
        }
        .padding()
        .onAppear(perform: loadProducts)
    }
    
    private func loadProducts() {
        Task {
            do {
                let fetched = try await Product.products(for: productIDs)
                await MainActor.run {
                    products = fetched
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load products: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func purchase(_ product: Product) {
        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    if case .verified(let transaction) = verification {
                        let coins = getCreditsAmount(for: product)
                        await MainActor.run { whipCoinsManager.addWhipCoins(coins) }
                        await transaction.finish()
                        await MainActor.run { showWhipCoins = false }
                    }
                default: break
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Purchase failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getCreditsAmount(for product: Product) -> Int {
        switch product.id {
        case "com.neurosplit.starter": return 500
        case "com.neurosplit.standard": return 1100
        case "com.neurosplit.pro": return 2400
        default: return 0
        }
    }
    
    private func getCreditsDescription(for product: Product) -> String {
        "\(getCreditsAmount(for: product)) WhipCoins"
    }
}

struct PricingRevealView: View {
    let creditsResult: CreditsResult
    let template: TipTemplate
    let onCollected: () -> Void
    let onNeedWhipCoins: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var whipCoinsManager: WhipCoinsManager
    
    @State private var revealedItems: [Int] = []
    @State private var showFinalPrice = false
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Analyzing your rules…")
                .font(.headline)
                .padding()
            
            ForEach(creditsResult.breakdown.indices, id: \.self) { index in
                if revealedItems.contains(index) {
                    let item = creditsResult.breakdown[index]
                    let sign = item.deltaWhipCoins > 0 ? "+" : ""
                    Text("\(item.label): \(sign)\(item.deltaWhipCoins) WhipCoins")
                        .font(.body)
                        .transition(.opacity.combined(with: .slide))
                }
            }
            
            if showFinalPrice {
                VStack {
                    Text("Your fair price is \(creditsResult.whipCoins) WhipCoins")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                        .scaleEffect(showFinalPrice ? 1.1 : 0.9)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showFinalPrice)
                    
                    HStack {
                        ForEach(0..<5) { _ in
                            Text("🎉")
                                .font(.title)
                                .offset(y: showFinalPrice ? -20 : 0)
                                .opacity(showFinalPrice ? 0 : 1)
                                .animation(
                                    .easeOut(duration: 1.0)
                                    .delay(Double.random(in: 0...0.5)),
                                    value: showFinalPrice
                                )
                        }
                    }
                }
                .transition(.scale)
            }
            
            if showFinalPrice {
                Button(action: collectTemplate) {
                    Text("🎉 Collect Template")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .transition(.opacity)
            }
        }
        .padding()
        .onAppear(perform: revealNext)
    }
    
    private func revealNext() {
        if currentIndex < creditsResult.breakdown.count {
            withAnimation(.easeIn(duration: 0.5)) {
                revealedItems.append(currentIndex)
            }
            currentIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                revealNext()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring()) {
                    showFinalPrice = true
                }
            }
        }
    }
    
    private func collectTemplate() {
        if whipCoinsManager.consumeWhipCoins(creditsResult.whipCoins) {
            onCollected()
            dismiss()
        } else {
            onNeedWhipCoins()
            dismiss()
        }
    }
}

// MARK: - Credentials View

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
                
                Section(footer: Text("Your key is stored locally and used only for API calls.")) {
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
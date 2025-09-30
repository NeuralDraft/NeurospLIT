// CalculationView.swift
// WhipTip Views

import SwiftUI

// [SECTION: views]
// [SUBSECTION: calculation]

// [ENTITY: CalculationView]
// Main view for calculating tip splits
struct CalculationView: View {
    @ObservedObject var templateService: TemplateService
    @ObservedObject var historyService: HistoryService
    @State private var selectedTemplateId: UUID?
    @State private var tipAmount: String = ""
    @State private var showingResults = false
    @State private var calculationResult: TipSplitResult?
    @State private var totalAmount: String = ""
    @State private var tipPercentage: Double = 18.0
    @State private var showingSettings = false
    
    // [FEATURE: body]
    var body: some View {
        VStack {
            if templateService.templates.isEmpty {
                emptyStateView
            } else {
                calculationForm
            }
        }
        .navigationTitle("Calculate Split")
        .sheet(isPresented: $showingResults) {
            if let result = calculationResult, let template = getSelectedTemplate() {
                CalculationResultView(
                    result: result,
                    template: template,
                    tipAmount: Double(tipAmount) ?? 0,
                    historyService: historyService,
                    onDismiss: {
                        showingResults = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
            })
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
    }
    
    // [VIEW: empty_state]
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Templates")
                .font(.title)
            
            Text("Create a template to start calculating tip splits")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            NavigationLink(destination: TemplateListView(templateService: templateService)) {
                Text("Go to Templates")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    // [VIEW: calculation_form]
    private var calculationForm: some View {
        Form {
            // Template selection
            Section(header: Text("Template")) {
                Picker("Select Template", selection: $selectedTemplateId) {
                    ForEach(templateService.templates) { template in
                        Text(template.name).tag(Optional(template.id))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onAppear {
                    if selectedTemplateId == nil && !templateService.templates.isEmpty {
                        selectedTemplateId = templateService.templates[0].id
                    }
                }
                
                if let template = getSelectedTemplate() {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(template.rules.type.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Participants")
                        Spacer()
                        Text("\(template.participants.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Amount entry
            Section(header: Text("Amounts")) {
                // Bill total with calculated tip
                HStack {
                    Text("Bill Total")
                    Spacer()
                    TextField("0.00", text: $totalAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: totalAmount) { newValue in
                            updateTipFromTotal()
                        }
                }
                
                // Tip percentage selector
                HStack {
                    Text("Tip Percentage")
                    Spacer()
                    Text("\(Int(tipPercentage))%")
                }
                
                Slider(value: $tipPercentage, in: 0...30, step: 1)
                    .onChange(of: tipPercentage) { newValue in
                        updateTipFromPercentage()
                    }
                
                // Tip amount with direct entry
                HStack {
                    Text("Tip Amount")
                    Spacer()
                    TextField("0.00", text: $tipAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: tipAmount) { newValue in
                            updatePercentageFromTip()
                        }
                }
            }
            
            // Calculate button
            Section {
                Button(action: calculateSplit) {
                    Text("Calculate Split")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .disabled(selectedTemplateId == nil || (Double(tipAmount) ?? 0) <= 0)
            }
        }
    }
    
    // [HELPER: get_selected_template]
    private func getSelectedTemplate() -> TipTemplate? {
        guard let id = selectedTemplateId else { return nil }
        return templateService.getTemplate(byId: id)
    }
    
    // [HELPER: update_tip_from_total]
    private func updateTipFromTotal() {
        guard let billTotal = Double(totalAmount) else { return }
        let calculatedTip = billTotal * (tipPercentage / 100.0)
        tipAmount = String(format: "%.2f", calculatedTip)
    }
    
    // [HELPER: update_tip_from_percentage]
    private func updateTipFromPercentage() {
        guard let billTotal = Double(totalAmount) else { return }
        let calculatedTip = billTotal * (tipPercentage / 100.0)
        tipAmount = String(format: "%.2f", calculatedTip)
    }
    
    // [HELPER: update_percentage_from_tip]
    private func updatePercentageFromTip() {
        guard let tipValue = Double(tipAmount), let billTotal = Double(totalAmount), billTotal > 0 else { return }
        let calculatedPercentage = (tipValue / billTotal) * 100.0
        if calculatedPercentage.isFinite {
            tipPercentage = min(calculatedPercentage, 100.0)
        }
    }
    
    // [HELPER: calculate_split]
    private func calculateSplit() {
        guard let template = getSelectedTemplate(),
              let tipValue = Double(tipAmount),
              tipValue > 0 else { return }
        
        let result = TipSplitService.calculateSplits(template: template, tipAmount: tipValue)
        calculationResult = result
        showingResults = true
        
        // Save to history
        historyService.addCalculation(template: template, tipAmount: tipValue, result: result)
    }
}

// [ENTITY: SettingsView]
// View for app settings
struct SettingsView: View {
    let onDismiss: () -> Void
    @State private var defaultTipPercentage: Double = UserDefaults.standard.double(forKey: "defaultTipPercentage")
    @State private var currencyCode: String = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
    @State private var showNicknames: Bool = UserDefaults.standard.bool(forKey: "showNicknames")
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Defaults")) {
                    HStack {
                        Text("Default Tip %")
                        Spacer()
                        TextField("18.0", value: $defaultTipPercentage, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Text("%")
                    }
                    
                    Picker("Currency", selection: $currencyCode) {
                        Text("USD - $").tag("USD")
                        Text("EUR - €").tag("EUR")
                        Text("GBP - £").tag("GBP")
                        Text("CAD - $").tag("CAD")
                        Text("AUD - $").tag("AUD")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Display")) {
                    Toggle("Show Nicknames", isOn: $showNicknames)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(defaultTipPercentage, forKey: "defaultTipPercentage")
        UserDefaults.standard.set(currencyCode, forKey: "currencyCode")
        UserDefaults.standard.set(showNicknames, forKey: "showNicknames")
    }
}
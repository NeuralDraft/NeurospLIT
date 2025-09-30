// CalculationResultView.swift
// WhipTip Views

import SwiftUI

// [SECTION: views]
// [SUBSECTION: results]

// [ENTITY: CalculationResultView]
// Displays the result of a tip split calculation
struct CalculationResultView: View {
    let result: TipSplitResult
    let template: TipTemplate
    let tipAmount: Double
    let historyService: HistoryService
    let onDismiss: () -> Void
    @State private var showingShareSheet = false
    @State private var shareText: String = ""
    
    // [FEATURE: body]
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Template")
                        Spacer()
                        Text(template.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Tip")
                        Spacer()
                        Text(formatCurrency(tipAmount))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Split Type")
                        Spacer()
                        Text(template.rules.type.description)
                            .foregroundColor(.secondary)
                    }
                    
                    if !result.warnings.isEmpty {
                        NavigationLink(destination: WarningsView(warnings: result.warnings)) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("View Warnings")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // Results section
                Section(header: Text("Split Results")) {
                    ForEach(result.splits, id: \.id) { split in
                        SplitRowView(split: split)
                    }
                }
                
                // Actions section
                Section {
                    Button(action: {
                        prepareShareText()
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Results")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Close")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Calculation Results")
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }
    
    // [HELPER: format_currency]
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    // [HELPER: prepare_share]
    private func prepareShareText() {
        var text = "Tip Split Results\n\n"
        text += "Template: \(template.name)\n"
        text += "Total Tip: \(formatCurrency(tipAmount))\n"
        text += "Split Type: \(template.rules.type.description)\n\n"
        
        for split in result.splits {
            text += "\(split.name) (\(split.role)): \(formatCurrency(split.calculatedAmount ?? 0))\n"
        }
        
        text += "\nCalculated with WhipTip"
        shareText = text
    }
}

// [ENTITY: SplitRowView]
// Displays a single tip split result row
struct SplitRowView: View {
    let split: TipSplit
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(split.name)
                    .font(.headline)
                Text(split.role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let amount = split.calculatedAmount {
                Text(formatCurrency(amount))
                    .fontWeight(.semibold)
            } else {
                Text("N/A")
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// [ENTITY: WarningsView]
// View for displaying calculation warnings
struct WarningsView: View {
    let warnings: [String]
    
    var body: some View {
        List {
            ForEach(warnings, id: \.self) { warning in
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(warning)
                }
            }
        }
        .navigationTitle("Warnings")
    }
}

// [ENTITY: ShareSheet]
// Wrapper for UIKit activity view controller
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {
        // Nothing to do here
    }
}
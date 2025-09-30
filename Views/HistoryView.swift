// HistoryView.swift
// WhipTip Views

import SwiftUI

// [SECTION: views]
// [SUBSECTION: history]

// [ENTITY: HistoryView]
// View for browsing calculation history
struct HistoryView: View {
    @ObservedObject var historyService: HistoryService
    @State private var showingClearConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportText = ""
    @State private var selectedEntry: TipCalculationHistory?
    @State private var showingDetail = false
    
    // [FEATURE: body]
    var body: some View {
        VStack {
            if historyService.history.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        exportText = historyService.exportHistoryCSV()
                        showingExportSheet = true
                    }) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: {
                        showingClearConfirmation = true
                    }) {
                        Label("Clear History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(historyService.history.isEmpty)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            NavigationView {
                VStack {
                    ScrollView {
                        Text(exportText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = exportText
                        showingExportSheet = false
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
                .navigationTitle("Export Data")
                .navigationBarItems(trailing: Button("Done") {
                    showingExportSheet = false
                })
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let entry = selectedEntry {
                HistoryDetailView(entry: entry, onDismiss: {
                    showingDetail = false
                })
            }
        }
        .alert("Clear History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                historyService.clearHistory()
            }
        } message: {
            Text("This will permanently delete all calculation history. This action cannot be undone.")
        }
    }
    
    // [VIEW: empty_state]
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No History")
                .font(.title)
            
            Text("Your tip split calculations will appear here")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // [VIEW: history_list]
    private var historyList: some View {
        List {
            ForEach(historyService.history) { entry in
                Button(action: {
                    selectedEntry = entry
                    showingDetail = true
                }) {
                    HistoryRowView(entry: entry)
                }
            }
            .onDelete(perform: deleteEntries)
        }
    }
    
    // [HELPER: delete_entries]
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = historyService.history[index]
            historyService.deleteEntry(withId: entry.id)
        }
    }
}

// [ENTITY: HistoryRowView]
// Row displaying a history entry summary
struct HistoryRowView: View {
    let entry: TipCalculationHistory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.templateName)
                    .font(.headline)
                
                Text(formatDate(entry.calculationTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(formatCurrency(entry.tipAmount))
                    .fontWeight(.semibold)
                
                Text("\(entry.participants) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
    
    // [HELPER: format_date]
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // [HELPER: format_currency]
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// [ENTITY: HistoryDetailView]
// Detailed view of a history entry
struct HistoryDetailView: View {
    let entry: TipCalculationHistory
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Template")
                        Spacer()
                        Text(entry.templateName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formatDate(entry.calculationTime))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Tip")
                        Spacer()
                        Text(formatCurrency(entry.tipAmount))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Split Type")
                        Spacer()
                        Text(entry.splitType.description)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Split Results")) {
                    ForEach(entry.splits, id: \.id) { split in
                        SplitRowView(split: split)
                    }
                }
                
                Section {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Close")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("History Details")
        }
    }
    
    // [HELPER: format_date]
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // [HELPER: format_currency]
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
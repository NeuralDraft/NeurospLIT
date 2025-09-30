import SwiftUI

// SHIFT: View to display the list of shift logs
struct ShiftHistoryView: View {
    @ObservedObject var shiftLogManager = ShiftLogManager.shared
    @State private var showingShiftDetail: ShiftLog? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if shiftLogManager.shiftLogs.isEmpty {
                    // SHIFT: Empty state view
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 72))
                            .foregroundColor(.secondary)
                        
                        Text("No Shifts Recorded")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Complete a tip calculation to automatically record shifts.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // SHIFT: List of shift logs
                    List {
                        ForEach(shiftLogManager.shiftLogs) { log in
                            Button(action: {
                                showingShiftDetail = log
                            }) {
                                ShiftLogRowView(shiftLog: log)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let logToDelete = shiftLogManager.shiftLogs[index]
                                shiftLogManager.deleteShiftLog(logToDelete)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Shift History")
            .toolbar {
                if !shiftLogManager.shiftLogs.isEmpty {
                    EditButton()
                }
            }
            .sheet(item: $showingShiftDetail) { log in
                ShiftDetailView(shiftLog: log)
            }
        }
    }
}

// SHIFT: Row view for each shift in the history list
struct ShiftLogRowView: View {
    let shiftLog: ShiftLog
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shiftLog.templateName)
                    .font(.headline)
                
                HStack {
                    Text(shiftLog.date.relativeDateString())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(shiftLog.date.formattedTime())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if shiftLog.notes != nil && !(shiftLog.notes?.isEmpty ?? true) {
                    Text("Has notes")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(format: "$%.2f", shiftLog.totalPool))
                    .font(.headline)
                
                Text("\(shiftLog.participants.count) staff")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
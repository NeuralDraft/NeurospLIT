import SwiftUI
import UIKit

// SHIFT: View to display details of a specific shift
struct ShiftDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var shiftLogManager = ShiftLogManager.shared
    
    let shiftLog: ShiftLog
    @State private var notes: String
    @State private var isEditingNotes = false
    @State private var showingDeleteConfirmation = false
    
    // SHIFT: Format currency with proper locale
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        return formatter
    }()
    
    // SHIFT: Date formatter for header
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(shiftLog: ShiftLog) {
        self.shiftLog = shiftLog
        _notes = State(initialValue: shiftLog.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // SHIFT: Header section
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shiftLog.templateName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(dateFormatter.string(from: shiftLog.date))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // SHIFT: Summary section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Text("Total Pool")
                            Spacer()
                            Text(currencyFormatter.string(from: NSNumber(value: shiftLog.totalPool)) ?? "$\(shiftLog.totalPool)")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // SHIFT: Participants section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(shiftLog.participants) { participant in
                            HStack {
                                Text(participant.emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(participant.color.opacity(0.2))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text(participant.name)
                                        .fontWeight(.medium)
                                    Text(participant.role)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let amount = participant.calculatedAmount {
                                    Text(currencyFormatter.string(from: NSNumber(value: amount)) ?? "")
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    
                    // SHIFT: Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditingNotes.toggle()
                            }) {
                                Text(isEditingNotes ? "Done" : "Edit")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if isEditingNotes {
                            // SHIFT: Editable notes
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Done") {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                                           to: nil, from: nil, for: nil)
                                            saveNotes()
                                        }
                                    }
                                }
                        } else {
                            // SHIFT: Display notes or placeholder
                            Text(notes.isEmpty ? "No notes added" : notes)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .foregroundColor(notes.isEmpty ? .secondary : .primary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Shift Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isEditingNotes {
                            saveNotes()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Shift", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteShift()
                }
            } message: {
                Text("Are you sure you want to delete this shift record? This action cannot be undone.")
            }
        }
    }
    
    // SHIFT: Save updated notes
    private func saveNotes() {
        isEditingNotes = false
        
        var updatedShiftLog = shiftLog
        updatedShiftLog.notes = notes.isEmpty ? nil : notes
        
        shiftLogManager.updateShiftLog(updatedShiftLog)
    }
    
    // SHIFT: Delete the shift record
    private func deleteShift() {
        shiftLogManager.deleteShiftLog(shiftLog)
        presentationMode.wrappedValue.dismiss()
    }
}

// SHIFT: Preview provider
struct ShiftDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockParticipants = [
            Participant(name: "John", role: "Server", calculatedAmount: 45.60),
            Participant(name: "Sarah", role: "Bartender", calculatedAmount: 32.40)
        ]
        
        let mockShift = ShiftLog(
            date: Date(),
            templateName: "Evening Shift",
            templateId: UUID(),
            totalPool: 78.00,
            participants: mockParticipants,
            notes: "Great shift! Everyone worked well together."
        )
        
        return ShiftDetailView(shiftLog: mockShift)
    }
}
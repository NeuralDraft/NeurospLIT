import SwiftUI
import UIKit

// LIFECYCLE: Created new view for editing templates
struct TemplateEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var templateManager: TemplateManager
    
    @State private var templateName: String
    @State private var participants: [Participant]
    @State private var rules: TipRules
    @State private var displayConfig: DisplayConfig
    
    private var originalTemplate: TipTemplate
    @State private var showingSaveOptions = false
    @State private var showingSaveConfirmation = false
    
    // LIFECYCLE-UI: Added validation state variables
    @State private var nameError: String? = nil
    @State private var participantsError: String? = nil
    @State private var hoursError: String? = nil
    @State private var percentageError: String? = nil
    
    // LIFECYCLE: Pass original template as reference
    init(template: TipTemplate, templateManager: TemplateManager) {
        self.originalTemplate = template
        self.templateManager = templateManager
        
        // Initialize state properties with template values
        _templateName = State(initialValue: template.name)
        _participants = State(initialValue: template.participants)
        _rules = State(initialValue: template.rules)
        _displayConfig = State(initialValue: template.displayConfig)
    }
    
    // LIFECYCLE-UI: Computed property for validation status
    private var isValid: Bool {
        // Validate template has a name
        guard !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nameError = "Template name is required"
            return false
        }
        nameError = nil
        
        // Validate at least one participant exists
        guard !participants.isEmpty else {
            participantsError = "At least one participant is required"
            return false
        }
        participantsError = nil
        
        // Validate hours/weights are not negative
        let negativeHours = participants.filter { $0.hours != nil && $0.hours! < 0 }
        if !negativeHours.isEmpty {
            hoursError = "Hours cannot be negative"
            return false
        }
        hoursError = nil
        
        // Validate percentages if present
        if rules.type == .percentage {
            let participantsWithPercentage = participants.filter { $0.percentage != nil }
            let totalPercentage = participantsWithPercentage.reduce(0) { $0 + ($1.percentage ?? 0) }
            if totalPercentage > 100.0 {
                percentageError = "Total percentage exceeds 100%"
                return false
            }
        }
        percentageError = nil
        
        return true
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // LIFECYCLE-UI: Enhanced template name section with validation
                VStack(alignment: .leading, spacing: 4) {
                    Text("Template Name")
                        .font(.headline)
                    
                    TextField("Enter template name", text: $templateName)
                        .padding()
                        .background(nameError != nil ? Color.red.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(nameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }
                
                // LIFECYCLE-UI: Enhanced participants section with validation
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Participants")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: addNewParticipant) {
                            Label("Add Participant", systemImage: "plus")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if let error = participantsError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.bottom, 4)
                    }
                    
                    if participants.isEmpty {
                        HStack {
                            Spacer()
                            Text("No participants added yet")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else {
                        ForEach(0..<participants.count, id: \.self) { index in
                            ParticipantEditRow(
                                participant: $participants[index],
                                onDelete: {
                                    participants.remove(at: index)
                                }
                            )
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            participants.remove(atOffsets: indexSet)
                        }
                    }
                    
                    if let error = hoursError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical)
                
                // Rules Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Distribution Rules")
                        .font(.headline)
                    
                    Picker("Rule Type", selection: $rules.type) {
                        Text("Equal").tag(TipRuleType.equal)
                        Text("Role-Based").tag(TipRuleType.roleWeighted)
                        Text("Hours-Based").tag(TipRuleType.hoursBased)
                        Text("Percentage").tag(TipRuleType.percentage)
                        Text("Custom").tag(TipRuleType.custom)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom)
                    
                    if rules.type == .roleWeighted {
                        VStack(alignment: .leading) {
                            Text("Role Weights")
                                .font(.subheadline)
                            
                            // Dynamic UI for role weights would go here
                            // For simplicity, we're not implementing the full UI for each rule type
                            Text("Configure role-specific weights")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if rules.type == .percentage {
                        VStack(alignment: .leading) {
                            Text("Percentage Allocations")
                                .font(.subheadline)
                            
                            // Dynamic UI for percentages would go here
                            Text("Set percentage allocations for each participant")
                                .foregroundColor(.secondary)
                                
                            // LIFECYCLE-UI: Added validation for percentages
                            if let error = percentageError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.vertical)
                
                // Display Configuration
                VStack(alignment: .leading, spacing: 10) {
                    Text("Display Settings")
                        .font(.headline)
                    
                    Toggle("Show Hours", isOn: $displayConfig.showHours)
                    Toggle("Show Role", isOn: $displayConfig.showRole)
                    Toggle("Show Percentages", isOn: $displayConfig.showPercentages)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // LIFECYCLE-UI: Updated save button with validation
                Button(action: {
                    if isValid {
                        showingSaveOptions = true
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Changes")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isValid)
            }
            .padding()
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                // LIFECYCLE-UI: Add keyboard toolbar
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .actionSheet(isPresented: $showingSaveOptions) {
                ActionSheet(
                    title: Text("Save Changes"),
                    message: Text("Do you want to update the current template or save as a new one?"),
                    buttons: [
                        .default(Text("Update Current")) {
                            saveChanges(asNew: false)
                        },
                        .default(Text("Save as New")) {
                            saveChanges(asNew: true)
                        },
                        .cancel()
                    ]
                )
            }
            .alert(isPresented: $showingSaveConfirmation) {
                Alert(
                    title: Text("Changes Saved"),
                    message: Text("Your template has been updated."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    // LIFECYCLE: Add new participant with default values
    private func addNewParticipant() {
        let newParticipant = Participant(
            id: UUID(),
            name: "New Staff",
            role: "Server",
            emoji: "👤",
            color: Color(hex: "6C8EAD"),
            hours: 8.0,
            percentage: 0.0
        )
        participants.append(newParticipant)
    }
    
    // LIFECYCLE-UI: Enhanced save changes method with validation
    private func saveChanges(asNew: Bool) {
        // Validate before saving
        guard isValid else { return }
        
        let updatedTemplate = TipTemplate(
            id: asNew ? UUID() : originalTemplate.id,
            name: asNew ? "Copy of \(templateName)" : templateName,
            createdDate: asNew ? Date() : originalTemplate.createdDate,
            lastEditedDate: Date(), // Always set last edited date to now
            rules: rules,
            participants: participants,
            displayConfig: displayConfig
        )
        
        if asNew {
            templateManager.saveTemplate(updatedTemplate)
        } else {
            templateManager.updateTemplate(updatedTemplate)
        }
        
        showingSaveConfirmation = true
    }
}

// LIFECYCLE: Component for editing individual participants
struct ParticipantEditRow: View {
    @Binding var participant: Participant
    var onDelete: () -> Void
    
    private let roleOptions = ["Server", "Bartender", "Host", "Busser", "Manager", "Chef", "Runner"]
    private let emojiOptions = ["👤", "👨‍🍳", "👩‍🍳", "🤵", "👩‍🔧", "👨‍🔧", "🧑‍🔬"]
    private let colorOptions = ["6C8EAD", "A3C9A8", "FFD275", "FF8C42", "F96E46", "9C89B8", "F0A6CA"]
    
    @State private var showingEmojiPicker = false
    @State private var showingColorPicker = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { showingEmojiPicker.toggle() }) {
                    Text(participant.emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(participant.color)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading) {
                    TextField("Enter staff name", text: $participant.name)
                        .font(.headline)
                    
                    HStack {
                        Text("Role:")
                            .foregroundColor(.secondary)
                        Picker("Role", selection: $participant.role) {
                            ForEach(roleOptions, id: \.self) { role in
                                Text(role).tag(role)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        // LIFECYCLE-UI: Added hours field with validation
                        Spacer()
                        Text("Hours:")
                            .foregroundColor(.secondary)
                        TextField("Hours", value: $participant.hours, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if showingEmojiPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: {
                                participant.emojiOverride = emoji
                                showingEmojiPicker = false
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .padding(8)
                                    .background(participant.emoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if showingColorPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(colorOptions, id: \.self) { colorHex in
                            let color = Color(hex: colorHex)
                            Button(action: {
                                participant.color = color
                                showingColorPicker = false
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(participant.colorHex == colorHex ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#if DEBUG
// LIFECYCLE: Preview provider
struct TemplateEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TemplateEditView(
                template: TipTemplate(
                    name: "Sample Template",
                    createdDate: Date(),
                    rules: TipRules(type: .equal, values: [:]),
                    participants: [
                        Participant(name: "John", role: "Server", emoji: "👨‍🍳", color: Color.blue),
                        Participant(name: "Sarah", role: "Bartender", emoji: "👩‍🔧", color: Color.green)
                    ],
                    displayConfig: DisplayConfig()
                ),
                templateManager: TemplateManager.shared
            )
        }
    }
}
#endif
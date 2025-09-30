// TemplateDetailView.swift
// WhipTip Views

import SwiftUI

// [SECTION: views]
// [SUBSECTION: templates]

// [ENTITY: TemplateDetailView]
// View for editing a tip template
struct TemplateDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var templateService: TemplateService
    @State private var workingTemplate: TipTemplate
    @State private var showingParticipantEditor = false
    @State private var showingRulesEditor = false
    @State private var validationMessage: String?
    @State private var showingValidationAlert = false
    @State private var selectedParticipantIndex: Int?
    private var isNewTemplate: Bool
    
    // [FEATURE: initialization]
    init(template: TipTemplate, templateService: TemplateService, isNewTemplate: Bool = false) {
        self.templateService = templateService
        self._workingTemplate = State(initialValue: template)
        self.isNewTemplate = isNewTemplate
    }
    
    // [FEATURE: body]
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Template Name", text: $workingTemplate.name)
                
                HStack {
                    Text("Split Type")
                    Spacer()
                    Text(workingTemplate.rules.type.description)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingRulesEditor = true
                }
            }
            
            Section(header: Text("Participants")) {
                ForEach(Array(workingTemplate.participants.enumerated()), id: \.element.id) { index, participant in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(participant.name)
                                .font(.headline)
                            Text(participant.role)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if workingTemplate.rules.type == .percentage {
                            Text("\(participant.weight ?? 0, specifier: "%.1f")%")
                        } else if workingTemplate.rules.type == .hoursBased {
                            Text("\(participant.hours ?? 0, specifier: "%.1f") hrs")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedParticipantIndex = index
                        showingParticipantEditor = true
                    }
                }
                .onDelete(perform: deleteParticipant)
                
                Button(action: addParticipant) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Participant")
                    }
                }
            }
            
            if workingTemplate.rules.type == .roleWeighted {
                Section(header: Text("Role Weights")) {
                    ForEach(Array(workingTemplate.rules.roleWeights.keys.sorted()), id: \.self) { role in
                        HStack {
                            Text(role)
                            Spacer()
                            Text("\(workingTemplate.rules.roleWeights[role] ?? 0, specifier: "%.1f")")
                        }
                    }
                }
            }
            
            if let offTheTop = workingTemplate.rules.offTheTop, !offTheTop.isEmpty {
                Section(header: Text("Off-the-Top Rules")) {
                    ForEach(offTheTop, id: \.role) { rule in
                        HStack {
                            Text(rule.role)
                            Spacer()
                            Text("\(rule.percentage, specifier: "%.1f")%")
                        }
                    }
                }
            }
        }
        .navigationTitle(isNewTemplate ? "New Template" : "Edit Template")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveTemplate()
                }
            }
        }
        .sheet(isPresented: $showingParticipantEditor) {
            if let index = selectedParticipantIndex {
                ParticipantEditorView(
                    participant: $workingTemplate.participants[index],
                    ruleType: workingTemplate.rules.type,
                    onSave: { updatedParticipant in
                        workingTemplate.participants[index] = updatedParticipant
                        showingParticipantEditor = false
                    },
                    onCancel: {
                        showingParticipantEditor = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingRulesEditor) {
            RulesEditorView(
                rules: $workingTemplate.rules,
                onSave: { updatedRules in
                    workingTemplate.rules = updatedRules
                    showingRulesEditor = false
                },
                onCancel: {
                    showingRulesEditor = false
                }
            )
        }
        .alert(isPresented: $showingValidationAlert) {
            Alert(
                title: Text("Validation Error"),
                message: Text(validationMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // [HELPER: add_participant]
    private func addParticipant() {
        let newParticipant = Participant(name: "New Staff", role: "Server")
        workingTemplate.participants.append(newParticipant)
        selectedParticipantIndex = workingTemplate.participants.count - 1
        showingParticipantEditor = true
    }
    
    // [HELPER: delete_participant]
    private func deleteParticipant(at offsets: IndexSet) {
        workingTemplate.participants.remove(atOffsets: offsets)
    }
    
    // [HELPER: save_template]
    private func saveTemplate() {
        let result = templateService.saveTemplate(workingTemplate)
        
        switch result {
        case .success:
            presentationMode.wrappedValue.dismiss()
        case .failure(let error):
            validationMessage = error.localizedDescription
            showingValidationAlert = true
        }
    }
}

// [ENTITY: ParticipantEditorView]
// View for editing a participant
struct ParticipantEditorView: View {
    @Binding var participant: Participant
    let ruleType: TipRuleType
    let onSave: (Participant) -> Void
    let onCancel: () -> Void
    @State private var workingParticipant: Participant
    
    init(participant: Binding<Participant>, ruleType: TipRuleType, onSave: @escaping (Participant) -> Void, onCancel: @escaping () -> Void) {
        self._participant = participant
        self.ruleType = ruleType
        self.onSave = onSave
        self.onCancel = onCancel
        self._workingParticipant = State(initialValue: participant.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $workingParticipant.name)
                    TextField("Role", text: $workingParticipant.role)
                }
                
                if ruleType == .percentage {
                    Section(header: Text("Percentage")) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("Weight %", value: $workingParticipant.weight, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                        }
                    }
                } else if ruleType == .hoursBased {
                    Section(header: Text("Hours")) {
                        HStack {
                            Text("Hours Worked")
                            Spacer()
                            TextField("Hours", value: $workingParticipant.hours, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("hrs")
                        }
                    }
                }
            }
            .navigationTitle("Edit Participant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(workingParticipant)
                    }
                }
            }
        }
    }
}

// [ENTITY: RulesEditorView]
// View for editing split rules
struct RulesEditorView: View {
    @Binding var rules: TipRules
    let onSave: (TipRules) -> Void
    let onCancel: () -> Void
    @State private var workingRules: TipRules
    @State private var selectedType: TipRuleType
    @State private var showingRoleWeightEditor = false
    @State private var showingOffTheTopEditor = false
    @State private var selectedRoleForWeight: String?
    
    init(rules: Binding<TipRules>, onSave: @escaping (TipRules) -> Void, onCancel: @escaping () -> Void) {
        self._rules = rules
        self.onSave = onSave
        self.onCancel = onCancel
        self._workingRules = State(initialValue: rules.wrappedValue)
        self._selectedType = State(initialValue: rules.wrappedValue.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Split Type")) {
                    Picker("Split Type", selection: $selectedType) {
                        ForEach(TipRuleType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedType) { newValue in
                        workingRules.type = newValue
                    }
                }
                
                if selectedType == .roleWeighted {
                    Section(header: Text("Role Weights")) {
                        ForEach(Array(workingRules.roleWeights.keys.sorted()), id: \.self) { role in
                            HStack {
                                Text(role)
                                Spacer()
                                Text("\(workingRules.roleWeights[role] ?? 0, specifier: "%.1f")")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRoleForWeight = role
                                showingRoleWeightEditor = true
                            }
                        }
                        
                        Button(action: {
                            selectedRoleForWeight = nil
                            showingRoleWeightEditor = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Role Weight")
                            }
                        }
                    }
                }
                
                Section(header: Text("Off-the-Top Rules")) {
                    if let offTheTop = workingRules.offTheTop, !offTheTop.isEmpty {
                        ForEach(Array(offTheTop.enumerated()), id: \.element.role) { index, rule in
                            HStack {
                                Text(rule.role)
                                Spacer()
                                Text("\(rule.percentage, specifier: "%.1f")%")
                            }
                        }
                        .onDelete { offsets in
                            workingRules.offTheTop?.remove(atOffsets: offsets)
                        }
                    }
                    
                    Button(action: {
                        showingOffTheTopEditor = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Off-the-Top Rule")
                        }
                    }
                }
            }
            .navigationTitle("Edit Rules")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(workingRules)
                    }
                }
            }
            .sheet(isPresented: $showingRoleWeightEditor) {
                RoleWeightEditorView(
                    roleWeights: $workingRules.roleWeights,
                    existingRole: selectedRoleForWeight,
                    onDismiss: {
                        showingRoleWeightEditor = false
                    }
                )
            }
            .sheet(isPresented: $showingOffTheTopEditor) {
                OffTheTopEditorView(
                    offTheTopRules: Binding(
                        get: { workingRules.offTheTop ?? [] },
                        set: { workingRules.offTheTop = $0 }
                    ),
                    onDismiss: {
                        showingOffTheTopEditor = false
                    }
                )
            }
        }
    }
}

// [ENTITY: RoleWeightEditorView]
// View for editing role weights
struct RoleWeightEditorView: View {
    @Binding var roleWeights: [String: Double]
    let existingRole: String?
    let onDismiss: () -> Void
    @State private var role: String
    @State private var weight: Double
    
    init(roleWeights: Binding<[String: Double]>, existingRole: String?, onDismiss: @escaping () -> Void) {
        self._roleWeights = roleWeights
        self.existingRole = existingRole
        self.onDismiss = onDismiss
        
        if let existingRole = existingRole {
            self._role = State(initialValue: existingRole)
            self._weight = State(initialValue: roleWeights.wrappedValue[existingRole] ?? 1.0)
        } else {
            self._role = State(initialValue: "")
            self._weight = State(initialValue: 1.0)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Role Name", text: $role)
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(existingRole != nil ? "Edit Role Weight" : "Add Role Weight")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRoleWeight()
                    }
                    .disabled(role.isEmpty)
                }
            }
        }
    }
    
    private func saveRoleWeight() {
        if let oldRole = existingRole, oldRole != role {
            roleWeights.removeValue(forKey: oldRole)
        }
        
        roleWeights[role] = weight
        onDismiss()
    }
}

// [ENTITY: OffTheTopEditorView]
// View for editing off-the-top rules
struct OffTheTopEditorView: View {
    @Binding var offTheTopRules: [OffTheTopRule]
    let onDismiss: () -> Void
    @State private var role: String = ""
    @State private var percentage: Double = 10.0
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Role", text: $role)
                    
                    HStack {
                        Text("Percentage")
                        Spacer()
                        TextField("Percentage", value: $percentage, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("%")
                    }
                }
            }
            .navigationTitle("Add Off-the-Top Rule")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOffTheTopRule()
                    }
                    .disabled(role.isEmpty)
                }
            }
        }
    }
    
    private func saveOffTheTopRule() {
        let newRule = OffTheTopRule(role: role, percentage: percentage)
        offTheTopRules.append(newRule)
        onDismiss()
    }
}
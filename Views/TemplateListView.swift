// TemplateListView.swift
// WhipTip Views

import SwiftUI

// [SECTION: views]
// [SUBSECTION: templates]

// [ENTITY: TemplateListView]
// Displays a list of available tip templates
struct TemplateListView: View {
    @ObservedObject var templateService: TemplateService
    @State private var showingAddTemplate = false
    @State private var showingImportSheet = false
    @State private var importText = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    // [FEATURE: body]
    var body: some View {
        List {
            ForEach(templateService.templates) { template in
                NavigationLink(destination: TemplateDetailView(template: template, templateService: templateService)) {
                    TemplateRowView(template: template)
                }
            }
            .onDelete(perform: deleteTemplates)
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddTemplate = true
                    }) {
                        Label("New Template", systemImage: "plus")
                    }
                    
                    Button(action: exportTemplates) {
                        Label("Export Templates", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        Label("Import Templates", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddTemplate) {
            let newTemplate = templateService.createTemplate()
            TemplateDetailView(template: newTemplate, templateService: templateService, isNewTemplate: true)
        }
        .sheet(isPresented: $showingImportSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Paste JSON Template Data")) {
                        TextEditor(text: $importText)
                            .frame(height: 200)
                    }
                    
                    Section {
                        Button("Import") {
                            importTemplates()
                        }
                        .disabled(importText.isEmpty)
                    }
                }
                .navigationTitle("Import Templates")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingImportSheet = false
                    importText = ""
                })
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Templates"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // [HELPER: delete_templates]
    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = templateService.templates[index]
            templateService.deleteTemplate(withId: template.id)
        }
    }
    
    // [HELPER: export_templates]
    private func exportTemplates() {
        if let jsonString = templateService.exportTemplatesAsJson() {
            UIPasteboard.general.string = jsonString
            alertMessage = "Templates exported to clipboard"
            showingAlert = true
        } else {
            alertMessage = "Failed to export templates"
            showingAlert = true
        }
    }
    
    // [HELPER: import_templates]
    private func importTemplates() {
        let result = templateService.importTemplatesFromJson(importText)
        
        switch result {
        case .success(let count):
            alertMessage = "Successfully imported \(count) templates"
            showingImportSheet = false
            importText = ""
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
        }
        
        showingAlert = true
    }
}

// [ENTITY: TemplateRowView]
// Row displaying a template summary
struct TemplateRowView: View {
    let template: TipTemplate
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(template.name)
                .font(.headline)
            
            HStack {
                Text(template.rules.type.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(template.participants.count) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
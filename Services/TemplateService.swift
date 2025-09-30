// TemplateService.swift
// WhipTip Service Layer

import Foundation
import Combine

// [SECTION: services]
// [SUBSECTION: templates]

// [ENTITY: TemplateService]
// Service for managing tip templates
class TemplateService {
    // Published property to enable reactive UI updates
    @Published private(set) var templates: [TipTemplate] = []
    private let persistenceKey = "savedTemplates"
    
    // [FEATURE: initialization]
    init() {
        loadTemplates()
    }
    
    // [FEATURE: load_templates]
    // Loads saved templates from persistent storage
    func loadTemplates() {
        // Implementation would load from UserDefaults or other storage
        // This is a placeholder for the full implementation
        templates = [
            TipTemplate.defaultTemplate(),
            TipTemplate.exampleRestaurantTemplate()
        ]
    }
    
    // [FEATURE: save_template]
    // Saves a template to persistent storage
    func saveTemplate(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        // Validate the template first
        let validationResult = ValidationService.validateTemplate(template)
        
        switch validationResult {
        case .success(let validTemplate):
            // Check if template with this ID already exists
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                templates[index] = validTemplate
            } else {
                templates.append(validTemplate)
            }
            
            // Save to persistent storage
            saveTemplates()
            
            return .success(validTemplate)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // [FEATURE: delete_template]
    // Deletes a template from persistent storage
    func deleteTemplate(withId id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }
    
    // [HELPER: save_to_storage]
    // Helper method to save templates to persistent storage
    private func saveTemplates() {
        // Implementation would save to UserDefaults or other storage
        // This is a placeholder for the full implementation
    }
    
    // [FEATURE: get_template]
    // Gets a specific template by ID
    func getTemplate(byId id: UUID) -> TipTemplate? {
        return templates.first { $0.id == id }
    }
    
    // [FEATURE: update_template]
    // Updates an existing template
    func updateTemplate(_ template: TipTemplate) -> Result<TipTemplate, WhipCoreError> {
        return saveTemplate(template)
    }
    
    // [FEATURE: create_template]
    // Creates a new template with default values
    func createTemplate(name: String = "New Template") -> TipTemplate {
        let newTemplate = TipTemplate(
            name: name,
            rules: TipRules(type: .equal),
            participants: [
                Participant(name: "Staff Member", role: "Server")
            ]
        )
        
        let _ = saveTemplate(newTemplate)
        return newTemplate
    }
    
    // [FEATURE: import_export]
    // Import/export templates as JSON
    func exportTemplatesAsJson() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(templates)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to export templates: \(error)")
            return nil
        }
    }
    
    func importTemplatesFromJson(_ json: String) -> Result<Int, WhipCoreError> {
        guard let jsonData = json.data(using: .utf8) else {
            return .failure(.validation("Invalid JSON format"))
        }
        
        do {
            let decoder = JSONDecoder()
            let importedTemplates = try decoder.decode([TipTemplate].self, from: jsonData)
            
            // Validate each imported template
            var validTemplates: [TipTemplate] = []
            var errorMessages: [String] = []
            
            for template in importedTemplates {
                let result = ValidationService.validateTemplate(template)
                switch result {
                case .success(let validTemplate):
                    validTemplates.append(validTemplate)
                case .failure(let error):
                    errorMessages.append("\(template.name): \(error.localizedDescription)")
                }
            }
            
            // Add valid templates to the existing collection
            templates.append(contentsOf: validTemplates)
            saveTemplates()
            
            if !errorMessages.isEmpty {
                print("Some templates had validation errors: \(errorMessages.joined(separator: ", "))")
            }
            
            return .success(validTemplates.count)
        } catch {
            return .failure(.validation("Failed to parse template JSON: \(error.localizedDescription)"))
        }
    }
}
// TemplateVersion.swift
// WhipTip Models

import Foundation

// [ENTITY: TemplateVersion]
// [VERSION: schemaVersion=currentVersion, createdWith=currentAppVersion]
struct TemplateVersion: Codable {
    let version: Int
    let createdWith: String // app version

    static let currentVersion: Int = 1
    static var currentAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

struct TemplateMigrationService {
    struct MigrationNote: CustomStringConvertible { let description: String }

    static func migrate(templates: [TipTemplate]) -> (migrated: [TipTemplate], notes: [MigrationNote]) {
        var notes: [MigrationNote] = []
        var changed = false
        let migrated = templates.map { tpl -> TipTemplate in
            var t = tpl
            let currentVersion = TemplateVersion.currentVersion
            if t.schemaVersion.version < currentVersion {
                notes.append(MigrationNote(description: "Upgraded template '\(t.name)' schema from v\(t.schemaVersion.version) to v\(currentVersion)"))
                t.schemaVersion = TemplateVersion(version: currentVersion, createdWith: TemplateVersion.currentAppVersion)
                changed = true
            }
            return t
        }
        return (changed ? migrated : templates, notes)
    }
}
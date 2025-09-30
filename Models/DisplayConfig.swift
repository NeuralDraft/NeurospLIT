// DisplayConfig.swift
// WhipTip Models

import Foundation

// [ENTITY: DisplayConfig]
// [USES: UI configuration]
struct DisplayConfig: Codable {
    var primaryVisualization: String
    var accentColor: String
    var showPercentages: Bool
    var showComparison: Bool
    // LIFECYCLE: Added new display configuration options
    var showHours: Bool = true
    var showRole: Bool = true
    
    init(primaryVisualization: String = "pie", accentColor: String = "#1E88E5", showPercentages: Bool = true, showComparison: Bool = true, showHours: Bool = true, showRole: Bool = true) {
        self.primaryVisualization = primaryVisualization
        self.accentColor = accentColor
        self.showPercentages = showPercentages
        self.showComparison = showComparison
        self.showHours = showHours
        self.showRole = showRole
    }
}
// Participant.swift
// WhipTip Models

import SwiftUI
import Foundation

// [ENTITY: Participant]
// [USES: SwiftUI.Color, Foundation]
// [VALIDATION: Hours/weights non-negative recommended; emoji defaults by role]
struct Participant: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var hours: Double?
    var weight: Double?
    var calculatedAmount: Double?
    var actualAmount: Double?
    // LIFECYCLE: Added direct emoji property for template customization
    var emojiOverride: String?
    var colorHex: String?
    var percentage: Double?
    
    // LIFECYCLE: Added convenience initializer for template editing
    init(id: UUID = UUID(), name: String, role: String, 
         emoji: String? = nil, color: Color? = nil, 
         hours: Double? = nil, weight: Double? = nil, 
         calculatedAmount: Double? = nil, actualAmount: Double? = nil,
         percentage: Double? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.emojiOverride = emoji
        if let color = color {
            self.colorHex = color.hexString
        }
        self.hours = hours
        self.weight = weight
        self.calculatedAmount = calculatedAmount
        self.actualAmount = actualAmount
        self.percentage = percentage
    }

    var emoji: String {
        if let override = emojiOverride {
            return override
        }
        
        switch role.lowercased() {
        case "server": return "👤"
        case "busser": return "🍽️"
        case "host": return "🎯"
        case "bartender": return "🍹"
        case "cook", "kitchen": return "👨‍🍳"
        case "manager": return "💼"
        default: return "💰"
        }
    }

    // LIFECYCLE: Updated to support customizable colors with hex storage
    var color: Color {
        get {
            if let hex = colorHex {
                return Color(hex: hex)
            }
            
            // Default colors based on role
            switch role.lowercased() {
            case "server": return Color(hex: "6C8EAD") // Blue-gray
            case "bartender": return Color(hex: "A3C9A8") // Mint
            case "host": return Color(hex: "FFD275") // Gold
            case "busser": return Color(hex: "FF8C42") // Orange
            case "cook", "kitchen": return Color(hex: "F96E46") // Red-orange
            case "manager": return Color(hex: "9C89B8") // Purple
            default: return Color(hex: "F0A6CA") // Pink
            }
        }
        set {
            colorHex = newValue.hexString
        }
    }
}
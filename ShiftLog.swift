import Foundation
import SwiftUI

// SHIFT: Main model to track shift/session data
struct ShiftLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var templateName: String
    var templateId: UUID
    var totalPool: Double
    var participants: [Participant]
    var notes: String?
    
    // SHIFT: Initialize a new shift log from a completed calculation
    init(date: Date = Date(), 
         templateName: String, 
         templateId: UUID,
         totalPool: Double, 
         participants: [Participant], 
         notes: String? = nil) {
        self.date = date
        self.templateName = templateName
        self.templateId = templateId
        self.totalPool = totalPool
        self.participants = participants
        self.notes = notes
    }
}

// SHIFT: Manager class for handling shift log persistence
class ShiftLogManager: ObservableObject {
    @Published var shiftLogs: [ShiftLog] = []
    
    private let storageKey = "savedShiftLogs"
    
    static let shared = ShiftLogManager()
    
    init() {
        loadShiftLogs()
    }
    
    func loadShiftLogs() {
        do {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else {
                shiftLogs = []
                return
            }
            
            shiftLogs = try JSONDecoder().decode([ShiftLog].self, from: data)
            // Sort by date, newest first
            shiftLogs.sort { $0.date > $1.date }
            
        } catch {
            print("Failed to load shift logs: \(error)")
            shiftLogs = []
        }
    }
    
    func saveShiftLogs() {
        do {
            let encoded = try JSONEncoder().encode(shiftLogs)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("Failed to save shift logs: \(error)")
        }
    }
    
    func addShiftLog(_ shiftLog: ShiftLog) {
        shiftLogs.append(shiftLog)
        // Re-sort by date, newest first
        shiftLogs.sort { $0.date > $1.date }
        saveShiftLogs()
    }
    
    func updateShiftLog(_ updatedLog: ShiftLog) {
        if let index = shiftLogs.firstIndex(where: { $0.id == updatedLog.id }) {
            shiftLogs[index] = updatedLog
            saveShiftLogs()
        }
    }
    
    func deleteShiftLog(_ shiftLog: ShiftLog) {
        shiftLogs.removeAll { $0.id == shiftLog.id }
        saveShiftLogs()
    }
    
    func clearAllLogs() {
        shiftLogs = []
        saveShiftLogs()
    }
}

// SHIFT: Helper for relative date formatting
extension Date {
    func relativeDateString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        let now = Date()
        let difference = Calendar.current.dateComponents([.day], from: self, to: now).day ?? 0
        
        if difference == 0 {
            return "Today"
        } else if difference == 1 {
            return "Yesterday"
        } else {
            return formatter.localizedString(for: self, relativeTo: now)
        }
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
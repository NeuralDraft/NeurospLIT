import Foundation


public enum WhipCoreError: Error, LocalizedError, Equatable {
    case negativePool
    case noParticipants
    case negativeHours(participantName: String)
    case negativeWeight(participantName: String)
    case invalidOffTheTopPercentage(role: String, percentage: Double)
    case invalidRoleWeight(role: String, weight: Double)

    public var errorDescription: String? {
        switch self {
        case .negativePool:
            return "Pool cannot be negative."
        case .noParticipants:
            return "No participants to split."
        case .negativeHours(let name):
            return "Negative hours for participant: \(name)."
        case .negativeWeight(let name):
            return "Negative weight for participant: \(name)."
        case .invalidOffTheTopPercentage(let role, let pct):
            return "Invalid off-the-top percentage \(pct) for role: \(role)."
        case .invalidRoleWeight(let role, let w):
            return "Invalid role weight \(w) for role: \(role)."
        }
    }
}

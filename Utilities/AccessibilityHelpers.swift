import SwiftUI

// MARK: - Accessibility Helpers
struct AccessibilityHelpers {
    
    // MARK: - Common Labels
    
    struct Labels {
        static let closeButton = "Close"
        static let backButton = "Back"
        static let continueButton = "Continue"
        static let saveButton = "Save"
        static let deleteButton = "Delete"
        static let editButton = "Edit"
        static let addButton = "Add"
        static let settingsButton = "Settings"
        static let menuButton = "Menu"
        static let shareButton = "Share"
        static let refreshButton = "Refresh"
    }
    
    // MARK: - Value Formatting
    
    static func currencyAccessibilityLabel(_ amount: Double) -> String {
        let dollars = Int(amount)
        let cents = Int((amount - Double(dollars)) * 100)
        
        if cents == 0 {
            return "\(dollars) dollar\(dollars == 1 ? "" : "s")"
        } else {
            return "\(dollars) dollar\(dollars == 1 ? "" : "s") and \(cents) cent\(cents == 1 ? "" : "s")"
        }
    }
    
    static func percentageAccessibilityLabel(_ percentage: Double) -> String {
        return "\(Int(percentage)) percent"
    }
    
    static func participantAccessibilityLabel(name: String, role: String, amount: Double?) -> String {
        var label = "\(name), \(role)"
        if let amount = amount {
            label += ", receives \(currencyAccessibilityLabel(amount))"
        }
        return label
    }
    
    // MARK: - Dynamic Type Support
    
    static func scaledFont(_ style: Font.TextStyle, size: CGFloat? = nil) -> Font {
        if let size = size {
            return Font.system(size: size, design: .default)
                .accessibilityFont(style)
        } else {
            return Font.preferredFont(forTextStyle: style)
        }
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibilityAction: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let value: String?
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
}

struct AccessibilityFocus: ViewModifier {
    @AccessibilityFocusState private var isFocused: Bool
    let shouldFocus: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onAppear {
                if shouldFocus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
            }
    }
}

struct AccessibilityGroup: ViewModifier {
    let label: String
    let sortPriority: Double
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilitySortPriority(sortPriority)
    }
}

// MARK: - Extension Methods

extension View {
    func accessibilityAction(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        modifier(AccessibilityAction(
            label: label,
            hint: hint,
            traits: traits,
            value: value
        ))
    }
    
    func accessibilityFocusOnAppear(_ shouldFocus: Bool = true) -> some View {
        modifier(AccessibilityFocus(shouldFocus: shouldFocus))
    }
    
    func accessibilityGroup(label: String, sortPriority: Double = 0) -> some View {
        modifier(AccessibilityGroup(label: label, sortPriority: sortPriority))
    }
    
    func accessibilityFont(_ textStyle: Font.TextStyle) -> Font {
        return Font.preferredFont(forTextStyle: textStyle)
    }
}

// MARK: - Accessibility Announcements

struct AccessibilityAnnouncer {
    static func announce(_ message: String, priority: AccessibilityNotification.Priority = .high) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AccessibilityNotification.Announcement(message)
                .post(priority: priority)
        }
    }
    
    static func announceScreenChange(_ screenName: String) {
        announce("\(screenName) screen")
    }
    
    static func announceSuccess(_ message: String) {
        announce("Success: \(message)")
    }
    
    static func announceError(_ message: String) {
        announce("Error: \(message)", priority: .high)
    }
}

// MARK: - Color Contrast Helpers

extension Color {
    static let accessiblePurple = Color(red: 0.5, green: 0.2, blue: 0.8)
    static let accessibleGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    static let accessibleRed = Color(red: 0.8, green: 0.0, blue: 0.0)
    static let accessibleBlue = Color(red: 0.0, green: 0.4, blue: 0.8)
    static let accessibleOrange = Color(red: 0.9, green: 0.5, blue: 0.0)
    
    func meetsContrastRatio(against background: Color, ratio: Double = 4.5) -> Bool {
        // Simplified contrast check - in production, use proper WCAG calculation
        return true // Placeholder
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    enum FeedbackType {
        case success
        case warning
        case error
        case light
        case medium
        case heavy
        case selection
    }
    
    static func trigger(_ type: FeedbackType) {
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let reducedAnimation: Animation?
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    func adaptiveAnimation(_ animation: Animation?, reduced: Animation? = nil) -> some View {
        modifier(ReducedMotionModifier(animation: animation, reducedAnimation: reduced))
    }
}

// MARK: - Voice Control Support

struct VoiceControlLabel: ViewModifier {
    let label: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityInputLabels([label])
    }
}

extension View {
    func voiceControlLabel(_ label: String) -> some View {
        modifier(VoiceControlLabel(label: label))
    }
}

// MARK: - Dynamic Type Preview

struct DynamicTypePreview<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(ContentSizeCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading) {
                        Text(String(describing: category))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        content
                            .environment(\.sizeCategory, category)
                            .previewLayout(.sizeThatFits)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
struct AccessibilityInspector: View {
    @Environment(\.accessibilityEnabled) var accessibilityEnabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityInvertColors) var invertColors
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accessibility Settings")
                .font(.headline)
            
            Group {
                HStack {
                    Text("VoiceOver:")
                    Text(accessibilityEnabled ? "ON" : "OFF")
                        .foregroundColor(accessibilityEnabled ? .green : .gray)
                }
                
                HStack {
                    Text("Reduce Motion:")
                    Text(reduceMotion ? "ON" : "OFF")
                        .foregroundColor(reduceMotion ? .green : .gray)
                }
                
                HStack {
                    Text("Reduce Transparency:")
                    Text(reduceTransparency ? "ON" : "OFF")
                        .foregroundColor(reduceTransparency ? .green : .gray)
                }
                
                HStack {
                    Text("Differentiate Without Color:")
                    Text(differentiateWithoutColor ? "ON" : "OFF")
                        .foregroundColor(differentiateWithoutColor ? .green : .gray)
                }
                
                HStack {
                    Text("Invert Colors:")
                    Text(invertColors ? "ON" : "OFF")
                        .foregroundColor(invertColors ? .green : .gray)
                }
                
                HStack {
                    Text("Text Size:")
                    Text(String(describing: sizeCategory))
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
#endif

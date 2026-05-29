import SwiftUI

enum NotchMonochromeStyle {
    static let ink = Color.white
    static let muted = Color.white.opacity(0.55)
    static let faint = Color.white.opacity(0.32)
    static let hairline = Color.white.opacity(0.14)
    static let rowFill = Color.white.opacity(0.06)
    static let rowFillHover = Color.white.opacity(0.1)

    static let titleFont = Font.system(size: 11, weight: .semibold)
    static let bodyFont = Font.system(size: 10, weight: .regular)
    static let captionFont = Font.system(size: 9, weight: .medium)
    static let headerFont = Font.system(size: 10, weight: .medium)

    static func statusLabel(for state: AgentActivityState) -> String {
        switch state {
        case .needsInput: return "Waiting"
        case .working: return "Working"
        case .idle: return "Stopped"
        case .unknown: return "Unknown"
        }
    }

    static func iconOpacity(for state: AgentActivityState?) -> Double {
        switch state {
        case .needsInput, .working: return 1
        case .idle: return 0.55
        case .unknown, .none: return 0.28
        }
    }
}

struct NotchStatusPill: View {
    let state: AgentActivityState

    var body: some View {
        Text(NotchMonochromeStyle.statusLabel(for: state))
            .font(NotchMonochromeStyle.captionFont)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .overlay {
                if showsBorder {
                    Capsule().strokeBorder(NotchMonochromeStyle.hairline, lineWidth: 1)
                }
            }
    }

    private var foreground: Color {
        switch state {
        case .needsInput: return .black
        case .working: return NotchMonochromeStyle.ink
        case .idle, .unknown: return NotchMonochromeStyle.muted
        }
    }

    private var background: Color {
        switch state {
        case .needsInput: return NotchMonochromeStyle.ink
        case .working, .idle, .unknown: return .clear
        }
    }

    private var showsBorder: Bool {
        state == .working || state == .idle
    }
}

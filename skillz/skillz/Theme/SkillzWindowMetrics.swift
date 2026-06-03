import CoreGraphics

enum SkillzWindowMetrics {
    static let defaultWidth: CGFloat = 1440
    static let defaultHeight: CGFloat = 880

    static let minWidth: CGFloat = 1200
    static let minHeight: CGFloat = 720

    static let sidebarIdeal: CGFloat = 220
    static let sidebarMin: CGFloat = 200
    static let sidebarMax: CGFloat = 260

    static let listIdeal: CGFloat = 360
    static let listMin: CGFloat = 300
    static let listMax: CGFloat = 420

    static let detailMin: CGFloat = 520
    static let detailIdeal: CGFloat = 680

    static let inspectorIdeal: CGFloat = 280
    static let inspectorMin: CGFloat = 240
    static let inspectorMax: CGFloat = 320

    static let fileTreeIdeal: CGFloat = 168
    static let fileTreeMin: CGFloat = 140
    static let fileTreeMax: CGFloat = 200

    static let editorMin: CGFloat = 420

    /// Horizontal space occupied by the standard macOS traffic-light controls
    /// when the titlebar is hidden and content extends into the titlebar area.
    /// Sized to clear the close/minimize/zoom cluster so the toolbar sits just to its right.
    static let trafficLightReservedWidth: CGFloat = 88

    /// Upward pull applied to the NavigationSplitView so the floating inset-sidebar
    /// card tucks close to the top-bar divider. The system reserves extra title-bar
    /// space above the card; this trims that surplus so the card's top margin matches
    /// its side/bottom margins. The top bar renders above the split view (zIndex) so
    /// any shadow above the divider is masked and the hairline stays crisp.
    static let sidebarTopInsetPull: CGFloat = 18

    /// Top inset for the flat content/detail column headers ("All Items", the skill
    /// name, etc.). These columns have no floating card to cushion them from the
    /// top-bar divider, so they need a larger top gap than `SkillzSpacing.md` to clear
    /// the divider and align with the sidebar's title. Bottom padding stays `.md`.
    static let columnHeaderTopInset: CGFloat = 24
}

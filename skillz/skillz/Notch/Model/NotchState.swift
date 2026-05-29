import Foundation

enum NotchPanelMode: Equatable {
    case home
}

enum NotchPeekKind: Equatable {
    case needsInput(platformName: String, sessionTitle: String)
}

enum NotchState: Equatable {
    case hidden
    case closed
    case peeking(NotchPeekKind)
    case open(NotchPanelMode)
}

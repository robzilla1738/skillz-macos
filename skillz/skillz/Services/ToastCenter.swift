import Foundation
import Combine

/// Lightweight transient feedback (success/info). Errors keep using `SkillzErrorBanner`,
/// which requires explicit dismissal; toasts auto-dismiss.
@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    enum Kind: Equatable {
        case success
        case info

        var symbolName: String {
            switch self {
            case .success: return "checkmark.circle"
            case .info: return "info.circle"
            }
        }
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let kind: Kind
    }

    @Published private(set) var current: Toast?

    /// Seconds a toast stays on screen before auto-dismissing. Injectable for tests.
    var displayDuration: TimeInterval = 2.5

    private var dismissTask: Task<Void, Never>?

    init() {}

    func show(_ message: String, kind: Kind = .success) {
        dismissTask?.cancel()
        let toast = Toast(message: message, kind: kind)
        current = toast
        let duration = displayDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.current?.id == toast.id else { return }
                self.current = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}

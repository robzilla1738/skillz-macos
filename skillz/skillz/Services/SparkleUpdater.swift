import Foundation
import Combine
import Sparkle

@MainActor
final class SparkleUpdater: NSObject, ObservableObject {
    static let shared = SparkleUpdater()

    @Published private(set) var canCheckForUpdates = false

    let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        canCheckForUpdates = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = canCheck
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

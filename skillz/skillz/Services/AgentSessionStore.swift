import Foundation
import Combine

@MainActor
final class AgentSessionStore: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var summary = AgentActivitySummary(sessions: [], needsInputCount: 0, workingCount: 0, hasNeedsInput: false)
    @Published private(set) var lastRefreshedAt: Date?

    private var fsWatcher: FSEventWatcher?
    private var pollTimer: Timer?
    private var isStarted = false

    func start() {
        guard !isStarted else {
            refresh(silent: true)
            return
        }
        isStarted = true
        try? AgentStateFile.ensureExists()
        refresh()
        startWatching()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
    }

    func stop() {
        fsWatcher?.stop()
        fsWatcher = nil
        pollTimer?.invalidate()
        pollTimer = nil
        isStarted = false
    }

    func refresh(silent: Bool = false) {
        let discovered = AgentActivityEngine.discover()
        sessions = discovered
        summary = AgentActivityEngine.summary(for: discovered)
        if !silent {
            lastRefreshedAt = Date()
        }
    }

    func startWatching() {
        let paths = AgentPaths.watchPathsForAgents()
        fsWatcher?.stop()
        fsWatcher = FSEventWatcher(paths: paths) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
        fsWatcher?.start()
    }

    func reopenWatching() {
        startWatching()
        refresh(silent: true)
    }
}

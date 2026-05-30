import Foundation
import Combine

@MainActor
final class AgentSessionStore: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var summary = AgentActivitySummary(sessions: [], needsInputCount: 0, workingCount: 0, hasNeedsInput: false)
    @Published private(set) var lastRefreshedAt: Date?

    private var fsWatcher: FSEventWatcher?
    private var pollTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var pendingRefresh: PendingRefresh?
    private var lastFullDiscoveryAt: Date?
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
                guard let self else { return }
                self.refresh(silent: true, scope: self.scheduledPollScope())
            }
        }
    }

    func stop() {
        fsWatcher?.stop()
        fsWatcher = nil
        pollTimer?.invalidate()
        pollTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
        pendingRefresh = nil
        isStarted = false
    }

    func refresh(silent: Bool = false, scope: AgentActivityEngine.DiscoveryScope = .full) {
        let request = PendingRefresh(silent: silent, scope: scope)
        guard refreshTask == nil else {
            pendingRefresh = pendingRefresh.map { $0.merged(with: request) } ?? request
            return
        }

        runRefresh(request)
    }

    func startWatching() {
        let paths = AgentPaths.watchPathsForAgents()
        fsWatcher?.stop()
        fsWatcher = FSEventWatcher(paths: paths) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true, scope: .full)
            }
        }
        fsWatcher?.start()
    }

    func reopenWatching() {
        startWatching()
        refresh(silent: true, scope: .full)
    }

    private func scheduledPollScope() -> AgentActivityEngine.DiscoveryScope {
        guard let lastFullDiscoveryAt else { return .full }
        return Date().timeIntervalSince(lastFullDiscoveryAt) > 30 ? .full : .fast
    }

    private func runRefresh(_ request: PendingRefresh) {
        refreshTask = Task { [weak self] in
            let discovered = await Task.detached(priority: request.scope == .full ? .userInitiated : .utility) {
                AgentActivityEngine.discover(scope: request.scope)
            }.value

            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.sessions = discovered
                self.summary = AgentActivityEngine.summary(for: discovered)
                if request.scope == .full {
                    self.lastFullDiscoveryAt = Date()
                }
                if !request.silent {
                    self.lastRefreshedAt = Date()
                }
                self.refreshTask = nil

                if let pending = self.pendingRefresh {
                    self.pendingRefresh = nil
                    self.runRefresh(pending)
                }
            }
        }
    }
}

private struct PendingRefresh {
    var silent: Bool
    var scope: AgentActivityEngine.DiscoveryScope

    func merged(with other: PendingRefresh) -> PendingRefresh {
        PendingRefresh(
            silent: silent && other.silent,
            scope: scope == .full || other.scope == .full ? .full : .fast
        )
    }
}

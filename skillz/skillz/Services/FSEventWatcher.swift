import Foundation

final class FSEventWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let debounceInterval: TimeInterval
    private var pendingWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.skillz.fsevents", qos: .utility)
    private let onChange: @Sendable () -> Void

    init(paths: [URL], debounceInterval: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.paths = paths.map(\.path)
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    func start() {
        guard !paths.isEmpty else { return }
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<FSEventWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.scheduleDebouncedRefresh()
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    deinit {
        stop()
    }

    private func scheduleDebouncedRefresh() {
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [onChange] in
            DispatchQueue.main.async {
                onChange()
            }
        }
        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}

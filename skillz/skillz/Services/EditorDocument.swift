import Foundation
import Combine

enum SaveStatus: Equatable {
    case saved
    case saving
    case failed(String)
}

@MainActor
final class EditorDocument: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published private(set) var saveStatus: SaveStatus = .saved

    private var savedText: String = ""
    private var autosaveTask: Task<Void, Never>?
    private var autosavePaused = false

    private let debounceSeconds: TimeInterval = 1.2

    func load(url: URL) {
        cancelAutosave()
        fileURL = url
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        text = content
        savedText = content
        isDirty = false
        saveStatus = .saved
    }

    func updateText(_ newValue: String) {
        text = newValue
        isDirty = text != savedText
        guard isDirty else {
            saveStatus = .saved
            return
        }
        guard !autosavePaused else { return }
        scheduleAutosave()
    }

    func pauseAutosave() {
        autosavePaused = true
        cancelAutosave()
    }

    func resumeAutosave() {
        autosavePaused = false
        if isDirty {
            scheduleAutosave()
        }
    }

    func save() throws {
        guard let fileURL else { return }
        saveStatus = .saving
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        savedText = text
        isDirty = false
        saveStatus = .saved
    }

    @discardableResult
    func saveImmediately() -> Bool {
        cancelAutosave()
        guard isDirty else {
            saveStatus = .saved
            return true
        }
        do {
            try save()
            return true
        } catch {
            saveStatus = .failed(FileAccessError.userMessage(for: error))
            return false
        }
    }

    func discardChanges() {
        cancelAutosave()
        text = savedText
        isDirty = false
        saveStatus = .saved
    }

    private func scheduleAutosave() {
        cancelAutosave()
        saveStatus = .saving
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.2 * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.performAutosave()
            }
        }
    }

    private func performAutosave() {
        guard !autosavePaused, isDirty else { return }
        do {
            try save()
        } catch {
            saveStatus = .failed(FileAccessError.userMessage(for: error))
        }
    }

    private func cancelAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
    }
}

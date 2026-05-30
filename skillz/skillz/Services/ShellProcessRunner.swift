import Foundation

nonisolated struct ShellProcessResult: Sendable {
    let standardOutput: String
    let standardError: String
    let terminationStatus: Int32
    let didTimeOut: Bool
}

nonisolated enum ShellProcessRunner {
    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 1.5
    ) -> ShellProcessResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdout = LockedData()
        let stderr = LockedData()
        let outputGroup = DispatchGroup()

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            outputGroup.leave()
        }

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            outputGroup.leave()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }

        let didTimeOut = process.isRunning
        if didTimeOut {
            process.terminate()
            let terminateDeadline = Date().addingTimeInterval(0.15)
            while process.isRunning, Date() < terminateDeadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            if process.isRunning {
                process.interrupt()
            }
        }

        _ = outputGroup.wait(timeout: .now() + max(0.2, timeout))

        return ShellProcessResult(
            standardOutput: String(data: stdout.value, encoding: .utf8) ?? "",
            standardError: String(data: stderr.value, encoding: .utf8) ?? "",
            terminationStatus: process.terminationStatus,
            didTimeOut: didTimeOut
        )
    }
}

nonisolated private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    func set(_ value: Data) {
        lock.lock()
        data = value
        lock.unlock()
    }
}

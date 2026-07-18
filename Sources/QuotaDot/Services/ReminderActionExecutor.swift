import AppKit
import Foundation
import OSLog

struct ReminderProcessCommand: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let currentDirectoryURL: URL?
    let environment: [String: String]
}

enum ReminderActionExecutor {
    private static let logger = Logger(
        subsystem: "com.cmsjcm.QuotaDot",
        category: "reminder-action"
    )

    static func processCommand(for action: ReminderClickAction) -> ReminderProcessCommand? {
        switch action {
        case .shortcut(let name):
            return ReminderProcessCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/shortcuts"),
                arguments: ["run", name],
                currentDirectoryURL: nil,
                environment: ProcessInfo.processInfo.environment
            )
        case .python(let scriptPath, let workingDirectory):
            var environment = ProcessInfo.processInfo.environment
            let preferredPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            environment["PATH"] = (preferredPaths + [environment["PATH"] ?? ""])
                .filter { !$0.isEmpty }
                .joined(separator: ":")
            return ReminderProcessCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["python3", scriptPath],
                currentDirectoryURL: URL(fileURLWithPath: workingDirectory, isDirectory: true),
                environment: environment
            )
        case .none, .openURL, .openPath:
            return nil
        }
    }

    @MainActor
    static func perform(_ action: ReminderClickAction) {
        switch action {
        case .none:
            return
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .openPath(let path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .shortcut, .python:
            guard let command = processCommand(for: action) else { return }
            let process = Process()
            process.executableURL = command.executableURL
            process.arguments = command.arguments
            process.currentDirectoryURL = command.currentDirectoryURL
            process.environment = command.environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                logger.error("Reminder action failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

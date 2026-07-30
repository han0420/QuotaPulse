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
        subsystem: "com.cmsjcm.QuotaPulse",
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
        case .deepSeekBalance:
            guard let apiKey = DeepSeekAPIKeyStore.load(),
                  let command = DeepSeekBalanceClient.fixedCommand(apiKey: apiKey) else { return nil }
            return ReminderProcessCommand(
                executableURL: command.executableURL,
                arguments: command.arguments,
                currentDirectoryURL: nil,
                environment: ProcessInfo.processInfo.environment
            )
        case .none, .openURL, .openPath:
            return nil
        }
    }

    @MainActor
    static func perform(_ action: ReminderClickAction) {
        switch action {
        case .none:
            logger.info("Reminder action completed type=none result=no-op")
            return
        case .openURL(let url):
            let succeeded = NSWorkspace.shared.open(url)
            if succeeded {
                logger.info("Reminder action completed type=openURL result=success")
            } else {
                logger.error("Reminder action completed type=openURL result=failed")
            }
        case .openPath(let path):
            let succeeded = NSWorkspace.shared.open(URL(fileURLWithPath: path))
            if succeeded {
                logger.info("Reminder action completed type=openPath result=success")
            } else {
                logger.error("Reminder action completed type=openPath result=failed")
            }
        case .shortcut, .python, .deepSeekBalance:
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
                logger.info(
                    "Reminder action started type=\(action.diagnosticLabel, privacy: .public) result=success"
                )
            } catch {
                logger.error(
                    "Reminder action started type=\(action.diagnosticLabel, privacy: .public) result=failed error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

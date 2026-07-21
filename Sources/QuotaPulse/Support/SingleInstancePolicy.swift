import Foundation

enum SingleInstancePolicy {
    static func shouldTerminateCurrentProcess(
        currentProcessIdentifier: pid_t,
        runningProcessIdentifiers: [pid_t]
    ) -> Bool {
        runningProcessIdentifiers.contains { $0 != currentProcessIdentifier }
    }
}

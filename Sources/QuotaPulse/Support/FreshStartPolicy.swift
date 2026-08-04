import Foundation

enum FreshStartPolicy {
    static let completionKey = "QuotaPulse.v2.freshStart.completed"

    @discardableResult
    static func prepare(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: completionKey) else { return false }
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: completionKey)
        return true
    }
}

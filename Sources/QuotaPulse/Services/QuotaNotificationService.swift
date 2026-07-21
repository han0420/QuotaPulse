import AppKit
import Foundation
import OSLog
import UserNotifications

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized

    var shouldRequestAuthorization: Bool { self == .notDetermined }
}

enum QuotaNotificationPolicy {
    static func crossedThreshold(
        previous: Double,
        current: Double,
        configuration: QuotaNotificationConfiguration = QuotaNotificationPreferences.defaultConfiguration
    ) -> Double? {
        guard current < previous else { return nil }
        return configuration.remainingThresholdPercents
            .map { Double($0) / 100 }
            .filter { previous > $0 && current <= $0 }
            .min()
    }
}

enum DailyReminderScheduleResult {
    case scheduled
    case disabled
    case denied
    case failed
}

enum ReminderSnoozePolicy {
    static let tenMinutesActionIdentifier = "QuotaPulse.snooze.10m"
    static let oneHourActionIdentifier = "QuotaPulse.snooze.1h"

    static func delay(for actionIdentifier: String) -> TimeInterval? {
        switch actionIdentifier {
        case tenMinutesActionIdentifier: 10 * 60
        case oneHourActionIdentifier: 60 * 60
        default: nil
        }
    }
}

final class QuotaNotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private static let dailyReminderIdentifierPrefix = "com.cmsjcm.QuotaPulse.daily-reminder"
    private static let reminderCategoryIdentifier = "QuotaPulse.reminder.actions"
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.cmsjcm.QuotaPulse", category: "notification")

    override init() {
        center = .current()
        super.init()
        center.delegate = self
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorizationIfNeeded() async -> NotificationAuthorizationState {
        let state = await authorizationState()
        guard state.shouldRequestAuthorization else { return state }
        _ = await requestAuthorization()
        return await authorizationState()
    }

    @MainActor
    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func send(title: String, body: String) async {
        guard await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        do {
            try await center.add(UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            ))
        } catch {
            logger.error("Notification delivery failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func synchronizeReminders(
        _ configurations: [DailyReminderConfiguration],
        title: String,
        snoozeTenMinutesTitle: String,
        snoozeOneHourTitle: String
    ) async -> DailyReminderScheduleResult {
        let now = Date.now
        let enabled = configurations.filter(\.isEnabled)
        var scheduledConfigurations: [(DailyReminderConfiguration, [ReminderNotificationSchedule])] = []
        for configuration in enabled {
            if configuration.effectiveScheduleType == .once,
               let scheduledDate = configuration.scheduledDate,
               scheduledDate <= now {
                continue
            }
            guard configuration.isValid(at: now),
                  configuration.clickAction != nil else { return .failed }
            scheduledConfigurations.append((
                configuration,
                configuration.notificationSchedules(now: now)
            ))
        }

        let pending = await center.pendingNotificationRequests()
        let existingIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.dailyReminderIdentifierPrefix) }
        guard !scheduledConfigurations.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
            return .disabled
        }
        guard await requestAuthorization() else { return .denied }
        configureReminderCategory(
            snoozeTenMinutesTitle: snoozeTenMinutesTitle,
            snoozeOneHourTitle: snoozeOneHourTitle
        )
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

        do {
            for (configuration, schedules) in scheduledConfigurations {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = configuration.normalizedMessage
                content.sound = .default
                content.categoryIdentifier = Self.reminderCategoryIdentifier
                if let clickAction = configuration.clickAction {
                    content.userInfo = ReminderActionPayload(action: clickAction).userInfo
                }
                for schedule in schedules {
                    try await center.add(UNNotificationRequest(
                        identifier: schedule.identifier,
                        content: content,
                        trigger: UNCalendarNotificationTrigger(
                            dateMatching: schedule.dateComponents,
                            repeats: schedule.repeats
                        )
                    ))
                }
            }
            return .scheduled
        } catch {
            center.removePendingNotificationRequests(
                withIdentifiers: scheduledConfigurations.flatMap { $0.1.map(\.identifier) }
            )
            logger.error("Daily notification scheduling failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private func configureReminderCategory(
        snoozeTenMinutesTitle: String,
        snoozeOneHourTitle: String
    ) {
        let actions = [
            UNNotificationAction(
                identifier: ReminderSnoozePolicy.tenMinutesActionIdentifier,
                title: snoozeTenMinutesTitle
            ),
            UNNotificationAction(
                identifier: ReminderSnoozePolicy.oneHourActionIdentifier,
                title: snoozeOneHourTitle
            )
        ]
        center.setNotificationCategories([UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: actions,
            intentIdentifiers: []
        )])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let delay = ReminderSnoozePolicy.delay(for: response.actionIdentifier) {
            let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent
            completionHandler()
            guard let content else { return }
            center.add(UNNotificationRequest(
                identifier: "\(Self.dailyReminderIdentifierPrefix).snoozed.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )) { _ in }
            return
        }

        let payload = ReminderActionPayload(
            userInfo: response.notification.request.content.userInfo
        )
        let clickAction = payload?.clickAction
        completionHandler()
        guard let clickAction else { return }
        Task { @MainActor in
            ReminderActionExecutor.perform(clickAction)
        }
    }
}

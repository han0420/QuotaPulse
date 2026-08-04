import AppKit
import SwiftUI

@main
struct QuotaPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                store: appDelegate.store,
                windowController: appDelegate.windowController,
                language: appDelegate.language,
                notificationService: appDelegate.notificationService,
                backupController: appDelegate.backupController
            )
        } label: {
            HStack(spacing: 4) {
                MenuBarQuotaGlyph()
                Text(QuotaFormatters.percent(appDelegate.store.lowestRemaining))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }

        Settings {
            SettingsView(
                language: appDelegate.language,
                notificationService: appDelegate.notificationService,
                store: appDelegate.store,
                localNotificationHTTPToken: appDelegate.localNotificationHTTPToken
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shouldTerminateAsDuplicate: Bool
    private let performedFreshStart: Bool
    lazy var language = LanguageSettings()
    lazy var notificationService = QuotaNotificationService()
    let backupController = ConfigurationBackupController()
    lazy var localNotificationHTTPToken = LocalNotificationHTTPTokenStore.loadOrCreate()
    lazy var localNotificationHTTPAPI = try? LocalNotificationHTTPAPI(
        token: localNotificationHTTPToken,
        sendNotification: { [notificationService] title, body in await notificationService.send(title: title, body: body) }
    )
    lazy var store = QuotaStore(notificationService: notificationService, language: language)
    lazy var windowController = FloatingWindowController(store: store, language: language)
    private var refreshTask: Task<Void, Never>?

    override init() {
        shouldTerminateAsDuplicate = Self.isDuplicateInstance
        performedFreshStart = shouldTerminateAsDuplicate ? false : FreshStartPolicy.prepare()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !activateExistingInstanceAndTerminateIfNeeded() else { return }
        NSApp.setActivationPolicy(.accessory)
        if performedFreshStart {
            notificationService.clearAllNotifications()
        }
        localNotificationHTTPAPI?.start()
        windowController.show()
        refreshTask = Task { await store.start() }
        Task {
            await notificationService.requestAuthorization()
            await restoreDailyReminders()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
        localNotificationHTTPAPI?.stop()
    }

    private func restoreDailyReminders() async {
        let configurations = DailyReminderPreferences.loadAll()
        _ = await notificationService.synchronizeReminders(
            configurations,
            title: language.text("notification.daily.title"),
            snoozeTenMinutesTitle: language.text("notification.snooze.10m"),
            snoozeOneHourTitle: language.text("notification.snooze.1h")
        )
    }

    private func activateExistingInstanceAndTerminateIfNeeded() -> Bool {
        guard shouldTerminateAsDuplicate else { return false }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let runningApplications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).filter { !$0.isTerminated }
        runningApplications.first { $0.processIdentifier != currentProcessIdentifier }?
            .activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
        return true
    }

    private static var isDuplicateInstance: Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return SingleInstancePolicy.shouldTerminateCurrentProcess(
            currentProcessIdentifier: currentProcessIdentifier,
            runningProcessIdentifiers: NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).filter { !$0.isTerminated }.map(\.processIdentifier)
        )
    }
}

private struct MenuBarContent: View {
    let store: QuotaStore
    let windowController: FloatingWindowController
    let language: LanguageSettings
    let notificationService: QuotaNotificationService
    let backupController: ConfigurationBackupController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if store.providers.isEmpty {
            Text(language.text(store.errorMessageKey ?? "menu.loading"))
        } else {
            ForEach(store.providers) { provider in
                Text(menuSummary(for: provider))
            }
        }
        Divider()
        Button(language.text("menu.show")) { windowController.expandAndShow() }
        Button(language.text("menu.refresh")) { Task { await store.refresh() } }
        Button(language.text("menu.settings")) { showSettings() }
        Divider()
        Button(language.text("menu.exportConfiguration")) {
            backupController.exportConfiguration(language: language)
        }
        Button(language.text("menu.importConfiguration")) { importConfiguration() }
        Divider()
        Button(language.text("menu.quit")) { NSApp.terminate(nil) }
    }

    private func menuSummary(for provider: ProviderUsage) -> String {
        var parts = [provider.displayName]
        if let session = provider.session { parts.append("5h \(QuotaFormatters.percent(session.remainingPercent))") }
        if let weekly = provider.weekly {
            parts.append("\(language.text("menu.weekly.short")) \(QuotaFormatters.percent(weekly.remainingPercent))")
        }
        return parts.joined(separator: " · ")
    }

    private func showSettings() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
        }
    }

    private func importConfiguration() {
        guard let result = backupController.chooseConfigurationToImport(language: language) else { return }
        switch result {
        case .failure:
            backupController.showImportFailure(language: language)
        case .success(let backup):
            language.language = backup.language
            Task {
                _ = await notificationService.synchronizeReminders(
                    backup.dailyReminders,
                    title: language.text("notification.daily.title"),
                    snoozeTenMinutesTitle: language.text("notification.snooze.10m"),
                    snoozeOneHourTitle: language.text("notification.snooze.1h")
                )
                await store.refresh()
                backupController.showImportSuccess(language: language)
            }
        }
    }
}

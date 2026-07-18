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
                language: appDelegate.language
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
                store: appDelegate.store
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let language = LanguageSettings()
    let notificationService = QuotaNotificationService()
    lazy var store = QuotaStore(notificationService: notificationService, language: language)
    lazy var windowController = FloatingWindowController(store: store, language: language)
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController.show()
        refreshTask = Task { await store.start() }
        Task {
            await notificationService.requestAuthorization()
            await restoreDailyReminders()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
    }

    private func restoreDailyReminders() async {
        let configurations = DailyReminderPreferences.loadAll()
        guard !configurations.isEmpty else { return }
        _ = await notificationService.synchronizeReminders(
            configurations,
            title: language.text("notification.daily.title"),
            snoozeTenMinutesTitle: language.text("notification.snooze.10m"),
            snoozeOneHourTitle: language.text("notification.snooze.1h")
        )
    }
}

private struct MenuBarContent: View {
    let store: QuotaStore
    let windowController: FloatingWindowController
    let language: LanguageSettings
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
}

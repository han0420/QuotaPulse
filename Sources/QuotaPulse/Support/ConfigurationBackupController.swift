import AppKit
import UniformTypeIdentifiers

@MainActor
final class ConfigurationBackupController {
    func exportConfiguration(language: LanguageSettings) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "QuotaPulse-configuration.json"
        panel.title = language.text("backup.export.panelTitle")
        panel.prompt = language.text("backup.export.prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try AppConfigurationBackupService.exportData()
            try data.write(to: url, options: .atomic)
            showAlert(
                title: language.text("backup.export.success.title"),
                message: language.text("backup.export.success.message")
            )
        } catch {
            showAlert(
                title: language.text("backup.export.failure.title"),
                message: language.text("backup.failure.message"),
                style: .warning
            )
        }
    }

    func chooseConfigurationToImport(
        language: LanguageSettings
    ) -> Result<AppConfigurationBackup, Error>? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = language.text("backup.import.panelTitle")
        panel.prompt = language.text("backup.import.prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            return .success(try AppConfigurationBackupService.importData(Data(contentsOf: url)))
        } catch {
            return .failure(error)
        }
    }

    func showImportSuccess(language: LanguageSettings) {
        showAlert(
            title: language.text("backup.import.success.title"),
            message: language.text("backup.import.success.message")
        )
    }

    func showImportFailure(language: LanguageSettings) {
        showAlert(
            title: language.text("backup.import.failure.title"),
            message: language.text("backup.failure.message"),
            style: .warning
        )
    }

    private func showAlert(
        title: String,
        message: String,
        style: NSAlert.Style = .informational
    ) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

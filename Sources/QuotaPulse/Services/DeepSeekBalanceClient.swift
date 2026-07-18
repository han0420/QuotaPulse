import Foundation

struct DeepSeekBalanceProcessCommand: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
}

enum DeepSeekBalanceClient {
    static let fixedTemplate = DeepSeekBalanceConfiguration.defaultCurlTemplate

    static func command(template: String, apiKey: String) -> DeepSeekBalanceProcessCommand? {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, template.contains("<API_KEY>") else { return nil }
        guard let parsedTokens = tokenize(template) else { return nil }
        let tokens = parsedTokens.map { $0.replacingOccurrences(of: "<API_KEY>", with: trimmedKey) }
        guard tokens.first == "curl", tokens.dropFirst().contains("https://api.deepseek.com/user/balance") else { return nil }
        return DeepSeekBalanceProcessCommand(executableURL: URL(fileURLWithPath: "/usr/bin/curl"), arguments: Array(tokens.dropFirst()))
    }

    static func fixedCommand(apiKey: String) -> DeepSeekBalanceProcessCommand? {
        command(template: fixedTemplate, apiKey: apiKey)
    }

    static func fetch(configuration: DeepSeekBalanceConfiguration) async -> DeepSeekBalance? {
        guard configuration.isEnabled,
              let key = DeepSeekAPIKeyStore.load(),
              let command = command(template: configuration.curlTemplate, apiKey: key) else { return nil }
        let process = Process()
        let output = Pipe()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return try DeepSeekBalanceParser.parse(data: output.fileHandleForReading.readDataToEndOfFile())
        } catch { return nil }
    }

    private static func tokenize(_ template: String) -> [String]? {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false

        func appendCurrent() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current = ""
        }

        for character in template {
            if escaped {
                if character != "\n" { current.append(character) }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if let activeQuote = quote {
                if character == activeQuote { quote = nil } else { current.append(character) }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character.isWhitespace {
                appendCurrent()
            } else {
                current.append(character)
            }
        }
        guard quote == nil else { return nil }
        if escaped { current.append("\\") }
        appendCurrent()
        return tokens
    }
}

enum DeepSeekSettingsValidation {
    enum Result: Equatable {
        case valid
        case missingAPIKey
        case invalidTemplate
    }

    static func validate(isEnabled: Bool, apiKey: String, curlTemplate: String) -> Result {
        guard isEnabled else { return .valid }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .missingAPIKey }
        return DeepSeekBalanceClient.command(template: curlTemplate, apiKey: apiKey) == nil
            ? .invalidTemplate
            : .valid
    }
}

enum DeepSeekAPIKeyStore {
    private static let storageKey = "QuotaPulse.deepSeekBalance.apiKey"

    static func save(_ key: String, to defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: storageKey)
    }

    static func load(from defaults: UserDefaults = .standard) -> String? {
        let value = defaults.string(forKey: storageKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

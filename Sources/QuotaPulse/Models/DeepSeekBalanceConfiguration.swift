import Foundation

struct DeepSeekBalanceConfiguration: Codable, Equatable, Sendable {
    static let defaultCurlTemplate = "curl -L -X GET 'https://api.deepseek.com/user/balance' -H 'Accept: application/json' -H 'Authorization: Bearer <API_KEY>'"
    private static let storageKey = "QuotaPulse.v2.deepSeekBalance.configuration"

    var isEnabled: Bool
    var curlTemplate: String

    init(isEnabled: Bool = false, curlTemplate: String = Self.defaultCurlTemplate) {
        self.isEnabled = isEnabled
        self.curlTemplate = curlTemplate
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    static func save(_ value: Self, to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(value), forKey: storageKey)
    }
}

struct DeepSeekBalance: Decodable, Equatable, Sendable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    struct BalanceInfo: Decodable, Equatable, Sendable {
        let currency: String
        let totalBalance: String
    }

    var displayLines: [String] { balanceInfos.map { "\($0.currency) \($0.totalBalance)" } }
}

enum DeepSeekBalanceParser {
    static func parse(data: Data) throws -> DeepSeekBalance {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(DeepSeekBalance.self, from: data)
    }
}

import Foundation
import Network
import Security

enum LocalNotificationHTTPError: Error, Equatable {
    case badRequest
    case unauthorized
    case methodNotAllowed
    case notFound
}

struct LocalNotificationHTTPRequest: Equatable {
    let title: String
    let body: String

    static func parse(raw: String, token: String) -> Result<Self, LocalNotificationHTTPError> {
        guard let headerEnd = raw.range(of: "\r\n\r\n") else { return .failure(.badRequest) }
        let header = String(raw[..<headerEnd.lowerBound])
        let body = String(raw[headerEnd.upperBound...])
        let lines = header.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else { return .failure(.badRequest) }
        let parts = requestLine.split(separator: " ")
        guard parts.count == 3 else { return .failure(.badRequest) }
        guard parts[1] == "/v1/notifications" else { return .failure(.notFound) }
        guard parts[0] == "POST" else { return .failure(.methodNotAllowed) }

        let headers = Dictionary(uniqueKeysWithValues: lines.dropFirst().compactMap { line -> (String, String)? in
            guard let separator = line.firstIndex(of: ":") else { return nil }
            return (String(line[..<separator]).lowercased(), String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces))
        })
        guard headers["authorization"] == "Bearer \(token)" else { return .failure(.unauthorized) }
        guard body.utf8.count <= 16 * 1024,
              let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.title.isEmpty, !payload.body.isEmpty,
              payload.title.count <= 1_000, payload.body.count <= 1_000 else {
            return .failure(.badRequest)
        }
        return .success(Self(title: payload.title, body: payload.body))
    }

    private struct Payload: Decodable {
        let title: String
        let body: String
    }
}

final class LocalNotificationHTTPAPI: @unchecked Sendable {
    static let port: UInt16 = 37_821
    private let listener: NWListener
    private let token: String
    private let sendNotification: @Sendable (String, String) async -> Void
    private let queue = DispatchQueue(label: "com.cmsjcm.QuotaPulse.notification-http")

    init(token: String, sendNotification: @escaping @Sendable (String, String) async -> Void) throws {
        self.token = token
        self.sendNotification = sendNotification
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!)
        listener.parameters.requiredInterfaceType = .loopback
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        listener.start(queue: queue)
    }

    func stop() { listener.cancel() }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let raw = String(data: data, encoding: .utf8) else { connection.cancel(); return }
            if raw.hasPrefix("OPTIONS /v1/notifications ") {
                self.respond(connection, status: "204 No Content", cors: true)
                return
            }
            let result = LocalNotificationHTTPRequest.parse(raw: raw, token: self.token)
            Task {
                switch result {
                case let .success(request):
                    await self.sendNotification(request.title, request.body)
                    self.respond(connection, status: "202 Accepted", cors: true)
                case let .failure(error):
                    let status: String = switch error {
                    case .unauthorized: "401 Unauthorized"
                    case .methodNotAllowed: "405 Method Not Allowed"
                    case .notFound: "404 Not Found"
                    case .badRequest: "400 Bad Request"
                    }
                    self.respond(connection, status: status, cors: true)
                }
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String, cors: Bool = false) {
        let corsHeaders = cors ? "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Private-Network: true\r\nAccess-Control-Allow-Methods: POST, OPTIONS\r\nAccess-Control-Allow-Headers: Authorization, Content-Type\r\n" : ""
        let response = "HTTP/1.1 \(status)\r\n\(corsHeaders)Content-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}

enum LocalNotificationHTTPTokenStore {
    private static let key = "QuotaPulse.v2.localNotificationHTTP.token"

    static func loadOrCreate(from defaults: UserDefaults = .standard) -> String {
        if let token = defaults.string(forKey: key), !token.isEmpty { return token }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = Data(bytes).base64EncodedString()
        defaults.set(token, forKey: key)
        return token
    }
}

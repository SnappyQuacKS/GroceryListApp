import Foundation

struct ServerState: Codable {
    var lists:   [GroceryList]
    var items:   [Item]
    var entries: [ListEntry]
    var users:   [AppUser]
}

struct NetworkService {
    let baseURL: String

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    // ── Connectivity check ───────────────────────────────────────────────────

    func checkHealth() async throws {
        guard let url = URL(string: "\(baseURL)/health") else { throw URLError(.badURL) }
        let (_, response) = try await Self.session.data(from: url)
        try validate(response)
    }

    // ── Pull full state from server (scoped to userId) ───────────────────────

    func fetchState(userId: String) async throws -> ServerState {
        guard let url = URL(string: "\(baseURL)/state?user_id=\(userId.urlEncoded)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await Self.session.data(from: url)
        try validate(response)
        return try decoder.decode(ServerState.self, from: data)
    }

    // ── Push full state to server (scoped to userId) ─────────────────────────

    func pushState(_ state: ServerState, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/state?user_id=\(userId.urlEncoded)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(state)
        let (_, response) = try await Self.session.data(for: req)
        try validate(response)
    }

    // ── Sign in against server ───────────────────────────────────────────────

    func signIn(username: String, passwordHash: String) async throws -> AppUser? {
        guard let url = URL(string: "\(baseURL)/auth/signin") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["username": username, "passwordHash": passwordHash])
        let (data, response) = try await Self.session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? decoder.decode(AppUser.self, from: data)
    }

    // ── Sign up on server ────────────────────────────────────────────────────

    func signUp(username: String, passwordHash: String) async throws -> AppUser? {
        guard let url = URL(string: "\(baseURL)/auth/signup") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["username": username, "passwordHash": passwordHash])
        let (data, response) = try await Self.session.data(for: req)
        guard let code = (response as? HTTPURLResponse)?.statusCode, code == 200 else { return nil }
        return try? decoder.decode(AppUser.self, from: data)
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private var decoder: JSONDecoder { JSONDecoder() }
    private var encoder: JSONEncoder { JSONEncoder() }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

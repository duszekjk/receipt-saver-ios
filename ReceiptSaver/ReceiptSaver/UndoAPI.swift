import Foundation

struct UndoStatus: Codable {
    let can_undo: Bool
    let label: String
    let operation_type: String?
    let remaining: Int
    let created_at: String?
    let undone_label: String?
}

extension APIClient {
    func undoStatus() async throws -> UndoStatus {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("undo/status/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "GET"
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: nil)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(UndoStatus.self, from: data)
        }.value
    }

    func undoLastOperation() async throws -> UndoStatus {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("undo/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "POST"
        request.httpBody = Data()
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: Data())
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(UndoStatus.self, from: data)
        }.value
    }
}
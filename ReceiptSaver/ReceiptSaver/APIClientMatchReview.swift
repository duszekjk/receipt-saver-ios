import Foundation

extension APIClient {
    func acceptMatch(candidateID: Int) async throws -> MatchCandidate {
        try await sendMatchAction(path: "matches/review/\(candidateID)/accept/")
    }

    func rejectMatch(candidateID: Int) async throws -> MatchCandidate {
        try await sendMatchAction(path: "matches/review/\(candidateID)/reject/")
    }

    private func sendMatchAction(path: String) async throws -> MatchCandidate {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.httpBody = Data()
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: request.httpBody)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError(statusCode: http.statusCode, body: body)
        }
        return try JSONDecoder().decode(MatchCandidate.self, from: data)
    }
}

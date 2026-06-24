import Foundation

extension APIClient {
    func bankImportStatus(jobID: String) async throws -> BankImportJobStatus {
        var request = URLRequest(url: baseURL.appendingPathComponent("bank/import/status/\(jobID)/"), cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: request.httpBody)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError(statusCode: http.statusCode, body: body)
        }
        return try JSONDecoder().decode(BankImportJobStatus.self, from: data)
    }
}

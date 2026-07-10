import Foundation

struct PurchaseEmailImportResult: Decodable {
    let matched: Bool
    let transaction_id: Int?
    let merchant_name: String
    let purchase_description: String
    let purchased_at: String?
    let amount: String
    let currency: String
    let category: String
    let subcategory: String
    let message: String
}

struct EmailImportAttachment {
    let filename: String
    let mimeType: String
    let data: Data
}

extension APIClient {
    func importPurchaseEmail(text: String, attachments: [EmailImportAttachment]) async throws -> PurchaseEmailImportResult {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        body.append(text)
        body.append("\r\n")

        for attachment in attachments {
            let safeFilename = attachment.filename.replacingOccurrences(of: "\"", with: "")
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(safeFilename)\"\r\n")
            body.append("Content-Type: \(attachment.mimeType)\r\n\r\n")
            body.append(attachment.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")

        var request = URLRequest(
            url: baseURL.appendingPathComponent("imports/email/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(PurchaseEmailImportResult.self, from: data)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(string.data(using: .utf8) ?? Data())
    }
}

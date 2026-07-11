import Foundation

struct ReceiptItemUpdatePayload: Encodable {
    let id: Int
    let name: String
    let quantity: String?
    let unit_price: String?
    let paid_price: String?
    let regular_price: String?
    let discount_amount: String?
    let promotion_name: String?
    let is_discounted: Bool
    let category: String?
    let subcategory: String?
}

struct ReceiptUpdatePayload: Encodable {
    let merchant_name: String
    let purchased_at: String?
    let total_amount: String?
    let currency: String
    let payment_method: String
    let items: [ReceiptItemUpdatePayload]
}

extension APIClient {
    func updateReceipt(id: Int, payload: ReceiptUpdatePayload) async throws -> Receipt {
        let encoder = JSONEncoder()
        let body = try encoder.encode(payload)
        var request = URLRequest(
            url: baseURL.appendingPathComponent("receipts/\(id)/edit/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "PATCH"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        LocalCache.shared.upsertReceipt(receipt)
        return receipt
    }

    func deleteReceipt(id: Int) async throws {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("receipts/\(id)/delete/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "DELETE"
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &request, credentials: credentials, body: nil)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

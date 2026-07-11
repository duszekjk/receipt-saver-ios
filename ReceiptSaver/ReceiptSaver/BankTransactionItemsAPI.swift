import Foundation

struct BankTransactionManualItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: String
    var category: String
    var subcategory: String

    enum CodingKeys: String, CodingKey {
        case name, amount, category, subcategory
    }
}

struct BankTransactionItemsDocument: Codable {
    let transaction_id: Int
    let merchant_name: String
    let description: String
    let amount: String
    let currency: String
    let items: [BankTransactionManualItem]
}

private struct BankTransactionItemsUpdate: Encodable {
    let items: [BankTransactionManualItem]
}

extension APIClient {
    func bankTransactionItems(transactionID: Int) async throws -> BankTransactionItemsDocument {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("bank/transactions/\(transactionID)/items/"),
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
        return try JSONDecoder().decode(BankTransactionItemsDocument.self, from: data)
    }

    func updateBankTransactionItems(transactionID: Int, items: [BankTransactionManualItem]) async throws -> BankTransactionItemsDocument {
        let body = try JSONEncoder().encode(BankTransactionItemsUpdate(items: items))
        var request = URLRequest(
            url: baseURL.appendingPathComponent("bank/transactions/\(transactionID)/items/"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "PUT"
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
        return try JSONDecoder().decode(BankTransactionItemsDocument.self, from: data)
    }
}

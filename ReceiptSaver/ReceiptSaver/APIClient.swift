import Foundation
import UIKit

struct APIError: Error, LocalizedError {
    let statusCode: Int
    let body: String
    var errorDescription: String? {
        if let data = body.data(using: .utf8), let payload = try? JSONDecoder().decode(APIErrorPayload.self, from: data) { return payload.detail }
        return body.isEmpty ? "HTTP \(statusCode)" : "HTTP \(statusCode): \(body)"
    }
}

struct APIErrorPayload: Codable {
    let detail: String?
    let code: String?
    let requires_manual_date: Bool?
    let receipt: Receipt?
}

struct ReceiptUploadResponse {
    let receipt: Receipt
    let requiresManualDate: Bool
    let message: String
}

final class APIClient {
    static let shared = APIClient()
    var baseURL = URL(string: "https://www.duszekjk.com/receipts")!

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = method
        req.httpBody = body
        return req
    }

    private func signedRequest(_ request: URLRequest) -> URLRequest {
        var req = request
        if let credentials = CredentialStore.shared.load() { HMACSigner.sign(request: &req, credentials: credentials, body: req.httpBody) }
        return req
    }

    private func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: signedRequest(request))
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, http) = try await response(for: request)
        if !(200...299).contains(http.statusCode) { throw APIError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "") }
        return data
    }

    func me() async throws -> MobileProfile {
        let value = try await data(for: request("me/"))
        return try JSONDecoder().decode(MobileProfile.self, from: value)
    }

    func dashboard(period: String, month: String, category: String, limit: Int) async throws -> DashboardStats {
        let url = baseURL.appendingPathComponent("dashboard/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "period", value: period), URLQueryItem(name: "limit", value: String(limit))]
        if period == "month", !month.isEmpty { items.append(URLQueryItem(name: "month", value: month)) }
        if !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
        components.queryItems = items
        var req = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = "GET"
        let value = try await data(for: req)
        return try JSONDecoder().decode(DashboardStats.self, from: value)
    }

    func subcategoryDetails(month: String, subcategory: String) async throws -> SubcategoryDetails {
        let url = baseURL.appendingPathComponent("dashboard/subcategory/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "month", value: month), URLQueryItem(name: "subcategory", value: subcategory)]
        var req = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = "GET"
        let value = try await data(for: req)
        return try JSONDecoder().decode(SubcategoryDetails.self, from: value)
    }

    func summaries(period: String) async throws -> [SummaryRow] {
        let url = baseURL.appendingPathComponent("summaries/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "period", value: period)]
        var req = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = "GET"
        let value = try await data(for: req)
        let rows = try JSONDecoder().decode([SummaryRow].self, from: value)
        LocalCache.shared.saveSummaries(rows, period: period)
        return rows
    }

    func receipts() async throws -> [Receipt] {
        let value = try await data(for: request("receipts/"))
        let rows = try JSONDecoder().decode([Receipt].self, from: value)
        LocalCache.shared.saveReceipts(rows)
        return rows
    }

    func matchCandidates() async throws -> [MatchCandidate] {
        let value = try await data(for: request("matches/review/"))
        return try JSONDecoder().decode([MatchCandidate].self, from: value)
    }

    func acceptMatchCandidate(id: Int) async throws -> MatchCandidate {
        let value = try await data(for: request("matches/review/\(id)/accept/", method: "POST", body: Data()))
        return try JSONDecoder().decode(MatchCandidate.self, from: value)
    }

    func rejectMatchCandidate(id: Int) async throws -> MatchCandidate {
        let value = try await data(for: request("matches/review/\(id)/reject/", method: "POST", body: Data()))
        return try JSONDecoder().decode(MatchCandidate.self, from: value)
    }

    func uploadReceipt(image: UIImage) async throws -> ReceiptUploadResponse {
        let processed = image.preprocessedForReceipt()
        guard let imageData = processed.jpegData(compressionQuality: 0.72) else { throw URLError(.cannotDecodeContentData) }
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt_gray.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        var req = request("receipts/scan/", method: "POST", body: body)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (value, http) = try await response(for: req)
        if http.statusCode == 202 {
            let payload = try JSONDecoder().decode(APIErrorPayload.self, from: value)
            guard let receipt = payload.receipt else { throw APIError(statusCode: http.statusCode, body: String(data: value, encoding: .utf8) ?? "") }
            LocalCache.shared.upsertReceipt(receipt)
            return ReceiptUploadResponse(receipt: receipt, requiresManualDate: payload.requires_manual_date == true, message: payload.detail ?? "Data paragonu jest nieczytelna.")
        }
        guard (200...299).contains(http.statusCode) else { throw APIError(statusCode: http.statusCode, body: String(data: value, encoding: .utf8) ?? "") }
        let receipt = try JSONDecoder().decode(Receipt.self, from: value)
        LocalCache.shared.upsertReceipt(receipt)
        return ReceiptUploadResponse(receipt: receipt, requiresManualDate: false, message: "")
    }

    func setReceiptDate(receiptID: Int, date: Date) async throws -> Receipt {
        let body = try JSONSerialization.data(withJSONObject: ["purchased_at": ISO8601DateFormatter().string(from: date)])
        var req = request("receipts/\(receiptID)/date/", method: "POST", body: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let value = try await data(for: req)
        let receipt = try JSONDecoder().decode(Receipt.self, from: value)
        LocalCache.shared.upsertReceipt(receipt)
        return receipt
    }

    func importBankStatement(fileURL: URL, bank: String) async throws -> BankImportJobStatus {
        let boundary = UUID().uuidString
        var body = Data()
        let filename = fileURL.lastPathComponent.isEmpty ? "statement.csv" : fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"bank\"\r\n\r\n")
        body.append(bank)
        body.append("\r\n--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: text/csv\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        var req = request("bank/statement/", method: "POST", body: body)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let value = try await data(for: req)
        return try JSONDecoder().decode(BankImportJobStatus.self, from: value)
    }
}

private extension Data {
    mutating func append(_ string: String) { append(string.data(using: .utf8)!) }
}

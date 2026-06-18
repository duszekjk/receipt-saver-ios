import Foundation
import UIKit

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "https://example.com/api")!
    var bearerToken: String?

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = method
        if let token = bearerToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func summaries(period: String) async throws -> [SummaryRow] {
        let url = baseURL.appendingPathComponent("summaries/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "period", value: period)]
        var req = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        if let token = bearerToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        let rows = try JSONDecoder().decode([SummaryRow].self, from: data)
        LocalCache.shared.saveSummaries(rows, period: period)
        return rows
    }

    func receipts() async throws -> [Receipt] {
        let (data, _) = try await URLSession.shared.data(for: request("receipts/"))
        let rows = try JSONDecoder().decode([Receipt].self, from: data)
        LocalCache.shared.saveReceipts(rows)
        return rows
    }

    func matchCandidates() async throws -> [MatchCandidate] {
        let (data, _) = try await URLSession.shared.data(for: request("matches/review/"))
        return try JSONDecoder().decode([MatchCandidate].self, from: data)
    }

    func uploadReceipt(image: UIImage) async throws -> Receipt {
        let processed = image.preprocessedForReceipt()
        guard let imageData = processed.jpegData(compressionQuality: 0.72) else {
            throw URLError(.cannotDecodeContentData)
        }
        var req = request("receipts/scan/", method: "POST")
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt_gray.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: req)
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        LocalCache.shared.upsertReceipt(receipt)
        return receipt
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(string.data(using: .utf8)!)
    }
}

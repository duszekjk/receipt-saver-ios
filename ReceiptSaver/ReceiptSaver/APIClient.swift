import Foundation
import UIKit

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "https://example.com/api")!

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = method
        req.httpBody = body
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &req, credentials: credentials, body: body)
        }
        return req
    }

    func me() async throws -> MobileProfile {
        let (data, _) = try await URLSession.shared.data(for: request("me/"))
        return try JSONDecoder().decode(MobileProfile.self, from: data)
    }

    func summaries(period: String) async throws -> [SummaryRow] {
        let url = baseURL.appendingPathComponent("summaries/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "period", value: period)]
        var req = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = "GET"
        if let credentials = CredentialStore.shared.load() {
            HMACSigner.sign(request: &req, credentials: credentials, body: nil)
        }
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
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt_gray.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        var req = request("receipts/scan/", method: "POST", body: body)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
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

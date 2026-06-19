import CryptoKit
import Foundation

struct HMACSigner {
    static func sign(request: inout URLRequest, credentials: AppCredentials, body: Data?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        let query = request.url?.query.map { "?\($0)" } ?? ""
        let fullPath = path + query
        let bodyHash = SHA256.hash(data: body ?? Data()).map { String(format: "%02x", $0) }.joined()
        let payload = [method.uppercased(), fullPath, timestamp, nonce, bodyHash].joined(separator: "\n")
        let key = SymmetricKey(data: Data(credentials.secretKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key).map { String(format: "%02x", $0) }.joined()

        request.setValue(credentials.deviceID, forHTTPHeaderField: "X-Receipt-Device")
        request.setValue(timestamp, forHTTPHeaderField: "X-Receipt-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Receipt-Nonce")
        request.setValue(signature, forHTTPHeaderField: "X-Receipt-Signature")
    }
}

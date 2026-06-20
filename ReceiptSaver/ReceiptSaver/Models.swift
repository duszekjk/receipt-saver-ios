import Foundation

struct MobileProfile: Codable {
    let user_id: Int
    let username: String
    let is_superuser: Bool
    let profile_id: Int?
    let display_name: String
    let family_id: Int?
    let family_name: String
}

struct ReceiptItem: Identifiable, Codable {
    let id: Int
    let name: String
    let paid_price: String?
    let regular_price: String?
    let discount_amount: String?
    let promotion_name: String?
    let is_discounted: Bool
    let category: String?
}

struct Receipt: Identifiable, Codable {
    let id: Int
    let merchant_name: String
    let purchased_at: String?
    let total_amount: String?
    let currency: String
    let duplicate_of: Int?
    let discount_total: String?
    let items: [ReceiptItem]
}

struct SummaryRow: Identifiable, Codable {
    var id: String { String(describing: period) + "-" + String(describing: user_id) }
    let period: String?
    let user_id: Int?
    let spent: String
    let saved: String
    let halfyear: Int?

    enum CodingKeys: String, CodingKey {
        case period, user_id, spent, saved, halfyear
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(String.self, forKey: .period)
        user_id = try container.decodeIfPresent(Int.self, forKey: .user_id)
        spent = try container.decodeFlexibleString(forKey: .spent) ?? "0"
        saved = try container.decodeFlexibleString(forKey: .saved) ?? "0"
        halfyear = try container.decodeIfPresent(Int.self, forKey: .halfyear)
    }

    init(period: String?, user_id: Int?, spent: String, saved: String, halfyear: Int?) {
        self.period = period
        self.user_id = user_id
        self.spent = spent
        self.saved = saved
        self.halfyear = halfyear
    }
}

struct BankTransaction: Identifiable, Codable {
    let id: Int
    let bank: String
    let booked_at: String?
    let transaction_at: String?
    let merchant_name: String
    let amount: String
}

struct MatchCandidate: Identifiable, Codable {
    let id: Int
    let score: Double
    let status: String
    let receipt: Receipt
    let bank_transaction: BankTransaction
}

extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return String(format: "%.2f", value)
        }
        return nil
    }
}

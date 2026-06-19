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

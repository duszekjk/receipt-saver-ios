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

struct Receipt: Identifiable, Codable {
    let id: Int
    let merchant_name: String
    let purchased_at: String?
    let total_amount: String?
    let currency: String
    let payment_method: String?
    let duplicate_of: Int?
    let discount_total: String?
    let items: [ReceiptItem]
}

struct SummaryRow: Identifiable, Codable {
    var id: String { String(describing: period) + "-" + String(describing: user_id) }
    let period: String?
    let user_id: Int?
    let spent: Double
    let saved: Double
    let halfyear: Int?

    enum CodingKeys: String, CodingKey { case period, user_id, spent, saved, halfyear }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(String.self, forKey: .period)
        user_id = try container.decodeIfPresent(Int.self, forKey: .user_id)
        spent = try container.decodeFlexibleDouble(forKey: .spent) ?? 0
        saved = try container.decodeFlexibleDouble(forKey: .saved) ?? 0
        halfyear = try container.decodeIfPresent(Int.self, forKey: .halfyear)
    }

    init(period: String?, user_id: Int?, spent: Double, saved: Double, halfyear: Int?) {
        self.period = period
        self.user_id = user_id
        self.spent = spent
        self.saved = saved
        self.halfyear = halfyear
    }
}

struct DashboardCards: Codable {
    let spent: Double
    let saved: Double
    let receipt_count: Int
    let store_count: Int
}

struct DashboardBarRow: Identifiable, Codable {
    var id: String { name }
    let name: String
    let spent: Double
    let saved: Double
    let count: Int
}

typealias DashboardTimelineRow = DashboardBarRow

struct DashboardStats: Codable {
    let period: String
    let selected_month: String
    let available_months: [String]
    let category_filter: String
    let cards: DashboardCards
    let available_categories: [String]
    let timeline: [DashboardTimelineRow]
    let categories: [DashboardBarRow]
    let subcategories: [DashboardBarRow]
    let products: [DashboardBarRow]
    let stores: [DashboardBarRow]

    enum CodingKeys: String, CodingKey {
        case period, selected_month, available_months, category_filter, cards, available_categories, timeline, categories, subcategories, products, stores
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(String.self, forKey: .period)
        selected_month = try container.decodeIfPresent(String.self, forKey: .selected_month) ?? ""
        available_months = try container.decodeIfPresent([String].self, forKey: .available_months) ?? []
        category_filter = try container.decode(String.self, forKey: .category_filter)
        cards = try container.decode(DashboardCards.self, forKey: .cards)
        available_categories = try container.decode([String].self, forKey: .available_categories)
        timeline = try container.decodeIfPresent([DashboardTimelineRow].self, forKey: .timeline) ?? []
        categories = try container.decode([DashboardBarRow].self, forKey: .categories)
        subcategories = try container.decode([DashboardBarRow].self, forKey: .subcategories)
        products = try container.decode([DashboardBarRow].self, forKey: .products)
        stores = try container.decode([DashboardBarRow].self, forKey: .stores)
    }
}

struct BankImportResult: Codable {
    let created: Int
    let classified: Int?
}

struct BankTransaction: Identifiable, Codable {
    let id: Int
    let bank: String
    let booked_at: String?
    let transaction_at: String?
    let merchant_name: String
    let amount: String
    let currency: String?
    let raw_description: String?
    let corrected_description: String?
    let category: String?
    let subcategory: String?
}

struct MatchCandidate: Identifiable, Codable {
    let id: Int
    let score: Double
    let status: String
    let reason: [String: MatchReasonValue]?
    let receipt: Receipt
    let bank_transaction: BankTransaction
}

enum MatchReasonValue: Codable, CustomStringConvertible {
    case string(String)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        self = .string("")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    var description: String {
        switch self {
        case .string(let value): return value
        case .double(let value): return String(format: "%.2f", value)
        case .bool(let value): return value ? "tak" : "nie"
        }
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Double(value.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}

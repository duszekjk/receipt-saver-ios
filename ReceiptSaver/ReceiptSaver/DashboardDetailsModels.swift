import Foundation

struct SubcategoryPurchaseDetail: Identifiable, Decodable {
    var id: String { "\(receipt_id ?? -1)-\(date)-\(merchant)-\(spent)-\(name)" }
    let name: String
    let merchant: String
    let spent: Double
    let saved: Double
    let origin: String
    let date: String
    let receipt_id: Int?
    let quantity: Double?
    let unit_price: Double?
    let regular_price: Double?
    let discount_amount: Double
    let promotion_name: String

    enum CodingKeys: String, CodingKey {
        case name, merchant, spent, saved, date, receipt_id, quantity, unit_price, regular_price, discount_amount, promotion_name
        case origin = "source"
    }
}

struct SubcategoryDetailRow: Identifiable, Decodable {
    var id: String { name + "-" + merchant + "-" + origin }
    let name: String
    let merchant: String
    let spent: Double
    let count: Int
    let origin: String
    let details: [SubcategoryPurchaseDetail]

    enum CodingKeys: String, CodingKey {
        case name, merchant, spent, count, details
        case origin = "source"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        if let value = try container.decodeIfPresent(Double.self, forKey: .spent) {
            spent = value
        } else if let value = try container.decodeIfPresent(String.self, forKey: .spent) {
            spent = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
        } else {
            spent = 0
        }
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        origin = try container.decodeIfPresent(String.self, forKey: .origin) ?? ""
        details = try container.decodeIfPresent([SubcategoryPurchaseDetail].self, forKey: .details) ?? []
    }
}

struct SubcategoryDetails: Decodable {
    let month: String
    let subcategory: String
    let items: [SubcategoryDetailRow]

    enum CodingKeys: String, CodingKey {
        case month, subcategory, items, products
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decodeIfPresent(String.self, forKey: .month) ?? ""
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory) ?? ""
        if let rows = try container.decodeIfPresent([SubcategoryDetailRow].self, forKey: .items) {
            items = rows
        } else {
            items = try container.decodeIfPresent([SubcategoryDetailRow].self, forKey: .products) ?? []
        }
    }
}

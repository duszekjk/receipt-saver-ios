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
    var id: String { name + "-" + merchant + "-" + origin + "-" + String(spent) }
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

    init(name: String, merchant: String, spent: Double, count: Int, origin: String, details: [SubcategoryPurchaseDetail] = []) {
        self.name = name
        self.merchant = merchant
        self.spent = spent
        self.count = count
        self.origin = origin
        self.details = details
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
        let groupedRows = try container.decodeIfPresent([SubcategoryDetailRow].self, forKey: .items)
            ?? container.decodeIfPresent([SubcategoryDetailRow].self, forKey: .products)
            ?? []

        let concreteRows = groupedRows.flatMap { row -> [SubcategoryDetailRow] in
            guard !row.details.isEmpty else { return [row] }
            return row.details.map { detail in
                var context: [String] = []
                if !detail.merchant.isEmpty { context.append(detail.merchant) }
                if !detail.date.isEmpty { context.append(Self.displayDate(detail.date)) }
                if let quantity = detail.quantity { context.append("ilość: \(Self.number(quantity))") }
                if let unitPrice = detail.unit_price { context.append("cena jedn.: \(Self.money(unitPrice)) zł") }
                if detail.discount_amount > 0 { context.append("rabat: \(Self.money(detail.discount_amount)) zł") }
                if !detail.promotion_name.isEmpty { context.append(detail.promotion_name) }
                return SubcategoryDetailRow(
                    name: detail.name.isEmpty ? row.name : detail.name,
                    merchant: context.joined(separator: " • "),
                    spent: detail.spent,
                    count: 1,
                    origin: detail.origin,
                    details: [detail]
                )
            }
        }
        items = concreteRows.sorted { lhs, rhs in
            let leftDate = lhs.details.first?.date ?? ""
            let rightDate = rhs.details.first?.date ?? ""
            return leftDate > rightDate
        }
    }

    private static func displayDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        let output = DateFormatter()
        output.locale = Locale(identifier: "pl_PL")
        output.dateFormat = "dd.MM.yyyy HH:mm"
        return output.string(from: date)
    }

    private static func money(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }
}

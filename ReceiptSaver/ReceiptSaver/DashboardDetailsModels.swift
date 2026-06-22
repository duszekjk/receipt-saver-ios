import Foundation

struct SubcategoryDetailRow: Identifiable, Codable {
    var id: String { name + "-" + merchant + "-" + origin }
    let name: String
    let merchant: String
    let spent: Double
    let count: Int
    let origin: String

    enum CodingKeys: String, CodingKey {
        case name, merchant, spent, count
        case origin = "source"
    }
}

struct SubcategoryDetails: Codable {
    let month: String
    let subcategory: String
    let items: [SubcategoryDetailRow]
}

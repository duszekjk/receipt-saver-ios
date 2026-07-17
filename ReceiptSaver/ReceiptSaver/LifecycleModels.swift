import Foundation

struct ProductCycleRule: Codable, Identifiable {
    let id: Int
    let product_name: String
    let interval_days: Int
    let reminder_before_days: Int
    let enabled: Bool
    let last_purchase_at: String?
    let expected_next_purchase_at: String?
    let reminder_at: String?
    let too_frequent: Bool
}

struct ProductCycleSuggestionResponse: Codable {
    let suggestion: ProductCycleSuggestion?
    let sample_size: Int?
}

struct ProductCycleSuggestion: Codable {
    let interval_days: Int
    let reminder_before_days: Int
}

struct PurchaseSearchResult: Codable, Identifiable {
    let kind: String
    let id: Int
    let name: String
    let merchant: String
    let date: String?
    let amount: String
    let currency: String
    let category: String
    let subcategory: String
    let receipt_id: Int?
}

import Foundation

final class LocalCache {
    static let shared = LocalCache()
    private let defaults: UserDefaults
    private let summariesPrefix = "offline_summaries_"
    private let receiptsKey = "offline_receipts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSummaries(_ rows: [SummaryRow], period: String) {
        guard let data = try? JSONEncoder().encode(rows) else { return }
        defaults.set(data, forKey: summariesPrefix + period)
    }

    func loadSummaries(period: String) -> [SummaryRow] {
        guard let data = defaults.data(forKey: summariesPrefix + period),
              let rows = try? JSONDecoder().decode([SummaryRow].self, from: data) else {
            return []
        }
        return rows
    }

    func saveReceipts(_ receipts: [Receipt]) {
        guard let data = try? JSONEncoder().encode(receipts) else { return }
        defaults.set(data, forKey: receiptsKey)
    }

    func loadReceipts() -> [Receipt] {
        guard let data = defaults.data(forKey: receiptsKey),
              let rows = try? JSONDecoder().decode([Receipt].self, from: data) else {
            return []
        }
        return rows
    }

    func upsertReceipt(_ receipt: Receipt) {
        var receipts = loadReceipts()
        receipts.removeAll { $0.id == receipt.id }
        receipts.insert(receipt, at: 0)
        saveReceipts(receipts)
    }

    func clear() {
        defaults.removeObject(forKey: receiptsKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(summariesPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

import SwiftUI

struct ReceiptListView: View {
    @State private var receipts: [Receipt] = []
    @State private var errorMessage = ""

    var body: some View {
        List(receipts) { receipt in
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchant_name).font(.headline)
                Text("Suma: \(receipt.total_amount ?? "?") \(receipt.currency)")
                if let saved = receipt.discount_total { Text("Promocje: \(saved) zł") }
                if receipt.duplicate_of != nil { Text("Możliwy duplikat").font(.caption) }
            }
        }
        .navigationTitle("Paragony")
        .task { await load() }
    }

    private func load() async {
        do { receipts = try await APIClient.shared.receipts() }
        catch { errorMessage = error.localizedDescription }
    }
}

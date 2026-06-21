import SwiftUI

struct ReceiptListView: View {
    @State private var receipts: [Receipt] = []
    @State private var errorMessage = ""

    var body: some View {
        List(receipts) { receipt in
            VStack(alignment: .leading, spacing: 10) {
                Text(receipt.merchant_name.isEmpty ? "Nieznany sklep" : receipt.merchant_name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Suma: \(receipt.total_amount ?? "?") \(receipt.currency)")
                    .font(.title3)
                if let saved = receipt.discount_total {
                    Text("Oszczędzono: \(saved) zł")
                        .font(.title3)
                }
                if receipt.duplicate_of != nil {
                    Text("Możliwy duplikat")
                        .font(.headline)
                }
            }
            .padding(.vertical, 10)
        }
        .navigationTitle("Paragony")
        .task { await load() }
    }

    private func load() async {
        do { receipts = try await APIClient.shared.receipts() }
        catch { errorMessage = error.localizedDescription }
    }
}

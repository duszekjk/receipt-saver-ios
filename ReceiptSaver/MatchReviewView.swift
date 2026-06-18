import SwiftUI

struct MatchReviewView: View {
    @State private var candidates: [MatchCandidate] = []
    @State private var errorMessage = ""

    var body: some View {
        List(candidates) { candidate in
            VStack(alignment: .leading, spacing: 6) {
                Text("Score: \(String(format: "%.2f", candidate.score))").font(.headline)
                Text("Paragon: \(candidate.receipt.merchant_name), \(candidate.receipt.total_amount ?? "?") zł")
                Text("Bank: \(candidate.bank_transaction.merchant_name), \(candidate.bank_transaction.amount) zł")
                Text("Status: \(candidate.status)").font(.caption)
            }
        }
        .navigationTitle("Do weryfikacji")
        .task { await load() }
    }

    private func load() async {
        do { candidates = try await APIClient.shared.matchCandidates() }
        catch { errorMessage = error.localizedDescription }
    }
}

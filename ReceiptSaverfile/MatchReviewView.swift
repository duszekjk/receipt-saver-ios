import SwiftUI

struct MatchReviewView: View {
    @State private var candidates: [MatchCandidate] = []
    @State private var errorMessage = ""

    var body: some View {
        List(candidates) { candidate in
            VStack(alignment: .leading, spacing: 10) {
                Text("Dopasowanie: \(Int(candidate.score * 100))%")
                    .font(.title2)
                    .bold()
                Text("Paragon: \(candidate.receipt.merchant_name), \(candidate.receipt.total_amount ?? "?") zł")
                    .font(.title3)
                Text("Bank: \(candidate.bank_transaction.merchant_name), \(candidate.bank_transaction.amount) zł")
                    .font(.title3)
                Text("Status: \(candidate.status)")
                    .font(.headline)
            }
            .padding(.vertical, 10)
        }
        .navigationTitle("Do sprawdzenia")
        .task { await load() }
    }

    private func load() async {
        do { candidates = try await APIClient.shared.matchCandidates() }
        catch { errorMessage = error.localizedDescription }
    }
}

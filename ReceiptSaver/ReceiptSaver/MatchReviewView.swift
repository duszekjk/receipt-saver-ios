import SwiftUI

struct MatchReviewView: View {
    @State private var candidates: [MatchCandidate] = []
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundColor(.red) }
            }
            if candidates.isEmpty && !isLoading {
                Section { Text("Brak dopasowań do sprawdzenia").foregroundColor(.secondary) }
            }
            ForEach(candidates) { candidate in
                MatchCandidateCard(
                    candidate: candidate,
                    accept: { Task { await accept(candidate) } },
                    reject: { Task { await reject(candidate) } }
                )
            }
        }
        .navigationTitle("Dopasowania")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            candidates = try await APIClient.shared.matchCandidates()
            errorMessage = ""
        } catch {
            errorMessage = "Nie udało się pobrać dopasowań: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func accept(_ candidate: MatchCandidate) async {
        do {
            _ = try await APIClient.shared.acceptMatchCandidate(id: candidate.id)
            await load()
        } catch {
            errorMessage = "Nie udało się oznaczyć jako ta sama transakcja: \(error.localizedDescription)"
        }
    }

    private func reject(_ candidate: MatchCandidate) async {
        do {
            _ = try await APIClient.shared.rejectMatchCandidate(id: candidate.id)
            await load()
        } catch {
            errorMessage = "Nie udało się odrzucić dopasowania: \(error.localizedDescription)"
        }
    }
}

private struct MatchCandidateCard: View {
    let candidate: MatchCandidate
    let accept: () -> Void
    let reject: () -> Void
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dopasowanie \(Int(candidate.score * 100))%")
                    .font(.title3)
                Spacer()
                Text(candidate.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GroupBox("Paragon") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.receipt.merchant_name.isEmpty ? "Nieznany sklep" : candidate.receipt.merchant_name)
                    Text("Kwota: \(candidate.receipt.total_amount ?? "?") \(candidate.receipt.currency)")
                    Text("Data i godzina: \(candidate.receipt.purchased_at ?? "brak")")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Transakcja bankowa") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.bank_transaction.merchant_name.isEmpty ? "Brak kontrahenta" : candidate.bank_transaction.merchant_name)
                    Text("Kwota: \(candidate.bank_transaction.amount) \(candidate.bank_transaction.currency ?? "")")
                    Text("Data transakcji: \(candidate.bank_transaction.transaction_at ?? "brak")")
                    Text("Data księgowania: \(candidate.bank_transaction.booked_at ?? "brak")")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Szczegóły decyzji").font(.headline)
                    Text("Opis bankowy: \(candidate.bank_transaction.corrected_description ?? candidate.bank_transaction.raw_description ?? "brak")")
                    Text("Kategoria bankowa: \(candidate.bank_transaction.category ?? "brak") / \(candidate.bank_transaction.subcategory ?? "brak")")
                    if let reason = candidate.reason, !reason.isEmpty {
                        ForEach(reason.keys.sorted(), id: \.self) { key in
                            Text("\(key): \(reason[key]?.description ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Button(showDetails ? "Ukryj szczegóły" : "Pokaż szczegóły") {
                showDetails.toggle()
            }

            HStack(spacing: 10) {
                Button(action: accept) {
                    Text("Ta sama transakcja")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)

                Button(action: reject) {
                    Text("Inna")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
}

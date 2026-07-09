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
            _ = try await APIClient.shared.acceptMatch(candidateID: candidate.id)
            candidates.removeAll { $0.id == candidate.id }
            errorMessage = ""
        } catch {
            errorMessage = "Nie udało się oznaczyć jako ta sama transakcja: \(error.localizedDescription)"
        }
    }

    private func reject(_ candidate: MatchCandidate) async {
        do {
            _ = try await APIClient.shared.rejectMatch(candidateID: candidate.id)
            candidates.removeAll { $0.id == candidate.id }
            errorMessage = ""
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
                VStack(alignment: .leading, spacing: 8) {
                    detail("Sklep", candidate.receipt.merchant_name.isEmpty ? "Nieznany sklep" : candidate.receipt.merchant_name)
                    detail("Kwota", "\(candidate.receipt.total_amount ?? "?") \(candidate.receipt.currency)")
                    detail("Data i godzina", candidate.receipt.purchased_at ?? "brak")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Transakcja bankowa") {
                VStack(alignment: .leading, spacing: 8) {
                    detail("Kontrahent", candidate.bank_transaction.merchant_name.isEmpty ? "Brak kontrahenta" : candidate.bank_transaction.merchant_name)
                    detail("Opis", candidate.bank_transaction.corrected_description ?? candidate.bank_transaction.raw_description ?? "brak")
                    detail("Kwota", "\(candidate.bank_transaction.amount) \(candidate.bank_transaction.currency ?? "")")
                    detail("Data transakcji", candidate.bank_transaction.transaction_at ?? "brak")
                    detail("Data księgowania", candidate.bank_transaction.booked_at ?? "brak")
                    detail("Kategoria", "\(candidate.bank_transaction.category ?? "brak") / \(candidate.bank_transaction.subcategory ?? "brak")")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(showDetails ? "Ukryj szczegóły" : "Pokaż szczegóły") {
                showDetails.toggle()
            }
            .buttonStyle(.bordered)

            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Szczegóły dopasowania").font(.headline)
                    if let reason = candidate.reason, !reason.isEmpty {
                        ForEach(reason.keys.sorted(), id: \.self) { key in
                            detail(labelForReason(key), reason[key]?.description ?? "")
                        }
                    } else {
                        Text("Brak szczegółów dopasowania").foregroundColor(.secondary)
                    }
                }
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

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value.isEmpty ? "brak" : value).font(.body)
        }
    }

    private func labelForReason(_ key: String) -> String {
        switch key {
        case "amount_exact": return "Kwota identyczna"
        case "date_window": return "Zgodność daty"
        case "delta_days": return "Różnica dni"
        case "merchant": return "Podobieństwo kontrahenta"
        case "payment": return "Metoda płatności"
        case "bank_amount": return "Kwota bankowa"
        case "expense_amount": return "Kwota wydatku"
        case "receipt_amount": return "Kwota paragonu"
        case "bank_transaction_at": return "Data transakcji bankowej"
        case "bank_booked_at": return "Data księgowania"
        case "receipt_datetime": return "Data i godzina paragonu"
        case "receipt_merchant": return "Sklep z paragonu"
        case "bank_merchant": return "Kontrahent bankowy"
        case "bank_description": return "Opis bankowy"
        default: return key
        }
    }
}

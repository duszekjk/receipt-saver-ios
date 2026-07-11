import SwiftUI

struct MatchReviewView: View {
    @State private var candidates: [MatchCandidate] = []
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var processingIDs: Set<Int> = []
    @State private var acceptedIDs: Set<Int> = []
    @State private var rejectedIDs: Set<Int> = []

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
                    isProcessing: processingIDs.contains(candidate.id),
                    isAccepted: acceptedIDs.contains(candidate.id),
                    isRejected: rejectedIDs.contains(candidate.id),
                    accept: { Task { await accept(candidate) } },
                    reject: { Task { await reject(candidate) } }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .scale(scale: 0.92)).combined(with: .move(edge: .trailing))
                ))
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
            processingIDs.removeAll()
            acceptedIDs.removeAll()
            rejectedIDs.removeAll()
            errorMessage = ""
        } catch {
            errorMessage = "Nie udało się pobrać dopasowań: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func accept(_ candidate: MatchCandidate) async {
        guard !processingIDs.contains(candidate.id) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            processingIDs.insert(candidate.id)
            errorMessage = ""
        }
        do {
            _ = try await APIClient.shared.acceptMatch(candidateID: candidate.id)
            withAnimation(.easeInOut(duration: 0.45)) {
                processingIDs.remove(candidate.id)
                acceptedIDs.insert(candidate.id)
            }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeInOut(duration: 0.55)) {
                candidates.removeAll { $0.id == candidate.id }
                acceptedIDs.remove(candidate.id)
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                processingIDs.remove(candidate.id)
            }
            errorMessage = "Nie udało się oznaczyć jako ta sama transakcja: \(error.localizedDescription)"
        }
    }

    private func reject(_ candidate: MatchCandidate) async {
        guard !processingIDs.contains(candidate.id) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            processingIDs.insert(candidate.id)
            errorMessage = ""
        }
        do {
            _ = try await APIClient.shared.rejectMatch(candidateID: candidate.id)
            withAnimation(.easeInOut(duration: 0.4)) {
                processingIDs.remove(candidate.id)
                rejectedIDs.insert(candidate.id)
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                candidates.removeAll { $0.id == candidate.id }
                rejectedIDs.remove(candidate.id)
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                processingIDs.remove(candidate.id)
            }
            errorMessage = "Nie udało się odrzucić dopasowania: \(error.localizedDescription)"
        }
    }
}

private struct MatchCandidateCard: View {
    let candidate: MatchCandidate
    let isProcessing: Bool
    let isAccepted: Bool
    let isRejected: Bool
    let accept: () -> Void
    let reject: () -> Void
    @State private var showDetails = false

    private var backgroundColor: Color {
        if isAccepted { return Color.green.opacity(0.16) }
        if isRejected { return Color.secondary.opacity(0.10) }
        return Color.secondary.opacity(0.06)
    }

    private var borderColor: Color {
        if isAccepted { return Color.green.opacity(0.55) }
        if isRejected { return Color.secondary.opacity(0.35) }
        return Color.secondary.opacity(0.16)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundColor)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: isAccepted ? 2 : 1)

            if isAccepted {
                confirmationView(
                    icon: "checkmark.circle.fill",
                    title: "Dopasowano",
                    message: "Paragon i transakcja bankowa zostały połączone.",
                    color: .green
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if isRejected {
                confirmationView(
                    icon: "xmark.circle.fill",
                    title: "Odrzucono dopasowanie",
                    message: "Te pozycje pozostaną osobnymi transakcjami.",
                    color: .secondary
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                candidateContent
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeInOut(duration: 0.45), value: isAccepted)
        .animation(.easeInOut(duration: 0.4), value: isRejected)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }

    private var candidateContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dopasowanie \(Int(candidate.score * 100))%")
                    .font(.title3)
                Spacer()
                if isProcessing {
                    ProgressView()
                } else {
                    Text(candidate.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDetails.toggle()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button(action: accept) {
                    HStack(spacing: 8) {
                        if isProcessing { ProgressView() }
                        Text(isProcessing ? "Zapisywanie…" : "Ta sama transakcja")
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)

                Button(action: reject) {
                    Text("Inna")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
        }
        .padding(16)
    }

    private func confirmationView(icon: String, title: String, message: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(color)
            Text(title)
                .font(.title2)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(24)
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
        case "payment_card_last4": return "Końcówka karty z paragonu"
        case "bank_payment_card_last4": return "Końcówka karty z banku"
        case "card_last4_match": return "Zgodność karty"
        default: return key
        }
    }
}

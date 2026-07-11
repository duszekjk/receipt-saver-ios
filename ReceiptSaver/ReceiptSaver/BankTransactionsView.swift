import SwiftUI

struct BankTransactionsView: View {
    @State private var transactions: [BankTransactionItemsDocument] = []
    @State private var selectedTransaction: BankTransactionItemsDocument?
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if transactions.isEmpty && !isLoading {
                Section {
                    Text("Brak transakcji bankowych do uzupełnienia.")
                        .foregroundColor(.secondary)
                }
            }

            ForEach(transactions) { transaction in
                Button {
                    selectedTransaction = transaction
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top) {
                            Text(transaction.merchant_name.isEmpty ? "Transakcja bankowa" : transaction.merchant_name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer(minLength: 8)
                            Text("\(transaction.amount) \(transaction.currency)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        if !transaction.description.isEmpty {
                            Text(transaction.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if !transaction.date.isEmpty {
                            Text(transaction.date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if transaction.items.isEmpty {
                            Label("Dodaj konkretne produkty lub usługi", systemImage: "plus.circle")
                                .font(.subheadline)
                        } else {
                            Label("\(transaction.items.count) dodanych pozycji", systemImage: "checkmark.circle")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Transakcje")
        .overlay {
            if isLoading && transactions.isEmpty {
                ProgressView("Wczytuję transakcje…")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedTransaction) { transaction in
            BankTransactionItemsEditView(transactionID: transaction.transaction_id) {
                Task { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            transactions = try await APIClient.shared.editableBankTransactions()
        } catch {
            errorMessage = "Nie udało się pobrać transakcji bankowych: \(error.localizedDescription)"
        }
    }
}

import SwiftUI

struct BankTransactionItemsEditView: View {
    let transactionID: Int
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var document: BankTransactionItemsDocument?
    @State private var items: [BankTransactionManualItem] = []
    @State private var errorMessage = ""
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let document = document {
                    Section("Transakcja bankowa") {
                        if !document.merchant_name.isEmpty {
                            detailRow("Firma", document.merchant_name)
                        }
                        if !document.description.isEmpty {
                            Text(document.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        detailRow("Kwota", "\(document.amount) \(document.currency)")
                        detailRow("Suma pozycji", "\(formattedTotal) \(document.currency)")
                    }

                    Section {
                        Text("Dodaj konkretne produkty lub usługi składające się na tę transakcję. Suma pozycji musi być równa kwocie transakcji.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Produkty i usługi") {
                        ForEach($items) { $item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(item.name.isEmpty ? "Nowa pozycja" : item.name)
                                        .font(.headline)
                                    Spacer()
                                    Button(role: .destructive) {
                                        items.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                TextField("Nazwa produktu lub usługi", text: $item.name)
                                TextField("Kwota", text: $item.amount)
                                    .keyboardType(.decimalPad)
                                TextField("Kategoria", text: $item.category)
                                TextField("Podkategoria", text: $item.subcategory)
                            }
                            .padding(.vertical, 6)
                        }

                        Button {
                            items.append(BankTransactionManualItem(name: "", amount: "", category: "", subcategory: ""))
                        } label: {
                            Label("Dodaj produkt lub usługę", systemImage: "plus")
                        }
                    }
                } else if isLoading {
                    Section { ProgressView("Wczytuję transakcję…") }
                }
            }
            .navigationTitle("Produkty transakcji")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Zapisywanie…" : "Zapisz") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isLoading)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gotowe") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .task { await load() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
            Spacer(minLength: 12)
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var formattedTotal: String {
        let total = items.reduce(0.0) { result, item in
            result + (Double(item.amount.replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
        return String(format: "%.2f", total)
    }

    private func load() async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.bankTransactionItems(transactionID: transactionID)
            document = result
            items = result.items
        } catch {
            errorMessage = "Nie udało się pobrać transakcji: \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard !items.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć nazwę."
            return
        }
        guard !items.contains(where: { $0.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć kwotę."
            return
        }
        guard !items.contains(where: { $0.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.subcategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć kategorię i podkategorię."
            return
        }

        isSaving = true
        errorMessage = ""
        defer { isSaving = false }
        do {
            let normalized = items.map {
                BankTransactionManualItem(
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: $0.amount.replacingOccurrences(of: ",", with: "."),
                    category: $0.category.trimmingCharacters(in: .whitespacesAndNewlines),
                    subcategory: $0.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            _ = try await APIClient.shared.updateBankTransactionItems(transactionID: transactionID, items: normalized)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

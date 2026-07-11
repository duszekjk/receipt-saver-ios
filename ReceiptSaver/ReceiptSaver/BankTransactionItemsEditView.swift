import SwiftUI
import UIKit

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
                        if abs(remainingAmount) > 0.009 {
                            detailRow("Pozostało", String(format: "%.2f %@", remainingAmount, document.currency))
                        }
                    }

                    if !document.suggested_items.isEmpty {
                        Section("Sugestie") {
                            ForEach(document.suggested_items) { suggestion in
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(suggestion.name)
                                        .font(.headline)
                                    Text("\(suggestion.category) › \(suggestion.subcategory)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if !suggestion.reason.isEmpty {
                                        Text(suggestion.reason)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Button {
                                        addSuggestion(suggestion)
                                    } label: {
                                        Label("Dodaj tę pozycję", systemImage: "plus.circle.fill")
                                            .frame(maxWidth: .infinity, minHeight: 38)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 4)
                            }
                        }
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

                                Picker("Kategoria", selection: $item.category) {
                                    ForEach(categoryOptions(current: item.category), id: \.self) { category in
                                        Text(category).tag(category)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: item.category) { newCategory in
                                    let available = ReceiptCategoryCatalog.subcategories(for: newCategory)
                                    if !available.contains(item.subcategory) {
                                        item.subcategory = available.first ?? ""
                                    }
                                }

                                Picker("Podkategoria", selection: $item.subcategory) {
                                    ForEach(subcategoryOptions(category: item.category, current: item.subcategory), id: \.self) { subcategory in
                                        Text(subcategory).tag(subcategory)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.vertical, 6)
                        }

                        Button {
                            let initialAmount = items.isEmpty ? fullTransactionAmount : ""
                            let category = ReceiptCategoryCatalog.categoryNames.first ?? ""
                            let subcategory = ReceiptCategoryCatalog.subcategories(for: category).first ?? ""
                            items.append(BankTransactionManualItem(name: "", amount: initialAmount, category: category, subcategory: subcategory))
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

    private var fullTransactionAmount: String {
        document?.amount.replacingOccurrences(of: ",", with: ".") ?? ""
    }

    private var numericTransactionAmount: Double {
        Double(fullTransactionAmount) ?? 0
    }

    private var numericItemsTotal: Double {
        items.reduce(0.0) { result, item in
            result + (Double(item.amount.replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    private var formattedTotal: String {
        String(format: "%.2f", numericItemsTotal)
    }

    private var remainingAmount: Double {
        max(0, numericTransactionAmount - numericItemsTotal)
    }

    private func addSuggestion(_ suggestion: BankTransactionSuggestedItem) {
        let amount: String
        if items.isEmpty {
            amount = fullTransactionAmount
        } else if remainingAmount > 0.009 {
            amount = String(format: "%.2f", remainingAmount)
        } else {
            amount = ""
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            items.append(BankTransactionManualItem(
                name: suggestion.name,
                amount: amount,
                category: suggestion.category,
                subcategory: suggestion.subcategory
            ))
        }
    }

    private func categoryOptions(current: String) -> [String] {
        var result = ReceiptCategoryCatalog.categoryNames
        if !current.isEmpty && !result.contains(current) {
            result.insert(current, at: 0)
        }
        return result
    }

    private func subcategoryOptions(category: String, current: String) -> [String] {
        var result = ReceiptCategoryCatalog.subcategories(for: category)
        if !current.isEmpty && !result.contains(current) {
            result.insert(current, at: 0)
        }
        return result
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

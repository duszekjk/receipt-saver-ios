import SwiftUI
import UIKit

private struct EditableReceiptItem: Identifiable {
    let id: UUID
    let serverID: Int?
    var name: String
    var quantity: String
    var unitPrice: String
    var paidPrice: String
    var regularPrice: String
    var discountAmount: String
    var promotionName: String
    var isDiscounted: Bool
    var category: String
    var subcategory: String

    init(item: ReceiptItem) {
        id = UUID()
        serverID = item.id
        name = item.name
        quantity = item.quantity ?? ""
        unitPrice = item.unit_price ?? ""
        paidPrice = item.paid_price ?? ""
        regularPrice = item.regular_price ?? ""
        discountAmount = item.discount_amount ?? ""
        promotionName = item.promotion_name ?? ""
        isDiscounted = item.is_discounted
        category = item.category ?? ""
        subcategory = item.subcategory ?? ""
    }

    init() {
        id = UUID()
        serverID = nil
        name = ""
        quantity = ""
        unitPrice = ""
        paidPrice = ""
        regularPrice = ""
        discountAmount = ""
        promotionName = ""
        isDiscounted = false
        category = ""
        subcategory = ""
    }
}

struct ReceiptEditView: View {
    let receipt: Receipt
    let onSaved: (Receipt) -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var merchantName: String
    @State private var totalAmount: String
    @State private var currency: String
    @State private var paymentMethod: String
    @State private var purchasedAt: Date
    @State private var hasDate: Bool
    @State private var items: [EditableReceiptItem]
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var previewImage: UIImage?
    @State private var previewError = ""
    @State private var isLoadingPreview = false
    @State private var showFullScreenPreview = false
    @State private var keyboardVisible = false

    init(receipt: Receipt, onSaved: @escaping (Receipt) -> Void, onDeleted: @escaping () -> Void) {
        self.receipt = receipt
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _merchantName = State(initialValue: receipt.merchant_name)
        _totalAmount = State(initialValue: receipt.total_amount ?? "")
        _currency = State(initialValue: receipt.currency)
        _paymentMethod = State(initialValue: receipt.payment_method ?? "")
        let parsedDate = Self.parseDate(receipt.purchased_at) ?? Date()
        _purchasedAt = State(initialValue: parsedDate)
        _hasDate = State(initialValue: receipt.purchased_at != nil)
        _items = State(initialValue: receipt.items.map(EditableReceiptItem.init))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                previewPanel
                    .frame(height: keyboardVisible ? 122 : 260)
                    .animation(.easeInOut(duration: 0.22), value: keyboardVisible)

                Form {
                    if !errorMessage.isEmpty {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Section("Paragon") {
                        TextField("Sklep", text: $merchantName)
                        TextField("Suma paragonu", text: $totalAmount)
                            .keyboardType(.decimalPad)
                        TextField("Waluta", text: $currency)
                            .textInputAutocapitalization(.characters)
                        TextField("Metoda płatności", text: $paymentMethod)
                        Toggle("Data jest znana", isOn: $hasDate)
                        if hasDate {
                            DatePicker("Data i godzina", selection: $purchasedAt, in: Calendar.current.date(byAdding: .year, value: -1, to: Date())!...Date())
                        }
                    }

                    Section {
                        Text("Porównuj dane z widocznym wyżej zdjęciem. Podczas pisania zdjęcie pozostaje na ekranie i automatycznie zmniejsza wysokość.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Pozycje paragonu") {
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

                                TextField("Nazwa produktu", text: $item.name)
                                TextField("Cena zapłacona", text: $item.paidPrice)
                                    .keyboardType(.decimalPad)
                                TextField("Kategoria", text: $item.category)
                                TextField("Podkategoria", text: $item.subcategory)

                                DisclosureGroup("Pozostałe dane") {
                                    TextField("Ilość", text: $item.quantity).keyboardType(.decimalPad)
                                    TextField("Cena jednostkowa", text: $item.unitPrice).keyboardType(.decimalPad)
                                    TextField("Cena regularna", text: $item.regularPrice).keyboardType(.decimalPad)
                                    TextField("Rabat", text: $item.discountAmount).keyboardType(.decimalPad)
                                    TextField("Promocja", text: $item.promotionName)
                                    Toggle("Przecenione", isOn: $item.isDiscounted)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Button(action: { items.append(EditableReceiptItem()) }) {
                            Label("Dodaj pozycję", systemImage: "plus")
                        }
                    }

                    Section {
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Label("Usuń paragon", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Zweryfikuj paragon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Zapisywanie…" : "Zapisz") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gotowe") { hideKeyboard() }
                }
            }
            .confirmationDialog("Usunąć ten paragon?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Usuń paragon", role: .destructive) { Task { await deleteReceipt() } }
                Button("Anuluj", role: .cancel) {}
            }
            .sheet(isPresented: $showFullScreenPreview) {
                NavigationView {
                    Group {
                        if let image = previewImage {
                            ReceiptZoomImageView(image: image)
                                .background(Color.black)
                        } else {
                            ProgressView()
                        }
                    }
                    .navigationTitle("Zdjęcie paragonu")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Zamknij") { showFullScreenPreview = false }
                        }
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            .task { await loadPreview() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var previewPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle().fill(Color.secondary.opacity(0.08))

            if let image = previewImage {
                ReceiptZoomImageView(image: image)
                    .padding(6)
            } else if isLoadingPreview {
                ProgressView("Pobieranie zdjęcia…")
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text.image")
                    Text(previewError.isEmpty ? "Brak podglądu zdjęcia" : previewError)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }

            if previewImage != nil {
                Button(action: { showFullScreenPreview = true }) {
                    Label("Pełny ekran", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
                .padding(10)
            }
        }
        .clipped()
    }

    private func loadPreview() async {
        previewImage = nil
        previewError = ""
        isLoadingPreview = true
        defer { isLoadingPreview = false }
        do {
            previewImage = try await APIClient.shared.receiptPreview(receiptID: receipt.id)
        } catch {
            previewError = "Nie udało się pobrać zdjęcia: \(error.localizedDescription)"
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }

        guard !items.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć nazwę."
            return
        }
        guard !items.contains(where: { $0.paidPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć cenę zapłaconą."
            return
        }
        guard !items.contains(where: { $0.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.subcategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Każda pozycja musi mieć kategorię i podkategorię."
            return
        }

        let payloadItems = items.map { item in
            ReceiptItemUpdatePayload(
                id: item.serverID,
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: emptyToNil(item.quantity),
                unit_price: emptyToNil(item.unitPrice),
                paid_price: emptyToNil(item.paidPrice),
                regular_price: emptyToNil(item.regularPrice),
                discount_amount: emptyToNil(item.discountAmount),
                promotion_name: emptyToNil(item.promotionName),
                is_discounted: item.isDiscounted,
                category: emptyToNil(item.category),
                subcategory: emptyToNil(item.subcategory)
            )
        }

        let payload = ReceiptUpdatePayload(
            merchant_name: merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
            purchased_at: hasDate ? ISO8601DateFormatter().string(from: purchasedAt) : nil,
            total_amount: emptyToNil(totalAmount),
            currency: currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            payment_method: paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines),
            items: payloadItems
        )

        do {
            let updated = try await APIClient.shared.updateReceipt(id: receipt.id, payload: payload)
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteReceipt() async {
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }
        do {
            try await APIClient.shared.deleteReceipt(id: receipt.id)
            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.replacingOccurrences(of: ",", with: ".")
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter.date(from: value)
    }
}

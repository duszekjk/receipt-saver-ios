import SwiftUI

struct CategorySelectionField: View {
    @Binding var category: String
    @Binding var subcategory: String
    @State private var showSelector = false

    var body: some View {
        Button {
            showSelector = true
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kategoria")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(category.isEmpty ? "Wybierz kategorię" : category)
                        .foregroundColor(.primary)
                    if !subcategory.isEmpty {
                        Text(subcategory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSelector) {
            CategorySelectionView(category: $category, subcategory: $subcategory)
        }
    }
}

private struct CategorySelectionView: View {
    @Binding var category: String
    @Binding var subcategory: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [ReceiptCategoryOption] {
        ReceiptCategoryCatalog.search(query)
    }

    var body: some View {
        NavigationView {
            List {
                if results.isEmpty {
                    Text("Nie znaleziono kategorii pasującej do „\(query)”.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results) { option in
                        Button {
                            category = option.category
                            subcategory = option.subcategory
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.subcategory)
                                        .foregroundColor(.primary)
                                    Text(option.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if option.category == category && option.subcategory == subcategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wybierz kategorię")
            .searchable(text: $query, prompt: "Np. autostrada, film, polisa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

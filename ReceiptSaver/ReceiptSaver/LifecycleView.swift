import SwiftUI
import UserNotifications

struct LifecycleView: View {
    @State private var rules: [ProductCycleRule] = []
    @State private var productName = ""
    @State private var intervalDays = 30
    @State private var reminderBeforeDays = 2
    @State private var suggestion: ProductCycleSuggestion?
    @State private var isSaving = false

    var body: some View {
        List {
            Section("Nowa kontrola zużycia") {
                TextField("Produkt lub usługa", text: $productName)
                    .onSubmit { Task { await loadSuggestion() } }
                Stepper("Cykl: \(intervalDays) dni", value: $intervalDays, in: 1...3650)
                Stepper("Przypomnij \(reminderBeforeDays) dni wcześniej", value: $reminderBeforeDays, in: 0...min(intervalDays, 365))

                if let suggestion {
                    Button("Użyj sugestii: \(suggestion.interval_days) dni") {
                        intervalDays = suggestion.interval_days
                        reminderBeforeDays = suggestion.reminder_before_days
                    }
                }

                Button("Dodaj przypomnienie") {
                    Task { await save() }
                }
                .disabled(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }

            Section("Aktywne przypomnienia") {
                if rules.isEmpty {
                    Text("Brak przypomnień").foregroundColor(.secondary)
                }
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(rule.product_name).font(.headline)
                        Text("Co \(rule.interval_days) dni, \(rule.reminder_before_days) dni wcześniej")
                        if let expected = formatted(rule.expected_next_purchase_at) {
                            Text("Przewidywany kolejny zakup: \(expected)")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Reguła zacznie działać po znalezieniu zakupu tego produktu.")
                                .foregroundColor(.secondary)
                        }
                        if rule.too_frequent {
                            Text("Produkt był kupowany częściej niż ustawiony cykl.")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        Task { await delete(rules[index]) }
                    }
                }
            }
        }
        .navigationTitle("Zużycie i przypomnienia")
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            rules = try await APIClient.shared.cycleRules()
            await scheduleNotifications(for: rules)
        } catch {
            ToastCenter.shared.show("Nie udało się pobrać przypomnień: \(error.localizedDescription)", style: .error)
        }
    }

    @MainActor
    private func loadSuggestion() async {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        suggestion = try? await APIClient.shared.cycleSuggestion(productName: productName).suggestion
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let rule = try await APIClient.shared.saveCycleRule(
                productName: productName,
                intervalDays: intervalDays,
                reminderBeforeDays: reminderBeforeDays
            )
            productName = ""
            suggestion = nil
            await load()
            ToastCenter.shared.show("Przypomnienie zapisane.", style: .success)
            await scheduleNotifications(for: [rule])
        } catch {
            ToastCenter.shared.show("Nie udało się zapisać przypomnienia: \(error.localizedDescription)", style: .error)
        }
    }

    @MainActor
    private func delete(_ rule: ProductCycleRule) async {
        do {
            try await APIClient.shared.deleteCycleRule(id: rule.id)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(rule.id)])
            rules.removeAll { $0.id == rule.id }
        } catch {
            ToastCenter.shared.show("Nie udało się usunąć przypomnienia: \(error.localizedDescription)", style: .error)
        }
    }

    private func scheduleNotifications(for rules: [ProductCycleRule]) async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        for rule in rules where rule.enabled {
            let identifier = notificationID(rule.id)
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            guard let value = rule.reminder_at, let date = ISO8601DateFormatter().date(from: value), date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Kończy się: \(rule.product_name)"
            content.body = "Sprawdź, czy trzeba kupić ponownie."
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    private func notificationID(_ id: Int) -> String { "product-cycle-\(id)" }

    private func formatted(_ value: String?) -> String? {
        guard let value, let date = ISO8601DateFormatter().date(from: value) else { return nil }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}

struct PurchaseSearchView: View {
    @State private var query = ""
    @State private var results: [PurchaseSearchResult] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if query.isEmpty {
                Text("Wpisz produkt, sklep, kategorię lub usługę.")
                    .foregroundColor(.secondary)
            } else if !isLoading && results.isEmpty {
                Text("Brak wyników").foregroundColor(.secondary)
            }
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name).font(.headline)
                    if !result.merchant.isEmpty { Text(result.merchant) }
                    HStack {
                        if let date = formatted(result.date) { Text(date) }
                        Spacer()
                        Text("\(result.amount) \(result.currency)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    if !result.category.isEmpty {
                        Text([result.category, result.subcategory].filter { !$0.isEmpty }.joined(separator: " / "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Szukaj zakupów")
        .searchable(text: $query, prompt: "Np. klimatyzacja, Ibuprom, Lidl")
        .onSubmit(of: .search) { Task { await search() } }
    }

    @MainActor
    private func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { results = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await APIClient.shared.searchPurchases(query: value)
        } catch {
            ToastCenter.shared.show("Nie udało się wyszukać zakupów: \(error.localizedDescription)", style: .error)
        }
    }

    private func formatted(_ value: String?) -> String? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        return value
    }
}

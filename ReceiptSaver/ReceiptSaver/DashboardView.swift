import SwiftUI
import AVFoundation

struct DashboardView: View {
    @State private var period = "month"
    @State private var selectedMonth = ""
    @State private var categoryFilter = ""
    @State private var limit = 10
    @State private var dashboard: DashboardStats?
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var pickerSource: ImagePicker.Source = .camera
    @State private var uploadStatus = ""
    @State private var showRetryButton = false
    @State private var selectedSubcategory: DashboardBarRow?
    @State private var subcategoryDetails: SubcategoryDetails?
    @State private var detailsError = ""

    let periods = [("month", "Miesiąc"), ("last30", "30 dni"), ("last90", "90 dni")]
    let limits = [5, 10, 15, 20]
    private let accent = Color(red: 0.00, green: 0.36, blue: 0.20)

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Zakres", selection: $period) {
                            ForEach(periods, id: \.0) { key, label in Text(label).tag(key) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: period) { _ in Task { await loadDashboard() } }

                        if let dashboard = dashboard, period == "month" {
                            compactMonthPicker(dashboard.available_months)
                        }

                        if !uploadStatus.isEmpty || showRetryButton {
                            VStack(alignment: .leading, spacing: 10) {
                                if !uploadStatus.isEmpty {
                                    Text(uploadStatus)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if showRetryButton {
                                    Button(action: { Task { await loadDashboard() } }) {
                                        Label("Spróbuj ponownie", systemImage: "arrow.clockwise")
                                            .frame(maxWidth: .infinity, minHeight: 42)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(accent)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let dashboard = dashboard {
                            Text(period == "month" ? "Podsumowanie za \(monthDisplay(dashboard.selected_month))" : timelineTitle())
                                .font(.title2)
                                .fixedSize(horizontal: false, vertical: true)
                            cards(dashboard.cards)
                            sectionHeader(categoryFilter.isEmpty ? "Największe subkategorie" : "Subkategorie: \(displayLabel(categoryFilter))")
                            BarList(rows: dashboard.subcategories, maxValue: maxSpent(dashboard.subcategories), displayName: displayLabel, accent: accent) { row in
                                selectedSubcategory = row
                                Task { await loadSubcategoryDetails(row) }
                            }
                            filterControls(dashboard.available_categories)
                            sectionHeader("Główne kategorie")
                            BarList(rows: dashboard.categories, maxValue: maxSpent(dashboard.categories), displayName: displayLabel, accent: accent)
                            sectionHeader("Najdroższe produkty")
                            BarList(rows: dashboard.products, maxValue: maxSpent(dashboard.products), displayName: displayLabel, accent: accent)
                            sectionHeader("Sklepy i odbiorcy")
                            BarList(rows: dashboard.stores, maxValue: maxSpent(dashboard.stores), displayName: displayLabel, accent: accent)
                            if period != "month", !dashboard.timeline.isEmpty {
                                sectionHeader(timelineTitle())
                                BarList(rows: dashboard.timeline, maxValue: maxSpent(dashboard.timeline), displayName: displayLabel, accent: accent)
                            }
                        } else {
                            ProgressView("Wczytuję podsumowanie...")
                                .frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .padding(.bottom, 96)
                }

                Button(action: { openBestScanner() }) {
                    Label("Dodaj paragon", systemImage: "camera.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(.thinMaterial)
            }
            .navigationTitle("Budżet")
            .sheet(isPresented: $showPicker) {
                ImagePicker(source: pickerSource) { image in Task { await upload(image) } }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(onImage: { image in Task { await upload(image) } }, onCancel: {})
            }
            .sheet(item: $selectedSubcategory) { row in
                SubcategoryDetailsView(title: displayLabel(row.name), details: subcategoryDetails, error: detailsError, displayName: displayLabel)
            }
            .task { await loadDashboard() }
        }
        .navigationViewStyle(.stack)
    }

    private func compactMonthPicker(_ months: [String]) -> some View {
        HStack(spacing: 12) {
            Text("Miesiąc").font(.headline)
            Spacer(minLength: 8)
            Picker("Miesiąc", selection: $selectedMonth) {
                ForEach(months, id: \.self) { month in Text(monthDisplay(month)).tag(month) }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedMonth) { _ in Task { await loadDashboard() } }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cards(_ cards: DashboardCards) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Wydatki", value: "\(money(cards.spent)) zł")
            StatCard(title: "Oszczędzono", value: "\(money(cards.saved)) zł")
            StatCard(title: "Pozycje", value: "\(cards.receipt_count)")
            StatCard(title: "Sklepy/odbiorcy", value: "\(cards.store_count)")
        }
        .frame(maxWidth: .infinity)
    }

    private func filterControls(_ categories: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtry").font(.headline)
            HStack {
                Text("Kategoria")
                Spacer(minLength: 8)
                Picker("Kategoria", selection: $categoryFilter) {
                    Text("Wszystkie").tag("")
                    ForEach(categories, id: \.self) { category in Text(displayLabel(category)).tag(category) }
                }
                .pickerStyle(.menu)
            }
            .onChange(of: categoryFilter) { _ in Task { await loadDashboard() } }
            Picker("Liczba pozycji", selection: $limit) {
                ForEach(limits, id: \.self) { value in Text("Top \(value)").tag(value) }
            }
            .pickerStyle(.segmented)
            .onChange(of: limit) { _ in Task { await loadDashboard() } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func timelineTitle() -> String { period == "last30" ? "Ostatnie 30 dni" : period == "last90" ? "Ostatnie 90 dni" : "Wydatki według miesięcy" }

    private func monthDisplay(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let number = Int(parts[1]) else { return month }
        let names = ["", "Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec", "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień"]
        return number >= 1 && number <= 12 ? "\(names[number]) \(parts[0])" : month
    }

    private func displayLabel(_ value: String) -> String {
        if value.range(of: "[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]", options: .regularExpression) != nil { return value }
        let key = value.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
        let labels = [
            "inne": "Inne", "paliwo": "Paliwo", "transport": "Transport", "zywnosc": "Żywność", "jedzenie": "Jedzenie", "zdrowie": "Zdrowie", "wizyta_u_lekarza": "Wizyta u lekarza", "leki": "Leki", "alkohol": "Alkohol", "alkohole": "Alkohole", "piwo": "Piwo", "wino": "Wino", "wodka": "Wódka", "mocny_alkohol": "Mocny alkohol", "hazard": "Hazard", "zaklady_bukmacherskie": "Zakłady bukmacherskie", "zaklady_sportowe": "Zakłady sportowe", "darowizny": "Darowizny", "dom": "Dom", "media": "Media", "telefon": "Telefon", "internet": "Internet", "restauracje": "Restauracje", "rozrywka": "Rozrywka", "ubrania": "Ubrania", "oszczednosci": "Oszczędności", "miod": "Miód", "roze": "Róże", "roza": "Róża", "kwiaty": "Kwiaty", "nabial": "Nabiał", "mieso": "Mięso", "wedliny": "Wędliny", "mrozonki": "Mrożonki", "slodycze": "Słodycze", "srodki_czystosci": "Środki czystości", "papier_toaletowy": "Papier toaletowy", "odziez": "Odzież", "ksiazki": "Książki", "rekodzielo": "Rękodzieło"
        ]
        if let label = labels[key] { return label }
        return value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func maxSpent(_ rows: [DashboardBarRow]) -> Double { max(rows.map(\.spent).max() ?? 1, 1) }
    private func money(_ value: Double) -> String { String(format: "%.2f", value) }

    private func openBestScanner() {
        requestCameraAccess { granted in
            guard granted else { uploadStatus = "Brak dostępu do aparatu. Włącz dostęp w Ustawieniach."; scheduleDashboardRetry(); return }
            if DocumentScannerView.isAvailable { showScanner = true } else { pickerSource = .camera; showPicker = true }
        }
    }

    private func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: completion(true)
        case .notDetermined: AVCaptureDevice.requestAccess(for: .video) { granted in DispatchQueue.main.async { completion(granted) } }
        default: completion(false)
        }
    }

    private func loadDashboard() async {
        showRetryButton = false
        do {
            let result = try await APIClient.shared.dashboard(period: period, month: selectedMonth, category: categoryFilter, limit: limit)
            dashboard = result
            uploadStatus = ""
            if selectedMonth.isEmpty || !result.available_months.contains(selectedMonth) { selectedMonth = result.selected_month }
        } catch {
            uploadStatus = "Nie udało się pobrać dashboardu: \(errorMessage(error))"
            scheduleDashboardRetry()
        }
    }

    private func scheduleDashboardRetry() {
        showRetryButton = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            if !uploadStatus.isEmpty {
                showRetryButton = true
            }
        }
    }

    private func loadSubcategoryDetails(_ row: DashboardBarRow) async {
        subcategoryDetails = nil
        detailsError = ""
        do { subcategoryDetails = try await APIClient.shared.subcategoryDetails(month: selectedMonth, subcategory: row.name) }
        catch { detailsError = errorMessage(error) }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysyłam paragon..."
        do { _ = try await APIClient.shared.uploadReceipt(image: image); uploadStatus = "Paragon dodany"; await loadDashboard() }
        catch { uploadStatus = "Błąd wysyłania paragonu: \(errorMessage(error))"; scheduleDashboardRetry() }
    }

    private func errorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError { return apiError.errorDescription ?? "Błąd API" }
        if let urlError = error as? URLError { return "URL \(urlError.code.rawValue): \(urlError.localizedDescription)" }
        if let decodingError = error as? DecodingError { return "Błąd JSON: \(decodingError)" }
        return error.localizedDescription
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(.secondary).lineLimit(2)
            Text(value).font(.title2).lineLimit(2).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct BarList: View {
    let rows: [DashboardBarRow]
    let maxValue: Double
    let displayName: (String) -> String
    let accent: Color
    var onTap: ((DashboardBarRow) -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            if rows.isEmpty {
                Text("Brak danych")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(rows) { row in
                    Button(action: { onTap?(row) }) { bar(row) }
                        .buttonStyle(.plain)
                        .disabled(onTap == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    private func bar(_ row: DashboardBarRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(displayName(row.name))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(String(format: "%.2f zł", row.spent))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 6).fill(accent).frame(width: min(geometry.size.width, max(8, geometry.size.width * CGFloat(row.spent / maxValue))), height: 12)
                }
            }.frame(height: 12)
            HStack {
                Text("\(row.count) pozycji").font(.caption).foregroundColor(.secondary)
                if onTap != nil { Spacer(); Text("Pokaż").font(.caption).foregroundColor(accent) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SubcategoryDetailsView: View {
    let title: String
    let details: SubcategoryDetails?
    let error: String
    let displayName: (String) -> String
    var body: some View {
        NavigationView {
            List {
                if !error.isEmpty { Text("Nie udało się pobrać szczegółów: \(error)") }
                else if let details = details {
                    if details.items.isEmpty { Text("Brak pozycji w tej subkategorii.") }
                    else { ForEach(details.items) { item in VStack(alignment: .leading, spacing: 4) { Text(displayName(item.name)).font(.headline); if !item.merchant.isEmpty { Text(item.merchant).font(.caption).foregroundColor(.secondary) }; Text("\(item.count) pozycji • \(String(format: "%.2f", item.spent)) zł").font(.subheadline).foregroundColor(.secondary) } } }
                } else { ProgressView("Wczytuję szczegóły...") }
            }.navigationTitle(title)
        }.navigationViewStyle(.stack)
    }
}

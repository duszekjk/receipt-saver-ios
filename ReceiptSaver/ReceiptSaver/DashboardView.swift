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

    let periods = [("month", "Miesiac"), ("last30", "30 dni"), ("last90", "90 dni")]
    let limits = [5, 10, 15, 20]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Zakres", selection: $period) {
                            ForEach(periods, id: \.0) { key, label in Text(label).tag(key) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: period) { _ in Task { await loadDashboard() } }

                        if let dashboard = dashboard, period == "month" {
                            monthPicker(dashboard.available_months)
                        }

                        if !uploadStatus.isEmpty {
                            Text(uploadStatus)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let dashboard = dashboard {
                            Text(period == "month" ? "Podsumowanie za \(monthDisplay(dashboard.selected_month))" : timelineTitle())
                                .font(.title2)
                                .fontWeight(.bold)

                            cards(dashboard.cards)

                            sectionHeader(categoryFilter.isEmpty ? "Najwieksze subkategorie" : "Subkategorie: \(categoryFilter)")
                            BarList(rows: dashboard.subcategories, maxValue: maxSpent(dashboard.subcategories))

                            filterControls(dashboard.available_categories)

                            sectionHeader("Glowne kategorie")
                            BarList(rows: dashboard.categories, maxValue: maxSpent(dashboard.categories))

                            sectionHeader("Najdrozsze produkty")
                            BarList(rows: dashboard.products, maxValue: maxSpent(dashboard.products))

                            sectionHeader("Sklepy i odbiorcy")
                            BarList(rows: dashboard.stores, maxValue: maxSpent(dashboard.stores))

                            if period != "month", !dashboard.timeline.isEmpty {
                                sectionHeader(timelineTitle())
                                BarList(rows: dashboard.timeline, maxValue: maxSpent(dashboard.timeline))
                            }
                        } else {
                            ProgressView("Wczytuje podsumowanie...")
                                .frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }
                    .padding()
                    .padding(.bottom, 96)
                }

                Button(action: { openBestScanner() }) {
                    Label("Dodaj paragon", systemImage: "camera.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 62)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(.thinMaterial)
            }
            .navigationTitle("Budzet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Wiecej") {
                        if DocumentScannerView.isAvailable {
                            Button("Skan dokumentu") { openBestScanner() }
                        }
                        Button("Aparat") { openCameraPicker() }
                        Button("Biblioteka") { pickerSource = .library; showPicker = true }
                    }
                    .font(.title3)
                }
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(source: pickerSource) { image in
                    Task { await upload(image) }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(onImage: { image in
                    Task { await upload(image) }
                }, onCancel: {})
            }
            .task { await loadDashboard() }
        }
        .navigationViewStyle(.stack)
    }

    private func monthPicker(_ months: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Miesiac rozliczenia")
                .font(.headline)
            Picker("Miesiac", selection: $selectedMonth) {
                ForEach(months, id: \.self) { month in
                    Text(monthDisplay(month)).tag(month)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedMonth) { _ in Task { await loadDashboard() } }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cards(_ cards: DashboardCards) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Wydatki", value: "\(money(cards.spent)) zl")
            StatCard(title: "Oszczedzono", value: "\(money(cards.saved)) zl")
            StatCard(title: "Pozycje", value: "\(cards.receipt_count)")
            StatCard(title: "Sklepy/odbiorcy", value: "\(cards.store_count)")
        }
    }

    private func filterControls(_ categories: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtry")
                .font(.headline)
            Picker("Kategoria", selection: $categoryFilter) {
                Text("Wszystkie kategorie").tag("")
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: categoryFilter) { _ in Task { await loadDashboard() } }

            Picker("Liczba pozycji", selection: $limit) {
                ForEach(limits, id: \.self) { value in
                    Text("Top \(value)").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: limit) { _ in Task { await loadDashboard() } }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.top, 4)
    }

    private func timelineTitle() -> String {
        switch period {
        case "last30": return "Ostatnie 30 dni"
        case "last90": return "Ostatnie 90 dni"
        default: return "Wydatki wedlug miesiecy"
        }
    }

    private func monthDisplay(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let number = Int(parts[1]) else { return month }
        let names = ["", "Styczen", "Luty", "Marzec", "Kwiecien", "Maj", "Czerwiec", "Lipiec", "Sierpien", "Wrzesien", "Pazdziernik", "Listopad", "Grudzien"]
        return number >= 1 && number <= 12 ? "\(names[number]) \(parts[0])" : month
    }

    private func maxSpent(_ rows: [DashboardBarRow]) -> Double {
        max(rows.map(\.spent).max() ?? 1, 1)
    }

    private func money(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func openBestScanner() {
        requestCameraAccess { granted in
            guard granted else {
                uploadStatus = "Brak dostepu do aparatu. Wlacz dostep w Ustawieniach."
                return
            }
            if DocumentScannerView.isAvailable {
                showScanner = true
            } else {
                pickerSource = .camera
                showPicker = true
            }
        }
    }

    private func openCameraPicker() {
        requestCameraAccess { granted in
            guard granted else {
                uploadStatus = "Brak dostepu do aparatu. Wlacz dostep w Ustawieniach."
                return
            }
            pickerSource = .camera
            showPicker = true
        }
    }

    private func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func loadDashboard() async {
        do {
            let result = try await APIClient.shared.dashboard(period: period, month: selectedMonth, category: categoryFilter, limit: limit)
            dashboard = result
            if selectedMonth.isEmpty || !result.available_months.contains(selectedMonth) {
                selectedMonth = result.selected_month
            }
        } catch {
            uploadStatus = "Nie udalo sie pobrac dashboardu: \(errorMessage(error))"
        }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysylam paragon..."
        do {
            _ = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = "Paragon dodany"
            await loadDashboard()
        } catch {
            uploadStatus = "Blad wysylania paragonu: \(errorMessage(error))"
        }
    }

    private func errorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Blad API"
        }
        if let urlError = error as? URLError {
            return "URL \(urlError.code.rawValue): \(urlError.localizedDescription)"
        }
        if let decodingError = error as? DecodingError {
            return "Blad JSON: \(decodingError)"
        }
        return error.localizedDescription
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(row.name.isEmpty ? "inne" : row.name)
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f zl", row.spent))
                                .font(.headline)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .frame(height: 12)
                                    .opacity(0.15)
                                RoundedRectangle(cornerRadius: 6)
                                    .frame(width: max(8, geometry.size.width * CGFloat(row.spent / maxValue)), height: 12)
                            }
                        }
                        .frame(height: 12)
                        Text("\(row.count) pozycji")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

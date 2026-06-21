import SwiftUI
import AVFoundation

struct DashboardView: View {
    @State private var period = "month"
    @State private var categoryFilter = ""
    @State private var limit = 10
    @State private var dashboard: DashboardStats?
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var pickerSource: ImagePicker.Source = .camera
    @State private var uploadStatus = ""

    let periods = [("month", "Miesiąc"), ("quarter", "Kwartał"), ("halfyear", "Półrocze"), ("year", "Rok")]
    let limits = [5, 10, 15, 20]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Okres", selection: $period) {
                            ForEach(periods, id: \.0) { key, label in Text(label).tag(key) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: period) { _ in Task { await loadDashboard() } }

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
                            cards(dashboard.cards)

                            sectionHeader("Największe kategorie")
                            BarList(rows: dashboard.categories, maxValue: maxSpent(dashboard.categories))

                            filterControls(dashboard.available_categories)

                            sectionHeader(categoryFilter.isEmpty ? "Największe subkategorie" : "Subkategorie: \(categoryFilter)")
                            BarList(rows: dashboard.subcategories, maxValue: maxSpent(dashboard.subcategories))

                            sectionHeader("Najdroższe produkty")
                            BarList(rows: dashboard.products, maxValue: maxSpent(dashboard.products))

                            sectionHeader("Sklepy")
                            BarList(rows: dashboard.stores, maxValue: maxSpent(dashboard.stores))
                        } else {
                            ProgressView("Wczytuję podsumowanie...")
                                .frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }
                    .padding()
                    .padding(.bottom, 96)
                }

                Button(action: { openBestScanner() }) {
                    Label("Dodaj paragon", systemImage: "camera.fill")
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 62)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(.thinMaterial)
            }
            .navigationTitle("Podsumowanie")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Więcej") {
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

    private func cards(_ cards: DashboardCards) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Wydano", value: "\(money(cards.spent)) zł")
            StatCard(title: "Oszczędzono", value: "\(money(cards.saved)) zł")
            StatCard(title: "Paragony", value: "\(cards.receipt_count)")
            StatCard(title: "Sklepy", value: "\(cards.store_count)")
        }
    }

    private func filterControls(_ categories: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtry subkategorii")
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
            .bold()
            .padding(.top, 4)
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
                uploadStatus = "Brak dostępu do aparatu. Włącz dostęp w Ustawieniach."
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
                uploadStatus = "Brak dostępu do aparatu. Włącz dostęp w Ustawieniach."
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
            dashboard = try await APIClient.shared.dashboard(period: period, category: categoryFilter, limit: limit)
        } catch {
            uploadStatus = "Nie udało się pobrać dashboardu: \(errorMessage(error))"
        }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysyłam paragon..."
        do {
            _ = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = "Paragon dodany"
            await loadDashboard()
        } catch {
            uploadStatus = "Błąd wysyłania paragonu: \(errorMessage(error))"
        }
    }

    private func errorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Błąd API"
        }
        if let urlError = error as? URLError {
            return "URL \(urlError.code.rawValue): \(urlError.localizedDescription)"
        }
        if let decodingError = error as? DecodingError {
            return "Błąd JSON: \(decodingError)"
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
                .bold()
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
                            Text(String(format: "%.2f zł", row.spent))
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

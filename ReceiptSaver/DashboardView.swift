import SwiftUI

struct DashboardView: View {
    @State private var period = "month"
    @State private var summaries: [SummaryRow] = []
    @State private var showPicker = false
    @State private var pickerSource: ImagePicker.Source = .camera
    @State private var uploadStatus = ""

    let periods = [("month", "Miesiąc"), ("quarter", "Kwartał"), ("halfyear", "Półrocze"), ("year", "Rok")]

    var body: some View {
        NavigationView {
            VStack {
                Picker("Okres", selection: $period) {
                    ForEach(periods, id: \.0) { key, label in Text(label).tag(key) }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: period) { _ in Task { await loadSummaries() } }

                if !uploadStatus.isEmpty { Text(uploadStatus).font(.footnote).padding(.bottom, 4) }

                List(summaries) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.period ?? "Brak daty").font(.headline)
                        Text("Wydano: \(row.spent) zł")
                        Text("Oszczędzono na promocjach: \(row.saved) zł")
                    }
                }
            }
            .navigationTitle("Paragony")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Lista") { }
                    Menu("Dodaj") {
                        Button("Aparat") { pickerSource = .camera; showPicker = true }
                        Button("Biblioteka") { pickerSource = .library; showPicker = true }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(source: pickerSource) { image in
                    Task { await upload(image) }
                }
            }
            .task { await loadSummaries() }
        }
    }

    private func loadSummaries() async {
        do { summaries = try await APIClient.shared.summaries(period: period) }
        catch { uploadStatus = "Nie udało się pobrać podsumowań: \(error.localizedDescription)" }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysyłam paragon..."
        do {
            _ = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = "Paragon dodany"
            await loadSummaries()
        } catch {
            uploadStatus = "Błąd uploadu: \(error.localizedDescription)"
        }
    }
}

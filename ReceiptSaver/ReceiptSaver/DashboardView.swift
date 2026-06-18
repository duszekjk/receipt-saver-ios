import SwiftUI
import AVFoundation

struct DashboardView: View {
    @State private var period = "month"
    @State private var summaries: [SummaryRow] = []
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var pickerSource: ImagePicker.Source = .camera
    @State private var uploadStatus = ""

    let periods = [("month", "Miesiąc"), ("quarter", "Kwartał"), ("halfyear", "Półrocze"), ("year", "Rok")]

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                Picker("Okres", selection: $period) {
                    ForEach(periods, id: \.0) { key, label in Text(label).tag(key) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: period) { _ in Task { await loadSummaries() } }

                if !uploadStatus.isEmpty {
                    Text(uploadStatus)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Sprawdź dostęp do aparatu") {
                    checkCameraPermissionOnly()
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .padding(.horizontal)

                List(summaries) { row in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(row.period ?? "Brak daty")
                            .font(.title2)
                            .bold()
                        Text("Wydano: \(row.spent) zł")
                            .font(.title3)
                        Text("Oszczędzono: \(row.saved) zł")
                            .font(.title3)
                    }
                    .padding(.vertical, 10)
                }

                VStack(spacing: 12) {
                    Button(action: { openBestScanner() }) {
                        Text("Zeskanuj paragon")
                            .font(.title2)
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 12) {
                        NavigationLink(destination: ReceiptListView()) {
                            Text("Lista")
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(destination: MatchReviewView()) {
                            Text("Dopasuj")
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Paragony")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Dodaj") {
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
            .task { await loadSummaries() }
        }
        .navigationViewStyle(.stack)
    }

    private func checkCameraPermissionOnly() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        uploadStatus = "Status aparatu: \(cameraStatusText(status))"
        requestCameraAccess { granted in
            let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
            uploadStatus = granted ? "Aparat dostępny: \(cameraStatusText(newStatus))" : "Brak dostępu: \(cameraStatusText(newStatus))"
        }
    }

    private func cameraStatusText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
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

    private func loadSummaries() async {
        do { summaries = try await APIClient.shared.summaries(period: period) }
        catch { uploadStatus = "Nie udało się pobrać podsumowań" }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysyłam paragon..."
        do {
            _ = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = "Paragon dodany"
            await loadSummaries()
        } catch {
            uploadStatus = "Błąd wysyłania paragonu"
        }
    }
}

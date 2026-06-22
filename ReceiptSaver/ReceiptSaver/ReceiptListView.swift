import SwiftUI
import AVFoundation

struct ReceiptListView: View {
    @State private var receipts: [Receipt] = []
    @State private var errorMessage = ""
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var showLibraryPicker = false
    @State private var showBankPicker = false
    @State private var pickerSource: ImagePicker.Source = .camera
    @State private var uploadStatus = ""
    @State private var queueStatus = ""
    @State private var queuePendingCount = 0
    @State private var queueTotalCount = 0
    @State private var queueProcessedCount = 0
    @State private var queueProgress = 0.0
    @State private var selectedBank = "ing"
    @State private var uploadQueue = ReceiptUploadQueue()

    private let accent = Color(red: 0.00, green: 0.36, blue: 0.20)
    private let banks = [("ing", "ING"), ("santander", "Santander")]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { openBestScanner() }) {
                        Label("Dodaj paragon", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                    Button(action: { showLibraryPicker = true }) {
                        Label("Import paragonów z biblioteki", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)

                    HStack {
                        Picker("Bank", selection: $selectedBank) {
                            ForEach(banks, id: \.0) { key, label in
                                Text(label).tag(key)
                            }
                        }
                        .pickerStyle(.menu)

                        Button(action: { showBankPicker = true }) {
                            Label("Import wyciągu", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                    }
                }
                .padding(.vertical, 6)

                if !statusText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statusText)
                            .font(.body)
                        if queueTotalCount > 0 && queueProgress < 1.0 {
                            ProgressView(value: queueProgress)
                            Text("\(queueProcessedCount) z \(queueTotalCount) paragonów")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Lista paragonów") {
                if receipts.isEmpty {
                    Text("Brak paragonów")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(receipts) { receipt in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(receipt.merchant_name.isEmpty ? "Nieznany sklep" : receipt.merchant_name)
                                .font(.title2)
                            Text("Suma: \(receipt.total_amount ?? "?") \(receipt.currency)")
                                .font(.title3)
                            if let saved = receipt.discount_total {
                                Text("Oszczędzono: \(saved) zł")
                                    .font(.title3)
                            }
                            if receipt.duplicate_of != nil {
                                Text("Możliwy duplikat")
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .navigationTitle("Paragony")
        .sheet(isPresented: $showPicker) {
            ImagePicker(source: pickerSource) { image in Task { await upload(image) } }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(onImage: { image in Task { await upload(image) } }, onCancel: {})
        }
        .sheet(isPresented: $showLibraryPicker) {
            MultiPhotoPicker(selectionLimit: 100) { images in
                uploadQueue.enqueue(images)
                syncQueueStatus()
                Task { await processQueue() }
            }
        }
        .sheet(isPresented: $showBankPicker) {
            BankStatementPicker { url in
                Task { await importBankStatement(url) }
            }
        }
        .task {
            await load()
            syncQueueStatus()
            await processQueueIfNeeded()
        }
    }

    private var statusText: String {
        var parts: [String] = []
        if !errorMessage.isEmpty { parts.append(errorMessage) }
        if !uploadStatus.isEmpty { parts.append(uploadStatus) }
        if !queueStatus.isEmpty { parts.append(queueStatus) }
        if queuePendingCount > 0 { parts.append("Kolejka importu: \(queuePendingCount).") }
        return parts.joined(separator: "\n")
    }

    private func syncQueueStatus() {
        queueStatus = uploadQueue.statusText
        queuePendingCount = uploadQueue.pendingCount
        queueTotalCount = uploadQueue.totalCount
        queueProcessedCount = uploadQueue.processedCount
        queueProgress = uploadQueue.progress
    }

    private func processQueueIfNeeded() async {
        await uploadQueue.resumeIfNeeded(onProgress: { syncQueueStatus() }, onUploaded: { await load() })
        syncQueueStatus()
    }

    private func processQueue() async {
        await uploadQueue.process(onProgress: { syncQueueStatus() }, onUploaded: { await load() })
        syncQueueStatus()
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

    private func load() async {
        do {
            receipts = try await APIClient.shared.receipts()
            errorMessage = ""
        } catch {
            errorMessage = "Nie udało się pobrać paragonów: \(errorMessageFor(error))"
        }
    }

    private func upload(_ image: UIImage) async {
        uploadStatus = "Wysyłam paragon..."
        do {
            _ = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = "Paragon dodany"
            await load()
        } catch {
            uploadStatus = "Błąd wysyłania paragonu: \(errorMessageFor(error))"
        }
    }

    private func importBankStatement(_ url: URL) async {
        uploadStatus = "Importuję wyciąg bankowy..."
        do {
            let result = try await APIClient.shared.importBankStatement(fileURL: url, bank: selectedBank)
            uploadStatus = "Zaimportowano transakcje: \(result.created)."
        } catch {
            uploadStatus = "Błąd importu wyciągu: \(errorMessageFor(error))"
        }
    }

    private func errorMessageFor(_ error: Error) -> String {
        if let apiError = error as? APIError { return apiError.errorDescription ?? "Błąd API" }
        if let urlError = error as? URLError { return "URL \(urlError.code.rawValue): \(urlError.localizedDescription)" }
        if let decodingError = error as? DecodingError { return "Błąd JSON: \(decodingError)" }
        return error.localizedDescription
    }
}

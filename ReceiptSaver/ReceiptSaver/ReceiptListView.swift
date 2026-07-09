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
    @State private var lastFailedAction: FailedAction?
    @State private var showRetryButton = false
    @State private var lastBankFileURL: URL?
    @State private var bankImportProgress = 0.0
    @State private var bankImportProgressText = ""
    @State private var receiptNeedingDate: Receipt?
    @State private var manualReceiptDate = Date()
    @State private var manualDateMessage = ""
    @State private var showManualDateSheet = false

    private let accent = Color(red: 0.00, green: 0.36, blue: 0.20)
    private let banks = [("ing", "ING"), ("santander", "Santander"), ("revolut", "Revolut")]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { openBestScanner() }) { Label("Dodaj paragon", systemImage: "camera.fill").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(.borderedProminent).tint(accent)
                    Button(action: { showLibraryPicker = true }) { Label("Import paragonów z biblioteki", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered).tint(accent)
                    HStack(spacing: 12) {
                        Picker("Bank", selection: $selectedBank) { ForEach(banks, id: \.0) { key, label in Text(label).tag(key) } }.pickerStyle(.menu)
                        Spacer(minLength: 8)
                        Button(action: { showBankPicker = true }) { Label("Import wyciągu", systemImage: "doc.badge.plus").lineLimit(1).padding(.horizontal, 16).padding(.vertical, 8) }.buttonStyle(.bordered).tint(accent)
                    }
                }.padding(.vertical, 6)
                if !statusText.isEmpty || lastFailedAction != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if !statusText.isEmpty { Text(statusText).font(.body) }
                        if queueTotalCount > 0 && queueProgress < 1.0 { ProgressView(value: queueProgress); Text("\(queueProcessedCount) z \(queueTotalCount) paragonów").font(.caption).foregroundColor(.secondary) }
                        if !bankImportProgressText.isEmpty && bankImportProgress < 1.0 { ProgressView(value: bankImportProgress); Text(bankImportProgressText).font(.caption).foregroundColor(.secondary) }
                        if showRetryButton, lastFailedAction != nil { Button(action: { retryLastFailedAction() }) { Label("Spróbuj ponownie", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 42).padding(.horizontal, 14) }.buttonStyle(.borderedProminent).tint(accent) }
                    }.padding(.vertical, 6)
                }
            }
            Section("Lista paragonów") {
                if receipts.isEmpty { Text("Brak paragonów").foregroundColor(.secondary) }
                else { ForEach(receipts) { receipt in VStack(alignment: .leading, spacing: 10) { Text(receipt.merchant_name.isEmpty ? "Nieznany sklep" : receipt.merchant_name).font(.title2); Text("Suma: \(receipt.total_amount ?? "?") \(receipt.currency)").font(.title3); if receipt.purchased_at == nil { Text("Data wymaga uzupełnienia").font(.headline) }; if let saved = receipt.discount_total { Text("Oszczędzono: \(saved) zł").font(.title3) }; if receipt.duplicate_of != nil { Text("Możliwy duplikat").font(.headline) } }.padding(.vertical, 10) } }
            }
        }
        .navigationTitle("Paragony")
        .sheet(isPresented: $showPicker) { ImagePicker(source: pickerSource) { image in Task { await upload(image) } } }
        .sheet(isPresented: $showScanner) { DocumentScannerView(onImage: { image in Task { await upload(image) } }, onCancel: {}) }
        .sheet(isPresented: $showLibraryPicker) { MultiPhotoPicker(selectionLimit: 100) { images in clearRetry(); uploadQueue.enqueue(images); syncQueueStatus(); Task { await processQueue() } } }
        .sheet(isPresented: $showBankPicker) { BankStatementPicker { url in lastBankFileURL = url; Task { await importBankStatement(url) } } }
        .sheet(isPresented: $showManualDateSheet) { manualDateView }
        .task { await load(); syncQueueStatus(); await processQueueIfNeeded(); await pollLatestBankImportIfNeeded() }
    }

    private var manualDateView: some View {
        NavigationStack {
            Form {
                Section("Data paragonu") {
                    if !manualDateMessage.isEmpty { Text(manualDateMessage).foregroundColor(.secondary) }
                    DatePicker("Data i godzina zakupu", selection: $manualReceiptDate, in: Calendar.current.date(byAdding: .year, value: -1, to: Date())!...Date())
                }
            }
            .navigationTitle("Uzupełnij datę")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { showManualDateSheet = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Zapisz") { Task { await saveManualDate() } } }
            }
        }
    }

    private var statusText: String { var parts: [String] = []; if !errorMessage.isEmpty { parts.append(errorMessage) }; if !uploadStatus.isEmpty { parts.append(uploadStatus) }; if !queueStatus.isEmpty { parts.append(queueStatus) }; if queuePendingCount > 0 { parts.append("Kolejka importu: \(queuePendingCount).") }; return parts.joined(separator: "\n") }
    private func syncQueueStatus() { queueStatus = uploadQueue.statusText; queuePendingCount = uploadQueue.pendingCount; queueTotalCount = uploadQueue.totalCount; queueProcessedCount = uploadQueue.processedCount; queueProgress = uploadQueue.progress }
    private func processQueueIfNeeded() async { await uploadQueue.resumeIfNeeded(onProgress: { syncQueueStatus() }, onUploaded: { await load() }); syncQueueStatus() }
    private func processQueue() async { clearRetry(); await uploadQueue.process(onProgress: { syncQueueStatus() }, onUploaded: { await load() }); syncQueueStatus(); if uploadQueue.pendingCount > 0 { scheduleRetry(.receiptQueue) } }
    private func openBestScanner() { requestCameraAccess { granted in guard granted else { uploadStatus = "Brak dostępu do aparatu. Włącz dostęp w Ustawieniach."; scheduleRetry(.scanner); return }; if DocumentScannerView.isAvailable { showScanner = true } else { pickerSource = .camera; showPicker = true } } }
    private func requestCameraAccess(_ completion: @escaping (Bool) -> Void) { switch AVCaptureDevice.authorizationStatus(for: .video) { case .authorized: completion(true); case .notDetermined: AVCaptureDevice.requestAccess(for: .video) { granted in DispatchQueue.main.async { completion(granted) } }; default: completion(false) } }

    private func load() async { do { receipts = try await APIClient.shared.receipts(); errorMessage = ""; if lastFailedAction == .loadReceipts { clearRetry() } } catch { errorMessage = "Nie udało się pobrać paragonów: \(errorMessageFor(error))"; scheduleRetry(.loadReceipts) } }

    private func upload(_ image: UIImage) async {
        clearRetry(); uploadStatus = "Wysyłam paragon..."
        do {
            let result = try await APIClient.shared.uploadReceipt(image: image)
            uploadStatus = result.requiresManualDate ? result.message : "Paragon dodany"
            await load()
            if result.requiresManualDate { receiptNeedingDate = result.receipt; manualReceiptDate = Date(); manualDateMessage = result.message; showManualDateSheet = true }
        } catch { uploadStatus = "Błąd skanowania paragonu: \(errorMessageFor(error))"; scheduleRetry(.scanner) }
    }

    private func saveManualDate() async {
        guard let receipt = receiptNeedingDate else { return }
        do { _ = try await APIClient.shared.setReceiptDate(receiptID: receipt.id, date: manualReceiptDate); showManualDateSheet = false; receiptNeedingDate = nil; uploadStatus = "Data paragonu zapisana"; await load() }
        catch { manualDateMessage = "Nie udało się zapisać daty: \(errorMessageFor(error))" }
    }

    private func importBankStatement(_ url: URL) async { clearRetry(); bankImportProgress = 0.0; bankImportProgressText = ""; uploadStatus = "Import wyciągu został dodany do kolejki..."; do { _ = try await APIClient.shared.importBankStatement(fileURL: url, bank: selectedBank); await pollLatestBankImportIfNeeded(force: true) } catch { uploadStatus = "Błąd importu wyciągu: \(errorMessageFor(error))"; lastBankFileURL = url; scheduleRetry(.bankImport) } }
    private func pollLatestBankImportIfNeeded(force: Bool = false) async { do { let status = try await APIClient.shared.latestBankImportStatus(); guard force || status.status == "queued" || status.status == "running" else { return }; await pollBankImport(status) } catch {} }
    private func pollBankImport(_ initial: BankImportJobStatus) async { var current = initial; while true { updateBankImportStatus(current); if current.status == "completed" { uploadStatus = "Zaimportowano transakcje: \(current.created)."; bankImportProgress = 1.0; bankImportProgressText = ""; await load(); clearRetry(); return }; if current.status == "failed" { uploadStatus = current.error_message.isEmpty ? "Błąd importu wyciągu." : "Błąd importu wyciągu: \(current.error_message)"; bankImportProgressText = ""; scheduleRetry(.bankImport); return }; try? await Task.sleep(nanoseconds: 10_000_000_000); do { current = try await APIClient.shared.bankImportStatus(jobID: current.job_id) } catch { uploadStatus = "Nie udało się sprawdzić statusu importu: \(errorMessageFor(error))"; scheduleRetry(.bankImport); return } } }
    private func updateBankImportStatus(_ status: BankImportJobStatus) { if status.progress_total > 0 { bankImportProgress = min(1.0, Double(status.progress_current) / Double(status.progress_total)); bankImportProgressText = "\(status.progress_current) z \(status.progress_total) transakcji" } else { bankImportProgress = 0.15; bankImportProgressText = "Przygotowywanie importu" }; uploadStatus = status.status == "queued" ? "Import wyciągu czeka w kolejce..." : "Import wyciągu trwa..." }
    private func scheduleRetry(_ action: FailedAction) { lastFailedAction = action; showRetryButton = false; Task { @MainActor in try? await Task.sleep(nanoseconds: 7_000_000_000); if lastFailedAction == action { showRetryButton = true } } }
    private func clearRetry() { lastFailedAction = nil; showRetryButton = false }
    private func retryLastFailedAction() { guard let action = lastFailedAction else { return }; clearRetry(); switch action { case .loadReceipts: Task { await load() }; case .receiptQueue: Task { await processQueue() }; case .bankImport: if let url = lastBankFileURL { Task { await importBankStatement(url) } } else { showBankPicker = true }; case .scanner: openBestScanner() } }
    private func errorMessageFor(_ error: Error) -> String { if let apiError = error as? APIError { return apiError.errorDescription ?? "Błąd API" }; if let urlError = error as? URLError { return "URL \(urlError.code.rawValue): \(urlError.localizedDescription)" }; if let decodingError = error as? DecodingError { return "Błąd JSON: \(decodingError)" }; return error.localizedDescription }
}

private enum FailedAction: Equatable { case loadReceipts; case scanner; case receiptQueue; case bankImport }

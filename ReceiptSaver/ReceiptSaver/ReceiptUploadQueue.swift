import Foundation
import UIKit

@MainActor
final class ReceiptUploadQueue {
    var pendingCount: Int = 0
    var totalCount: Int = 0
    var processedCount: Int = 0
    var isProcessing = false
    var statusText = ""
    private let directoryName = "ReceiptUploadQueue"

    init() { refreshPendingCount(); totalCount = pendingCount }
    var progress: Double { guard totalCount > 0 else { return 0 }; return min(1, max(0, Double(processedCount) / Double(totalCount))) }

    func enqueue(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let directory = queueDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for image in images {
            let processed = image.preprocessedForReceipt()
            guard let data = processed.jpegData(compressionQuality: 0.72) else { continue }
            try? data.write(to: directory.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).jpg"), options: .atomic)
        }
        refreshPendingCount(); totalCount = pendingCount; processedCount = 0; statusText = "Dodano do kolejki: \(images.count)."
    }

    func resumeIfNeeded(onProgress: @escaping () -> Void, onUploaded: @escaping () async -> Void) async {
        refreshPendingCount(); totalCount = pendingCount; processedCount = 0; onProgress()
        guard pendingCount > 0 else { return }
        await process(onProgress: onProgress, onUploaded: onUploaded)
    }

    func process(onProgress: @escaping () -> Void, onUploaded: @escaping () async -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false; onProgress() }
        refreshPendingCount(); if totalCount == 0 { totalCount = pendingCount }; onProgress()
        while let next = nextFile() {
            refreshPendingCount()
            let current = min(totalCount, processedCount + 1)
            statusText = "Wysyłam paragon \(current) z \(max(totalCount, current))."; onProgress()
            guard let image = UIImage(contentsOfFile: next.path) else { try? FileManager.default.removeItem(at: next); processedCount += 1; refreshPendingCount(); onProgress(); continue }
            do {
                let result = try await APIClient.shared.uploadReceipt(image: image)
                try? FileManager.default.removeItem(at: next)
                processedCount += 1; refreshPendingCount()
                statusText = result.requiresManualDate ? "Paragon odczytany, ale data wymaga ręcznego uzupełnienia na liście paragonów." : (pendingCount == 0 ? "Import z biblioteki zakończony." : "Paragon dodany. Czekam 2 sekundy przed następnym.")
                onProgress(); await onUploaded()
                if pendingCount > 0 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
            } catch {
                refreshPendingCount(); statusText = "Przerwano import. Błąd: \(error.localizedDescription). Kolejka zostaje zapisana."; onProgress(); return
            }
        }
    }

    private func refreshPendingCount() { pendingCount = queuedFiles().count }
    private func nextFile() -> URL? { queuedFiles().first }
    private func queuedFiles() -> [URL] { let files = (try? FileManager.default.contentsOfDirectory(at: queueDirectory(), includingPropertiesForKeys: nil)) ?? []; return files.filter { $0.pathExtension.lowercased() == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent } }
    private func queueDirectory() -> URL { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!; return base.appendingPathComponent(directoryName, isDirectory: true) }
}

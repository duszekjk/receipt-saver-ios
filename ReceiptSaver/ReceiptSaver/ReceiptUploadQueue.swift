import Foundation
import UIKit

@MainActor
final class ReceiptUploadQueue: ObservableObject {
    @Published var pendingCount: Int = 0
    @Published var isProcessing = false
    @Published var statusText = ""

    private let directoryName = "ReceiptUploadQueue"

    init() {
        refreshPendingCount()
    }

    func enqueue(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let directory = queueDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for image in images {
            let processed = image.preprocessedForReceipt()
            guard let data = processed.jpegData(compressionQuality: 0.72) else { continue }
            let filename = "\(Date().timeIntervalSince1970)-\(UUID().uuidString).jpg"
            try? data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        }

        refreshPendingCount()
        statusText = "Dodano do kolejki: \(images.count). Pozostało: \(pendingCount)."
    }

    func resumeIfNeeded(onUploaded: @escaping () async -> Void) async {
        refreshPendingCount()
        guard pendingCount > 0 else { return }
        await process(onUploaded: onUploaded)
    }

    func process(onUploaded: @escaping () async -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let next = nextFile() {
            refreshPendingCount()
            statusText = "Wysyłam paragon z kolejki. Pozostało: \(pendingCount)."

            guard let image = UIImage(contentsOfFile: next.path) else {
                try? FileManager.default.removeItem(at: next)
                refreshPendingCount()
                continue
            }

            do {
                _ = try await APIClient.shared.uploadReceipt(image: image)
                try? FileManager.default.removeItem(at: next)
                refreshPendingCount()
                statusText = pendingCount == 0 ? "Import z biblioteki zakończony." : "Paragon dodany. Czekam 2 sekundy przed następnym."
                await onUploaded()
                if pendingCount > 0 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            } catch {
                refreshPendingCount()
                statusText = "Przerwano import. Błąd: \(error.localizedDescription). Kolejka zostaje zapisana."
                return
            }
        }
    }

    private func refreshPendingCount() {
        pendingCount = queuedFiles().count
    }

    private func nextFile() -> URL? {
        queuedFiles().first
    }

    private func queuedFiles() -> [URL] {
        let directory = queueDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func queueDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }
}

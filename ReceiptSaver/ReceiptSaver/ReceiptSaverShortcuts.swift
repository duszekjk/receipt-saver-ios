import Foundation

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers

@available(iOS 16.0, macOS 13.0, *)
struct AddToReceiptSaverIntent: AppIntent {
    static var title: LocalizedStringResource = "Dodaj do Receipt Saver"
    static var description = IntentDescription("Importuje treść wiadomości e-mail oraz załączniki, takie jak PDF, TXT, HTML lub CSV, i próbuje dopasować zakup do transakcji bankowej.")
    static var openAppWhenRun = false

    @Parameter(title: "Treść wiadomości")
    var text: String?

    @Parameter(title: "Załączniki")
    var files: [IntentFile]?

    static var parameterSummary: some ParameterSummary {
        Summary("Dodaj do Receipt Saver \(.$text) \(.$files)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var attachments: [EmailImportAttachment] = []
        for file in files ?? [] {
            let data = file.data
            let filename = file.filename.isEmpty ? "attachment" : file.filename
            let mimeType = file.type?.preferredMIMEType ?? "application/octet-stream"
            attachments.append(EmailImportAttachment(filename: filename, mimeType: mimeType, data: data))
        }

        let body = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !body.isEmpty || !attachments.isEmpty else {
            throw $text.needsValueError("Przekaż treść wiadomości albo co najmniej jeden załącznik.")
        }

        let result = try await APIClient.shared.importPurchaseEmail(text: body, attachments: attachments)
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct ReceiptSaverShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToReceiptSaverIntent(),
            phrases: [
                "Dodaj do \(.applicationName)",
                "Zaimportuj zakup do \(.applicationName)",
                "Dodaj rachunek do \(.applicationName)"
            ],
            shortTitle: "Dodaj do Receipt Saver",
            systemImageName: "tray.and.arrow.down.fill"
        )
    }
}
#endif

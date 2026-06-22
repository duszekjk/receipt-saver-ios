import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BankStatementPicker: UIViewControllerRepresentable {
    let onFile: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.commaSeparatedText, .plainText, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFile: onFile)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFile: (URL) -> Void

        init(onFile: @escaping (URL) -> Void) {
            self.onFile = onFile
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onFile(url)
        }
    }
}

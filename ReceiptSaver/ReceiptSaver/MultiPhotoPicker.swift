import SwiftUI
import UIKit
import PhotosUI

struct MultiPhotoPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onImages: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImages: onImages)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImages: ([UIImage]) -> Void

        init(onImages: @escaping ([UIImage]) -> Void) {
            self.onImages = onImages
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                onImages([])
                return
            }

            var images = Array<UIImage?>(repeating: nil, count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        images[index] = object as? UIImage
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.onImages(images.compactMap { $0 })
            }
        }
    }
}

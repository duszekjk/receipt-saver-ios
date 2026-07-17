import SwiftUI
import UIKit
import VisionKit

struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case library

        var uiType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .library: return .photoLibrary
            }
        }
    }

    let source: Source
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(source.uiType) ? source.uiType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image.preprocessedForReceipt())
            }
            picker.dismiss(animated: true)
        }
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true) { self.onCancel() }
                return
            }

            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0).preprocessedForReceipt() }
            guard pages.count > 1 else {
                controller.dismiss(animated: true) { self.onImage(pages[0]) }
                return
            }

            let choice = UIAlertController(
                title: "Jak traktować zeskanowane strony?",
                message: "Wybierz, czy strony tworzą jeden dokument, czy każda strona jest osobnym paragonem.",
                preferredStyle: .actionSheet
            )
            choice.addAction(UIAlertAction(title: "Jeden wielostronicowy dokument", style: .default) { _ in
                guard let document = UIImage.combinedDocument(from: pages) else {
                    controller.dismiss(animated: true) {
                        ToastCenter.shared.show("Nie udało się połączyć stron dokumentu.", style: .error)
                    }
                    return
                }
                controller.dismiss(animated: true) { self.onImage(document) }
            })
            choice.addAction(UIAlertAction(title: "Każda strona to osobny paragon", style: .default) { _ in
                controller.dismiss(animated: true) {
                    for (index, page) in pages.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                            self.onImage(page)
                        }
                    }
                }
            })
            choice.addAction(UIAlertAction(title: "Anuluj", style: .cancel))
            if let popover = choice.popoverPresentationController {
                popover.sourceView = controller.view
                popover.sourceRect = CGRect(
                    x: controller.view.bounds.midX,
                    y: controller.view.bounds.maxY - 1,
                    width: 1,
                    height: 1
                )
            }
            controller.present(choice, animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { self.onCancel() }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                ToastCenter.shared.show("Nie udało się zeskanować dokumentu: \(error.localizedDescription)", style: .error)
                self.onCancel()
            }
        }
    }
}

extension UIImage {
    func preprocessedForReceipt(maxDimension: CGFloat = 1800) -> UIImage {
        let resized: UIImage
        if size.height > size.width * 1.8 {
            resized = resizedKeepingWidth(maxWidth: maxDimension)
        } else {
            resized = resizedKeepingAspect(maxDimension: maxDimension)
        }
        return resized.grayscaleImage() ?? resized
    }

    static func combinedDocument(from pages: [UIImage], maxPageWidth: CGFloat = 1800) -> UIImage? {
        guard !pages.isEmpty else { return nil }
        let normalized = pages.map { $0.resizedKeepingWidth(maxWidth: maxPageWidth).grayscaleImage() ?? $0 }
        let width = normalized.map(\.size.width).max() ?? maxPageWidth
        let height = normalized.reduce(CGFloat.zero) { $0 + $1.size.height }
        guard width > 0, height > 0 else { return nil }

        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
        var y: CGFloat = 0
        for page in normalized {
            let x = (width - page.size.width) / 2
            page.draw(in: CGRect(x: x, y: y, width: page.size.width, height: page.size.height))
            y += page.size.height
        }
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    private func resizedKeepingAspect(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / max(size.width, size.height), 1)
        return resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }

    private func resizedKeepingWidth(maxWidth: CGFloat) -> UIImage {
        let scale = min(maxWidth / size.width, 1)
        return resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }

    private func resized(to newSize: CGSize) -> UIImage {
        guard newSize.width > 0, newSize.height > 0, newSize != size else { return self }
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }

    private func grayscaleImage() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let grayCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: grayCGImage, scale: 1.0, orientation: imageOrientation)
    }
}
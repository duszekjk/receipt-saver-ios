import SwiftUI
import UIKit

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

extension UIImage {
    func preprocessedForReceipt(maxDimension: CGFloat = 1600) -> UIImage {
        let scale = min(maxDimension / max(size.width, size.height), 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }
}

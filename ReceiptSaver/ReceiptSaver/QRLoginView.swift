import AVFoundation
import SwiftUI

struct QRLoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var status = "Zeskanuj kod QR z panelu admina."
    @State private var showScanner = true

    var body: some View {
        VStack(spacing: 24) {
            Text("Logowanie")
                .font(.largeTitle)
                .bold()

            Text(status)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if showScanner {
                QRScannerView { code in
                    handle(code)
                }
                .frame(maxWidth: .infinity, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding()
            }

            Button("Spróbuj ponownie") {
                status = "Zeskanuj kod QR z panelu admina."
                showScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showScanner = true }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func handle(_ code: String) {
        guard let data = code.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AppLoginPayload.self, from: data),
              payload.type == "receipt_saver_login" else {
            status = "Nieprawidłowy kod QR."
            return
        }
        do {
            try CredentialStore.shared.save(AppCredentials(payload: payload))
            status = "Zalogowano."
            isLoggedIn = true
        } catch {
            status = "Nie udało się zapisać tokenu w Keychain."
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configure()
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = object.stringValue else { return }
        didScan = true
        session.stopRunning()
        onCode?(string)
    }
}

import AVFoundation
import SwiftUI

struct QRLoginView: View {
    @ObservedObject var accessStore: AppAccessStore
    @State private var status = "Aplikacja jest dostępna na zaproszenie."
    @State private var showScanner = false
    @State private var showHelp = false
    @State private var isCreatingGuest = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 54))
                    .foregroundColor(.accentColor)
                    .padding(.top, 28)

                Text("Receipt Saver")
                    .font(.largeTitle)
                    .bold()

                Text(status)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if showScanner {
                    QRScannerView(
                        onCode: handle,
                        onError: { message in
                            status = message
                            showScanner = false
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                }

                Button {
                    openScanner()
                } label: {
                    Label(showScanner ? "Spróbuj ponownie" : "Zaloguj się kodem QR", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(isCreatingGuest)

                Button {
                    Task { await createGuest() }
                } label: {
                    HStack {
                        if isCreatingGuest {
                            ProgressView()
                        }
                        Text(isCreatingGuest ? "Przygotowywanie dostępu…" : "Korzystaj jako gość")
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(isCreatingGuest)

                Button("Jak uzyskać dostęp?") {
                    showHelp = true
                }
                .font(.footnote)

                Text("Bez zaproszenia możesz korzystać z aplikacji jako gość. Skanowanie paragonów, import wyciągów i synchronizacja są dostępne także w tym trybie.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationView {
                List {
                    Section("Dostęp na zaproszenie") {
                        Text("Po otrzymaniu zaproszenia wybierz „Zaloguj się kodem QR” i zeskanuj otrzymany kod.")
                        Text("Bez zaproszenia możesz korzystać z aplikacji jako gość. Dane dodane w tym trybie pozostają przypisane do tego dostępu.")
                    }
                }
                .navigationTitle("Pomoc")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Zamknij") { showHelp = false }
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private func openScanner() {
        let open = {
            status = "Zeskanuj kod QR otrzymany w zaproszeniu."
            if showScanner {
                showScanner = false
                DispatchQueue.main.async {
                    showScanner = true
                }
            } else {
                showScanner = true
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            open()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        open()
                    } else {
                        status = "Włącz dostęp do aparatu w Ustawieniach, aby zeskanować kod QR."
                    }
                }
            }
        case .denied, .restricted:
            status = "Włącz dostęp do aparatu w Ustawieniach, aby zeskanować kod QR."
            showScanner = false
        @unknown default:
            status = "Nie udało się uruchomić aparatu."
            showScanner = false
        }
    }

    @MainActor
    private func createGuest() async {
        guard !isCreatingGuest else { return }
        isCreatingGuest = true
        status = "Przygotowuję dostęp gościa…"
        defer { isCreatingGuest = false }

        do {
            let payload = try await APIClient.shared.registerGuest()
            try CredentialStore.shared.save(AppCredentials(payload: payload))
            status = "Gotowe."
            accessStore.completeGuestRegistration()
        } catch {
            status = "Nie udało się uruchomić trybu gościa: \(error.localizedDescription)"
        }
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
            accessStore.completeLogin()
        } catch {
            status = "Nie udało się zapisać danych logowania."
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "receipt-saver.qr-camera")
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    private var isConfigured = false
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            defer { self.session.commitConfiguration() }

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            guard let camera = discovery.devices.first ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {
                self.reportError("Nie udało się uruchomić aparatu na tym urządzeniu.")
                return
            }
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                self.reportError("Nie udało się uruchomić skanera kodów QR.")
                return
            }
            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []

            guard output.metadataObjectTypes.contains(.qr) else {
                self.reportError("Skanowanie kodów QR nie jest dostępne na tym urządzeniu.")
                return
            }

            self.isConfigured = true
            if self.viewIfLoaded?.window != nil {
                self.session.startRunning()
            }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.didScan = false
            self.session.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = object.stringValue else { return }
        didScan = true
        stopSession()
        onCode?(string)
    }
}

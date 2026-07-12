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
                    QRScannerView { code in
                        handle(code)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                }

                Button {
                    if showScanner {
                        status = "Zeskanuj kod QR otrzymany od administratora."
                        showScanner = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showScanner = true
                        }
                    } else {
                        status = "Zeskanuj kod QR otrzymany od administratora."
                        showScanner = true
                    }
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
                        Text(isCreatingGuest ? "Tworzenie dostępu gościa…" : "Korzystaj jako gość")
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

                Text("Gość otrzymuje oddzielny profil Receipt Saver bez konta użytkownika Django. Skanowanie, import bankowy i synchronizacja działają normalnie, ale gość nie ma dostępu do panelu administracyjnego ani funkcji rodzinnych.")
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
                        Text("Pełne konto jest tworzone przez administratora aplikacji. Po otrzymaniu kodu QR wybierz „Zaloguj się kodem QR” i zeskanuj kod.")
                        Text("Bez zaproszenia można utworzyć profil gościa. Profil gościa nie jest użytkownikiem Django, ale pozwala korzystać ze skanowania paragonów, importu wyciągów i pozostałych funkcji aplikacji.")
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

    @MainActor
    private func createGuest() async {
        guard !isCreatingGuest else { return }
        isCreatingGuest = true
        status = "Tworzę bezpieczny profil gościa…"
        defer { isCreatingGuest = false }

        do {
            let payload = try await APIClient.shared.registerGuest()
            try CredentialStore.shared.save(AppCredentials(payload: payload))
            status = "Profil gościa został utworzony."
            accessStore.completeGuestRegistration()
        } catch {
            status = "Nie udało się utworzyć profilu gościa: \(error.localizedDescription)"
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

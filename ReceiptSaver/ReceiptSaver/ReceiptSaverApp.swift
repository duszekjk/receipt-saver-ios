import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct ReceiptSaverApp: App {
    @StateObject private var accessStore: AppAccessStore
    @StateObject private var toastCenter = ToastCenter.shared

    init() {
        if ProcessInfo.processInfo.arguments.contains("-reset-app-state") {
            CredentialStore.shared.delete()
            LocalCache.shared.clear()
            URLCache.shared.removeAllCachedResponses()
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
        }

        _accessStore = StateObject(wrappedValue: AppAccessStore())

        #if canImport(AppIntents)
        if #available(iOS 16.0, macOS 13.0, *) {
            ReceiptSaverShortcuts.updateAppShortcutParameters()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch accessStore.mode {
                case .signedIn, .guest:
                    MainTabView()
                case .signedOut:
                    QRLoginView(accessStore: accessStore)
                }
            }
            .environmentObject(accessStore)
            .environmentObject(toastCenter)
            .appToastOverlay(toastCenter)
            .tint(Color(red: 0.00, green: 0.36, blue: 0.20))
        }
    }
}

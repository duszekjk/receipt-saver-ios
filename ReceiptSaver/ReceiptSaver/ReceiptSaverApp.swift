import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct ReceiptSaverApp: App {
    @State private var isLoggedIn = CredentialStore.shared.load() != nil

    init() {
        #if canImport(AppIntents)
        if #available(iOS 16.0, macOS 13.0, *) {
            ReceiptSaverShortcuts.updateAppShortcutParameters()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                MainTabView()
                    .tint(Color(red: 0.00, green: 0.36, blue: 0.20))
            } else {
                QRLoginView(isLoggedIn: $isLoggedIn)
                    .tint(Color(red: 0.00, green: 0.36, blue: 0.20))
            }
        }
    }
}

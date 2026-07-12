import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct ReceiptSaverApp: App {
    @StateObject private var accessStore = AppAccessStore.shared
    @StateObject private var toastCenter = ToastCenter.shared

    init() {
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
            .environmentObject(toastCenter)
            .appToastOverlay(toastCenter)
            .tint(Color(red: 0.00, green: 0.36, blue: 0.20))
        }
    }
}

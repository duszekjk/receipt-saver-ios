import SwiftUI

@main
struct ReceiptSaverApp: App {
    @State private var isLoggedIn = CredentialStore.shared.load() != nil

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                DashboardView()
            } else {
                QRLoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}

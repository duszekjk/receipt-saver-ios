import SwiftUI

@main
struct ReceiptSaverApp: App {
    @State private var isLoggedIn = CredentialStore.shared.load() != nil

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

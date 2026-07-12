import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject private var accessStore: AppAccessStore
    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            Section("Konto") {
                Button("Wyloguj się", role: .destructive) {
                    showSignOutConfirmation = true
                }
            }
        }
        .navigationTitle("Ustawienia")
        .confirmationDialog(
            "Wylogować się?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Wyloguj", role: .destructive) {
                accessStore.signOut()
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Wszystkie dane zapisane lokalnie przez obecne konto zostaną usunięte. Dane na serwerze pozostaną bez zmian.")
        }
    }
}

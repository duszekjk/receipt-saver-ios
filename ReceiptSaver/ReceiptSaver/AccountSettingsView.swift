import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject private var accessStore: AppAccessStore
    @State private var confirmation: Confirmation?

    var body: some View {
        List {
            Section("Konto") {
                Button("Wyloguj się") {
                    confirmation = .signOut
                }

                Button("Przełącz konto") {
                    confirmation = .switchAccount
                }
            }

            Section("Testowanie i dane lokalne") {
                Button("Resetuj aplikację", role: .destructive) {
                    confirmation = .reset
                }
            }
        }
        .navigationTitle("Ustawienia")
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation {
                Button(confirmation.actionTitle, role: confirmation.role) {
                    perform(confirmation)
                }
                Button("Anuluj", role: .cancel) {}
            }
        } message: {
            if let confirmation {
                Text(confirmation.message)
            }
        }
    }

    private func perform(_ confirmation: Confirmation) {
        self.confirmation = nil
        switch confirmation {
        case .signOut:
            accessStore.signOut()
        case .switchAccount:
            accessStore.switchAccount()
        case .reset:
            accessStore.resetApplication()
        }
    }
}

private enum Confirmation {
    case signOut
    case switchAccount
    case reset

    var title: String {
        switch self {
        case .signOut: return "Wylogować się?"
        case .switchAccount: return "Przełączyć konto?"
        case .reset: return "Zresetować aplikację?"
        }
    }

    var message: String {
        switch self {
        case .signOut:
            return "Token logowania i dane lokalne zostaną usunięte. Dane zapisane na serwerze pozostaną bez zmian."
        case .switchAccount:
            return "Wrócisz do ekranu wyboru logowania i konta gościa."
        case .reset:
            return "Keychain, ustawienia i lokalny cache zostaną usunięte. Aplikacja wróci do stanu pierwszego uruchomienia."
        }
    }

    var actionTitle: String {
        switch self {
        case .signOut: return "Wyloguj"
        case .switchAccount: return "Przełącz konto"
        case .reset: return "Resetuj"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .reset: return .destructive
        case .signOut, .switchAccount: return nil
        }
    }
}

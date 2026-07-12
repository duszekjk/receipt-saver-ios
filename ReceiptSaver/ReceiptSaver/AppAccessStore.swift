import Foundation

enum AppAccessMode {
    case signedOut
    case guest
    case signedIn
}

final class AppAccessStore: ObservableObject {
    static let shared = AppAccessStore()

    private let guestKey = "receipt_saver_guest_mode"

    @Published private(set) var mode: AppAccessMode

    private init() {
        if CredentialStore.shared.load() != nil {
            mode = .signedIn
        } else if UserDefaults.standard.bool(forKey: guestKey) {
            mode = .guest
        } else {
            mode = .signedOut
        }
    }

    func enterGuestMode() {
        UserDefaults.standard.set(true, forKey: guestKey)
        mode = .guest
    }

    func completeLogin() {
        UserDefaults.standard.set(false, forKey: guestKey)
        mode = .signedIn
    }

    func leaveGuestMode() {
        UserDefaults.standard.set(false, forKey: guestKey)
        mode = CredentialStore.shared.load() == nil ? .signedOut : .signedIn
    }
}

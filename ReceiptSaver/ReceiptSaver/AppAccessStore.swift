import Foundation
import Combine


enum AppAccessMode: Equatable {
    case signedOut
    case guest
    case signedIn
}

@MainActor
final class AppAccessStore: ObservableObject {
    static let shared = AppAccessStore()

    private let guestKey = "receipt_saver_guest_mode"
    private let credentialStore: CredentialStoring
    private let defaults: UserDefaults
    private let localCache: LocalCache

    @Published private(set) var mode: AppAccessMode

    init(
        credentialStore: CredentialStoring = CredentialStore.shared,
        defaults: UserDefaults = .standard,
        localCache: LocalCache = .shared
    ) {
        self.credentialStore = credentialStore
        self.defaults = defaults
        self.localCache = localCache

        if credentialStore.load() == nil {
            mode = .signedOut
        } else if defaults.bool(forKey: guestKey) {
            mode = .guest
        } else {
            mode = .signedIn
        }
    }

    func completeGuestRegistration() {
        defaults.set(true, forKey: guestKey)
        mode = .guest
    }

    func completeLogin() {
        defaults.set(false, forKey: guestKey)
        mode = .signedIn
    }

    func signOut() {
        credentialStore.delete()
        localCache.clear()
        URLCache.shared.removeAllCachedResponses()

        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }

        mode = .signedOut
    }
}

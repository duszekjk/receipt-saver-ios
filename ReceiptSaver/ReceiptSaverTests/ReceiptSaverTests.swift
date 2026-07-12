import Testing
@testable import ReceiptSaver

@MainActor
struct ReceiptSaverTests {
    @Test func startsSignedOutWithoutCredentials() {
        let fixture = AccessStoreFixture(credentials: nil)
        #expect(fixture.store.mode == .signedOut)
    }

    @Test func restoresSignedInAccount() {
        let fixture = AccessStoreFixture(credentials: .test)
        #expect(fixture.store.mode == .signedIn)
    }

    @Test func restoresGuestAccount() {
        let fixture = AccessStoreFixture(credentials: .test, guest: true)
        #expect(fixture.store.mode == .guest)
    }

    @Test func signOutRemovesAllLocalUserData() {
        let fixture = AccessStoreFixture(credentials: .test, guest: true)
        fixture.defaults.set(Data([1, 2, 3]), forKey: "offline_receipts")
        fixture.defaults.set(Data([4, 5, 6]), forKey: "offline_summaries_month")
        fixture.defaults.set("value", forKey: "user_preference")

        fixture.store.signOut()

        #expect(fixture.store.mode == .signedOut)
        #expect(fixture.credentials.load() == nil)
        #expect(fixture.defaults.dictionaryRepresentation().isEmpty)
    }
}

@MainActor
private struct AccessStoreFixture {
    let defaults: UserDefaults
    let credentials: MemoryCredentialStore
    let store: AppAccessStore

    init(credentials: AppCredentials?, guest: Bool = false) {
        let suiteName = "ReceiptSaverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(guest, forKey: "receipt_saver_guest_mode")

        let credentialStore = MemoryCredentialStore(credentials)
        self.defaults = defaults
        self.credentials = credentialStore
        self.store = AppAccessStore(
            credentialStore: credentialStore,
            defaults: defaults,
            localCache: LocalCache(defaults: defaults)
        )
    }
}

private final class MemoryCredentialStore: CredentialStoring {
    private var credentials: AppCredentials?

    init(_ credentials: AppCredentials?) {
        self.credentials = credentials
    }

    func load() -> AppCredentials? {
        credentials
    }

    func save(_ credentials: AppCredentials) throws {
        self.credentials = credentials
    }

    func delete() {
        credentials = nil
    }
}

private extension AppCredentials {
    static let test = AppCredentials(deviceID: "test-device", secretKey: "test-secret")
}

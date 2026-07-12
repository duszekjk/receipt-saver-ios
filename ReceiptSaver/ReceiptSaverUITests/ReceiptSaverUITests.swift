import XCTest

final class ReceiptSaverUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-reset-app-state")
        app.launch()
    }

    @MainActor
    func testResetLaunchShowsLoginChoices() throws {
        XCTAssertTrue(app.buttons["Zaloguj się kodem QR"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Korzystaj jako gość"].exists)
        XCTAssertTrue(app.buttons["Jak uzyskać dostęp?"].exists)
    }

    @MainActor
    func testHelpCanBeOpenedAndClosed() throws {
        let helpButton = app.buttons["Jak uzyskać dostęp?"]
        XCTAssertTrue(helpButton.waitForExistence(timeout: 5))
        helpButton.tap()

        XCTAssertTrue(app.navigationBars["Pomoc"].waitForExistence(timeout: 3))
        app.buttons["Zamknij"].tap()
        XCTAssertTrue(app.buttons["Korzystaj jako gość"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let measuredApp = XCUIApplication()
            measuredApp.launchArguments.append("-reset-app-state")
            measuredApp.launch()
        }
    }
}

import XCTest

/// Smoke UI tests that tap through the tabs without requiring any device permission.
final class SproutUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPROUT_NO_SK"] = "1"   // no StoreKit sign-in prompt
        app.launchEnvironment["SPROUT_SEED"] = "1"    // one child + story seeded
        if pro { app.launchEnvironment["SPROUT_FORCE_PRO"] = "1" }
        app.launch()
        return app
    }

    func testTabsExistAndSwitch() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Tonight"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.tabBars.buttons["Tonight"].tap()
    }
}

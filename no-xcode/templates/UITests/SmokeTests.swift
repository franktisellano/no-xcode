import XCTest

final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testIncrementAndReset() {
        let app = LaunchHelper.launchInTestMode()
        let home = HomeScreen(app: app)

        XCTAssertTrue(home.countLabel.waitForExistence(timeout: 10))
        XCTAssertEqual(home.count, "3", "Test mode should seed count = 3")

        home.incrementButton.tap()
        XCTAssertEqual(home.count, "4")

        home.resetButton.tap()
        XCTAssertEqual(home.count, "0")
    }
}

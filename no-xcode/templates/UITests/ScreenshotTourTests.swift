import XCTest

/// Visual tour: one named screenshot per screen, sheet and state, in a fixed order
/// (`Tour-NN-Name`). Run `make tour`, then read build/screenshots/Tour-*.png after a UI change.
/// Extend it whenever you add a screen.
final class ScreenshotTourTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTour() {
        let app = LaunchHelper.launchInTestMode()
        let home = HomeScreen(app: app)

        XCTAssertTrue(home.countLabel.waitForExistence(timeout: 10), "Home did not appear")
        snapshot(app, named: "Tour-01-Home")

        let detail = home.openDetails()
        XCTAssertTrue(detail.list.waitForExistence(timeout: 5), "Details did not open")
        snapshot(app, named: "Tour-02-Details")
    }
}

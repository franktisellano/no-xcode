import XCTest

/// Launches the app in its DEBUG-only test mode (seeded data, stubbed services).
@MainActor
enum LaunchHelper {
    static func launchInTestMode(_ extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["APP_TEST_MODE"] = "1"
        app.launchEnvironment.merge(extraEnvironment) { _, new in new }
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Captures the screen as a kept attachment named `name`. `make screenshots` / `make tour`
    /// export these to build/screenshots/<name>.png.
    @MainActor
    func snapshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIApplication {
    /// The first hittable button with `identifier`. SwiftUI can keep off-screen copies of a
    /// view (navigation stacks, sheets), so `buttons[id]` may resolve to an invisible one.
    func visibleButton(_ identifier: String) -> XCUIElement {
        let matches = buttons.matching(identifier: identifier)
        return matches.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? matches.firstMatch
    }
}

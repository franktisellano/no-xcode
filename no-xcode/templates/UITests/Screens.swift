import XCTest

/// Page objects: typed accessors and actions keyed off the `.accessibilityIdentifier`s in the
/// SwiftUI views. Keep every identifier string here so tests read like user flows.

@MainActor
struct HomeScreen {
    let app: XCUIApplication

    var countLabel: XCUIElement { app.staticTexts["count-label"] }
    var incrementButton: XCUIElement { app.visibleButton("increment-button") }
    var resetButton: XCUIElement { app.visibleButton("reset-button") }
    var detailsLink: XCUIElement { app.visibleButton("details-link") }

    var count: String { countLabel.label }

    @discardableResult
    func openDetails() -> DetailScreen {
        XCTAssertTrue(detailsLink.waitForExistence(timeout: 5), "Details link not found")
        detailsLink.tap()
        return DetailScreen(app: app)
    }
}

@MainActor
struct DetailScreen {
    let app: XCUIApplication

    var list: XCUIElement { app.collectionViews["detail-list"] }
    var backButton: XCUIElement { app.navigationBars.buttons.element(boundBy: 0) }
}

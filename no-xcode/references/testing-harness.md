# Simulator test harness

The goal: an agent can make a change, run the app, *see* the result and assert behavior with
no device, accounts, network or human. Three layers: test mode, page-object UI tests, and
screenshots exported as plain PNGs.

## 1. Test mode (DEBUG-only)

`App/TestMode.swift` reads `APP_TEST_MODE=1` once at launch. In test mode the app should:

- **Seed deterministic data in memory.** Build the store synchronously before the first frame
  so screenshots never catch an empty state. SwiftData example:

  ```swift
  static func makeSeededContainer() -> ModelContainer {
      let schema = Schema([Project.self, TodoItem.self])
      // In-memory configs must disable CloudKit or the init throws.
      let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
      let container = try! ModelContainer(for: schema, configurations: [config])
      let context = ModelContext(container)   // not mainContext, so callable off the main actor
      seed(into: context)
      try? context.save()
      return container
  }
  ```

  Seed for coverage: include an empty collection (zero state), an item missing an optional
  field, long names that stress layout.
- **Bypass gates that block automation:** auth, onboarding, paywalls, permission pre-prompts,
  services that don't work in the simulator (Apple Music, App Shortcuts, push).
- **Stub external services behind small protocols** chosen at launch:

  ```swift
  protocol WeatherProviding { func forecast() async throws -> Forecast }
  let weather: WeatherProviding = TestMode.isActive ? StubWeather() : LiveWeather()
  ```

- **Accept extra knobs** as more env vars (`APP_TEST_SCENARIO=empty`, `APP_TEST_ACCENT=#FF9500`)
  so UI tests can launch specific states without tapping through the app.

Wrap all of it in `#if DEBUG`. For apps with dev-only API keys, a CI step that greps the
Release `Info.plist` for those keys is a cheap backstop (see device-and-release.md).

Passing env vars:
- `make run`: `SIMCTL_CHILD_APP_TEST_MODE=1 xcrun simctl launch ...` (simctl strips the
  `SIMCTL_CHILD_` prefix and hands the var to the app).
- XCUITest: `app.launchEnvironment["APP_TEST_MODE"] = "1"` (in `LaunchHelper`).
- Launch arguments work too: `xcrun simctl launch <udid> <bundle> -myFlag value`, readable via
  `UserDefaults.standard.string(forKey: "myFlag")`. Handy for DEBUG-only hooks like
  `-runIntent foo` that exercise code paths the simulator can't trigger (App Intents).

## 2. Page objects and identifiers

- Every control a test touches gets `.accessibilityIdentifier("kebab-case")` **on the tappable
  element itself**. An identifier on a container collapses into its single interactive child or
  gets lost; put it on the `Button`, not the `HStack` around it.
- Dynamic rows: `"todo-row-\(item.title)"`. Stable, readable, unique.
- `UITests/Screens.swift` holds one struct per screen with typed accessors and navigation
  methods that return the next screen. Tests then read like flows:
  `ProjectsScreen(app:).openProject("Launch").openTodo("Write copy").markDone()`.
- Use `app.visibleButton(id)` (in `LaunchHelper.swift`) when SwiftUI keeps an off-screen copy
  of a view alive (navigation stacks, sheets) and `buttons[id]` hits the hidden one.
- Always `waitForExistence(timeout:)` before interacting after navigation; never `sleep`.
- Mark XCUITest methods and helpers `@MainActor` (Swift 6).

## 3. Screenshots an agent can read

- `make screenshot`: `xcrun simctl io <udid> screenshot build/screenshot.png`. Instant, whatever
  is on screen now. Read the PNG.
- `snapshot(app, named: "Tour-03-Settings")` inside a UI test attaches a named screenshot.
  `tools/export-screenshots.sh` pulls all attachments out of the `.xcresult` (via
  `xcrun xcresulttool export attachments`) into `build/screenshots/<name>.png`.
- **Screenshot tour** (`ScreenshotTourTests`): one test that walks every screen, sheet and
  zero state in a fixed order, `Tour-NN-Name`. After any UI change: `make tour`, read the
  PNGs. When you add a screen, add it to the tour.
- **Accessibility sizes:** a separate test class that launches with a larger content size and
  snapshots key screens as `AX-*`:

  ```swift
  app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
  ```

  Or change the booted simulator: `xcrun simctl ui <udid> content_size accessibility-large`.
- **Dark mode:** `make APPEARANCE=dark run` or `xcrun simctl ui <udid> appearance dark`.
- **Clean status bar** for marketing shots:
  `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4`
  (`clear` to undo).
- Screenshots are large (about 1200×2600). Read them one at a time and only the ones you need.

Add a make target per useful subset (`make screenshots-ax`, `make tour`) rather than
remembering `-only-testing:` incantations.

## 4. Fixtures that must never ship

Put personal or licensed test assets (songs, photos, documents) in a gitignored folder outside
any target (e.g. `TestSupport/Fixtures/`), and copy them into the installed app's sandbox:

```sh
CONTAINER=$(xcrun simctl get_app_container <udid> <bundle-id> data)
mkdir -p "$CONTAINER/Documents/Fixtures" && cp TestSupport/Fixtures/* "$CONTAINER/Documents/Fixtures/"
```

In test mode, read from there and fall back to synthetic data when it's empty, so CI stays hermetic.
Photos: `xcrun simctl addmedia <udid> photo.jpg`.

## 5. Other simctl tools

| Need | Command |
| --- | --- |
| Pre-grant permissions (no alert) | `xcrun simctl privacy <udid> grant photos\|camera\|microphone\|location\|contacts\|calendar <bundle-id>` |
| Deep link / universal link | `xcrun simctl openurl <udid> "myapp://route?x=1"` |
| Push notification | `xcrun simctl push <udid> <bundle-id> payload.apns` (JSON with an `aps` key) |
| Location | `xcrun simctl location <udid> set 37.3349,-122.0090` |
| App's sandbox path | `xcrun simctl get_app_container <udid> <bundle-id> data` |
| Read UserDefaults | `plutil -p "$(xcrun simctl get_app_container <udid> <bundle-id> data)/Library/Preferences/<bundle-id>.plist"` |
| Logs | `make logs-sim`, or `xcrun simctl launch --console-pty <udid> <bundle-id>` for stdout |
| Record video | `xcrun simctl io <udid> recordVideo build/run.mov` (Ctrl-C to stop) |
| Reset everything | `xcrun simctl erase <udid>` (shutdown first) |
| Uninstall | `xcrun simctl uninstall <udid> <bundle-id>` |

## 6. What the simulator can't do

Verify these on a device (`make device-run`, `make device-logs`): Apple Music / MusicKit
playback of library items, App Shortcuts / Siri execution (the simulator refuses ad-hoc-signed
apps), real push delivery, CloudKit sharing between accounts (possible with two signed-in
simulators, but slow and flaky), camera capture, haptics, background task scheduling cadence.
Keep a short device QA checklist in the repo for these.

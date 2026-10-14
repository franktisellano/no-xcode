# Gotchas (check here first when something fails strangely)

## Project generation

- **Edits to the `.xcodeproj` vanish.** Expected: it's regenerated on every `make`. Put the
  change in `project.yml`.
- **New file not compiled.** It's outside every target's `sources:` path, or was created
  before the last gen. Run `make gen`. Files in a folder listed in `sources` are picked up
  automatically.
- **Hand-edited Info.plist keys disappear.** XcodeGen rewrites the plist from
  `info.properties`. Move the keys there.
- **Simulator name collisions.** "iPhone 17 Pro" can exist on several runtimes, and the regex
  "iPhone 17 Pro" also matches "iPhone 17 Pro Max". Resolve to a UDID (`tools/sim-udid.sh`) and
  build with `-destination 'platform=iOS Simulator,id=<udid>'`; pass `OS=` to pin a runtime.
  Raw `name=` destinations are ambiguous.
- **GNU Make paren trouble.** A literal `(` inside `$(shell ...)` breaks Make's parser. Move
  complex shell logic into a `tools/*.sh` script instead of escaping it inline.

## Building and signing

- **`codesign` fails with "resource fork, Finder information, or similar detritus not allowed".**
  The project or DerivedData is in an iCloud-synced folder (Desktop/Documents), and
  file-provider extended attributes got into the bundle. Run `xattr -cr <source dirs>` and keep
  `-derivedDataPath` out of synced folders (e.g. `~/Library/Developer/Xcode/DerivedData/<App>`).
- **"No Account for Team" / "No profiles for 'com.x' were found".** xcodebuild has no
  provisioning credentials. Sign in once in Xcode → Settings → Accounts, or create `.asc.env`
  with an API key (the Makefile passes it automatically). Check that `DEVELOPMENT_TEAM` is a team
  you belong to (`tools/find-team.sh`).
- **Simulator builds don't need a team; unit/UI tests use `CODE_SIGNING_ALLOWED=NO`.** But apps
  using entitlement-gated APIs (CloudKit, App Groups, keychain sharing) need a *signed*
  simulator build outside test mode. `CKContainer(identifier:)` traps in an unsigned build.
  `make build`/`make run` sign ad hoc ("Sign to Run Locally"), which embeds entitlements.
- **SourceKit / editor says "cannot find type X in scope"** across files: indexing lag. Trust
  `xcodebuild`.
- **Build output floods context.** Always go through `tools/xcb.sh` (or pipe through
  `grep -E "error:|BUILD (SUCCEEDED|FAILED)"`); the full log is `build/xcodebuild.log`.
  Don't let a pipe swallow the exit status: check `${PIPESTATUS[0]}` or test for the `.app`.
- **Swift 6 strict concurrency errors in tests.** XCUITest APIs are `@MainActor`; annotate
  test methods and helpers with `@MainActor`.

## Devices

- **Device "not found" though paired.** Different Wi-Fi network, a VPN (Bonjour doesn't cross
  it), or the phone is asleep. Plug in by cable to confirm.
- **`DeviceLocked` on install/launch.** Unlock the phone and rerun. Launch can fail even after
  a successful install; the app is installed, so open it by hand.
- **Developer Mode missing from Settings.** It appears only after the phone has been connected
  to a Mac with Xcode once.
- **Pushing to the wrong phone.** Several paired devices (a partner's, a test phone). The
  scripts refuse to guess; always pass `DEVICE_NAME`, and don't target someone else's device
  unless asked.

## Testing

- **UI test can't find an element that's visibly on screen.** The identifier is on a container
  rather than the tappable element, or SwiftUI kept an off-screen duplicate (use
  `app.visibleButton`). Debug with `print(app.debugDescription)` in the test and read the
  accessibility tree in `build/xcodebuild.log`.
- **Test passes locally, fails in CI on timing.** Replace any `sleep` with
  `waitForExistence(timeout:)`; give the first launch 10s+.
- **`xcodebuild test` env vars don't reach the app.** Scheme `environmentVariables` go to the
  test runner; use `app.launchEnvironment` in XCUITest and `SIMCTL_CHILD_*` with simctl.
- **Unit tests show "Executed 0 tests".** That's XCTest's counter; Swift Testing reports its
  own `Test run with N tests` line. Both appear in `tools/xcb.sh` output.
- **Screenshot shows the previous state.** Animations hadn't settled. `make screenshot` waits
  `SETTLE` seconds (default 1); in UI tests wait for the destination element before
  `snapshot`.
- **Things the simulator can't do:** App Shortcuts/Siri execution, Apple Music library
  playback, real push, camera. See testing-harness.md §6; test those on device.

## Release

- **Upload rejected: build number already used.** Build numbers must increase per marketing
  version; the timestamp scheme handles it. Don't pass a lower `BUILD=`.
- **Extension version mismatch warning/rejection.** Extension `CFBundleShortVersionString` /
  `CFBundleVersion` must match the app's. Reference the shared build settings.
- **TestFlight build can't see CloudKit data that dev builds can.** Deploy the CloudKit schema
  to Production.
- **Missing privacy string crash/rejection.** Every protected API (camera, mic, location,
  photos, music, contacts) needs its `NS…UsageDescription` in `info.properties`.
- **xcconfig value truncated at `//`.** It's a comment marker; write `https:/$()/host`.

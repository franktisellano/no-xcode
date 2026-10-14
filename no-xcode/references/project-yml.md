# project.yml recipes (XcodeGen)

Full spec: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md

After any edit: `make gen` (or any make target that depends on it). If a setting doesn't take
effect, inspect what Xcode actually sees:

```sh
xcodebuild -project App.xcodeproj -scheme App -showBuildSettings | grep -E "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM"
```

## Info.plist: generate it from project.yml

Declare keys under `info.properties`; XcodeGen writes the plist at `info.path` on every gen.
Don't hand-edit that plist, since your edits get overwritten.

```yaml
info:
  path: App/Info.plist
  properties:
    CFBundleDisplayName: My App
    CFBundleShortVersionString: $(MARKETING_VERSION)
    CFBundleVersion: $(CURRENT_PROJECT_VERSION)
    UILaunchScreen: {}
    ITSAppUsesNonExemptEncryption: false          # skips the export-compliance prompt on upload
    NSCameraUsageDescription: Scans receipts.     # every privacy-sensitive API needs its string
    NSLocationWhenInUseUsageDescription: Shows the nearest station.
    UIBackgroundModes: [audio, fetch, remote-notification]
    BGTaskSchedulerPermittedIdentifiers: [com.example.app.refresh]
    LSApplicationQueriesSchemes: [someotherapp]   # needed for canOpenURL on another app's scheme
    NSSupportsLiveActivities: true
    UIAppFonts: [Archivo-Bold.ttf]
```

## Entitlements

```yaml
entitlements:
  path: App/App.entitlements
  properties:
    aps-environment: development
    com.apple.developer.icloud-container-identifiers: [iCloud.com.example.app]
    com.apple.developer.icloud-services: [CloudKit]
    com.apple.security.application-groups: [group.com.example.app]
    com.apple.developer.usernotifications.time-sensitive: true
```

With automatic signing plus `-allowProvisioningUpdates`, xcodebuild registers the capabilities
and regenerates the profile on the next device build. No developer-portal clicking.

## Secrets via xcconfig

```yaml
targets:
  App:
    configFiles:
      Debug: Config/Debug.xcconfig
      Release: Config/Release.xcconfig
    info:
      properties:
        API_KEY: $(API_KEY)          # surfaces the build setting in Info.plist
```

`Config/Debug.xcconfig` does `#include? "../Secrets.xcconfig"` (gitignored, optional include).
`Config/Release.xcconfig` blanks dev-only keys (`DEV_API_KEY =`) so they can't ship, and a
release gate script asserts it (see device-and-release.md). Read in Swift with
`Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String`.
In xcconfig `//` starts a comment, so write URLs as `https:/$()/host`.

## App extensions (widgets, Live Activities, share extensions)

Share code between targets with a folder both compile:

```yaml
targets:
  App:
    sources: [App, Shared]
    dependencies:
      - target: AppWidgets          # embeds the extension
  AppWidgets:
    type: app-extension
    platform: iOS
    sources: [AppWidgets, Shared]
    info:
      path: AppWidgets/Info.plist
      properties:
        CFBundleDisplayName: My App
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
          # share extension: com.apple.share-services + NSExtensionPrincipalClass / NSExtensionAttributes
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.app.widgets   # must be prefixed by the app's id
        SKIP_INSTALL: YES
```

The extension's version strings must match the app's or upload validation fails, so
reference the same `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` from the project-level
settings. Data between app and extension needs an App Group entitlement on both.

## Swift packages

```yaml
packages:
  Algorithms:
    url: https://github.com/apple/swift-algorithms
    from: 1.2.0
  LocalThing:
    path: Vendor/LocalThing          # vendored local package
targets:
  App:
    dependencies:
      - package: Algorithms
      - package: LocalThing
        product: CLocalThing         # when the product name differs
```

Resolve without a GUI: `xcodebuild -resolvePackageDependencies -project App.xcodeproj -scheme App`.

## Schemes with environment variables

A target's `scheme:` block generates its default scheme. Extra schemes go under top-level `schemes:`.

```yaml
targets:
  App:
    scheme:
      testTargets: [AppTests, AppUITests]
      gatherCoverageData: false
      environmentVariables:
        APP_TEST_MODE: "1"            # optional: makes the default scheme's Run match `make run`
schemes:
  App (Real Data):
    build: { targets: { App: all } }
    run: { config: Debug }
    archive: { config: Release }
```

Command-line launches don't use scheme env vars; `simctl launch` takes `SIMCTL_CHILD_<VAR>`
and XCUITest takes `app.launchEnvironment`. If you set it on the scheme, `xcodebuild test` passes it
to the *test runner*, not the app.

## App icons

- **Asset catalog:** `App/Assets.xcassets/AppIcon.appiconset` with a single 1024×1024 universal
  PNG; set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.
- **Icon Composer (`.icon` bundle, iOS 26+ Liquid Glass icons):** a folder with `icon.json` +
  `Assets/*.svg|png`. Include it as a file resource rather than a source group:

  ```yaml
  sources:
    - path: App
      excludes: ["AppIcon.icon/**"]
    - path: App/AppIcon.icon
      type: file
      buildPhase: resources
  settings:
    base:
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
  ```

  You can author `icon.json` by hand. In it, the first-listed layer/group draws on top.
  Preview without Xcode:
  `mkdir -p build/icon && xcrun actool --compile build/icon --app-icon AppIcon --platform iphoneos --minimum-deployment-target 18.0 App/AppIcon.icon`
  then Read `build/icon/AppIcon60x60@2x.png`.

## Custom document types / UTIs

```yaml
info:
  properties:
    UTExportedTypeDeclarations:
      - UTTypeIdentifier: com.example.app.doc
        UTTypeDescription: My Document
        UTTypeConformsTo: [public.data]
        UTTypeTagSpecification:
          public.filename-extension: [mydoc]
    CFBundleDocumentTypes:
      - CFBundleTypeName: My Document
        CFBundleTypeRole: Editor
        LSHandlerRank: Owner
        LSItemContentTypes: [com.example.app.doc]
    LSSupportsOpeningDocumentsInPlace: true
```

## Converting an existing hand-made project

1. `xcodebuild -list -project Old.xcodeproj` for targets and schemes.
2. For each target: `xcodebuild -project Old.xcodeproj -target T -showBuildSettings` and keep
   only the non-default settings that matter (bundle id, team, deployment target, Swift
   version, Info.plist path, entitlements, `OTHER_*` flags).
3. Copy Info.plist keys into `info.properties` and entitlements into `entitlements.properties`.
4. Packages: read `Old.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
5. Write `project.yml`, then `make gen && make build`. Compare `-showBuildSettings` output if
   behavior differs. When it builds and runs, `git rm -r --cached Old.xcodeproj` and gitignore it.
6. Projects using Xcode 16 "synchronized folders" already pick up files automatically, but
   still have a hand-edited pbxproj; converting removes the merge-conflict surface.

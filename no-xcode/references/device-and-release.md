# Physical devices, signing and TestFlight, all from the terminal

## One-time setup

1. **Team ID.** `tools/find-team.sh` lists the team IDs of valid "Apple Development"
   certificates in the keychain. Put the one you want in `project.yml` →
   `settings.base.DEVELOPMENT_TEAM` and in `ExportOptions.plist` → `teamID`.
   No certificate yet? Either sign in to Xcode → Settings → Accounts **once** (the only GUI step;
   xcodebuild then mints certificates itself) or use an App Store Connect API key (below).
2. **Provisioning credentials for xcodebuild.** `-allowProvisioningUpdates` lets xcodebuild
   create certificates, App IDs, capabilities and profiles. It authenticates with either:
   - the Apple ID signed in to Xcode's Accounts (simplest for personal machines), or
   - an App Store Connect API key passed as `-authenticationKeyID/-IssuerID/-Path`. The
     Makefile adds these automatically when `.asc.env` exists. Required for CI.
3. **Pair the phone.** Connect by cable once, unlock, tap *Trust*. Enable
   Settings → Privacy & Security → **Developer Mode** (the phone reboots). After that it can
   install over Wi-Fi when both are on the same network. `make devices` should list it.
4. **Name it.** Device targets resolve the phone by its name (`DEVICE_NAME="Jane's iPhone"`).
   With exactly one paired iPhone the name can be omitted; with several, the scripts refuse
   rather than guess. Put your default in your shell profile (`export DEVICE_NAME=...`) rather
   than in the shared Makefile.

## Daily device loop

```sh
make device-run      # gen → signed Debug build → install → launch
make device-logs     # relaunch with stdout/stderr attached (print + os_log)
```

`-allowProvisioningDeviceRegistration` registers a new phone's UDID with the team on the
first build. A brand-new device or capability can take one extra build to settle.

Under the hood:

```sh
xcodebuild -project App.xcodeproj -scheme App -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device <id> build/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device <id> com.example.app
```

Other `devicectl` tools: `xcrun devicectl device info apps --device <id>`,
`xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier <bundle-id> --source Documents --destination ./pulled`
(pull the app's files), `xcrun devicectl device uninstall app --device <id> <bundle-id>`.

## TestFlight

One-time:

1. App Store Connect → Apps → **+** New App with the exact bundle id. (Can't be done via
   xcodebuild. An agent with the App Store Connect API can create it, otherwise it's a
   two-minute web form.)
2. App Store Connect → Users and Access → Integrations → **Team Keys** → generate a key with
   **App Manager** role. Download the `.p8` (only downloadable once) to e.g.
   `~/.appstoreconnect/private_keys/`. Fill in `.asc.env` from `.asc.env.example`.
3. Internal testing group in TestFlight → add testers.

Each release:

```sh
# bump MARKETING_VERSION in project.yml when the user-visible version changes
make archive          # optional: Release archive only, prints the signing identity
make testflight       # timestamp build number → archive → (release gate) → export + upload
```

How it works (`tools/testflight-upload.sh`):
- `CURRENT_PROJECT_VERSION` in `project.yml` is rewritten to a UTC timestamp
  (`YYYYMMDDHHMM`), so build numbers are unique and increasing without bookkeeping. Commit the
  change after a successful upload, or don't. It just has to increase.
- `xcodebuild archive` and `xcodebuild -exportArchive` with `ExportOptions.plist`
  (`method: app-store-connect`, `destination: upload`) upload directly; no Transporter or
  altool. With the API key, the Apple Distribution certificate and App Store profile are
  created on the first run.
- `ITSAppUsesNonExemptEncryption: false` in Info.plist answers export compliance for apps
  that only use standard HTTPS.

### Release gate

If `tools/release-gate.sh` exists and is executable, the upload script runs it with the
archived `.app` path before uploading. Use it to block shipping mistakes:

```bash
#!/bin/bash
# Fail if dev-only secrets made it into the Release bundle.
set -euo pipefail
PLIST="$1/Info.plist"
KEY=$(/usr/libexec/PlistBuddy -c 'Print :DEV_API_KEY' "$PLIST" 2>/dev/null || true)
[ -z "$KEY" ] || { echo "error: DEV_API_KEY is set in the Release bundle" >&2; exit 1; }
echo "release gate ok"
```

### CloudKit apps

TestFlight and App Store builds use the **Production** CloudKit environment. Before the first
TestFlight build (and after any schema change), deploy the schema: CloudKit Console →
container → *Deploy Schema Changes*. Dev builds work fine before that, which makes the bug
confusing when it shows up. SwiftData + CloudKit models need default values or optionals for
every property, optional relationships, and no `@Attribute(.unique)`.

## CI (GitHub Actions)

`.github/workflows/ci.yml` (from the scaffold) installs XcodeGen and runs `make test` and
`make screenshots`, uploading `build/screenshots` and the `.xcresult` as artifacts so you can
see UI regressions from the PR page. Pin `SIM=` to a device that exists on the runner image.
Unit and UI tests run with `CODE_SIGNING_ALLOWED=NO`, so CI needs no certificates. Add the
release gate as a CI step to catch secrets leaking into Release builds early.

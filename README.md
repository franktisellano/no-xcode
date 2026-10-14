# no-xcode

An agent skill for building iOS apps **without ever opening Xcode**. Your coding agent (Google
Antigravity, Claude Code, ChatGPT/Codex, or anything else that can run a shell) creates the project, builds it,
runs it on the simulator or your iPhone, writes and runs tests, **takes screenshots and looks at
them**, and uploads to TestFlight, all from the terminal.

It's the setup behind several shipped personal apps, extracted into a reusable skill:

- **[XcodeGen](https://github.com/yonaskolb/XcodeGen) `project.yml`** is the source of truth. The
  `.xcodeproj` is generated and gitignored, so there are no pbxproj merge conflicts and agents
  never edit Xcode's file format.
- **One Makefile** for the whole loop: `make run`, `make test`, `make screenshot`, `make tour`,
  `make device-run`, `make testflight`.
- **A DEBUG-only test mode** (`APP_TEST_MODE=1`) that boots the app with seeded in-memory data and
  stubbed services, so it runs deterministically on the simulator with no accounts or network.
- **XCUITest page objects + a screenshot tour** exported as plain PNGs to `build/screenshots/`,
  which the agent reads to check its own UI work.
- **Quiet builds.** `tools/xcb.sh` keeps the full xcodebuild log on disk and prints only errors,
  test failures and the result, so the agent's context isn't filled with build noise.
- **Device + TestFlight without the GUI:** automatic signing with `-allowProvisioningUpdates`,
  `devicectl` install/launch/logs, App Store Connect API-key uploads with timestamp build numbers.

```
$ make run && make screenshot
** BUILD SUCCEEDED **
Launched MyApp in test mode on iPhone 17 Pro (6F1C2E0A-…)
Wrote build/screenshot.png
```

## Install

Clone once, then link the skill folder into your agent's skills directory. Using a symlink means
`git pull` updates every agent at once.

```sh
git clone https://github.com/franktisellano/no-xcode.git ~/no-xcode
```

Each agent picks the skill up automatically when you work on an iOS app ("make me an iPhone
app that…", "run it on my phone", "upload to TestFlight").

### Google Antigravity

```sh
# Antigravity IDE
mkdir -p ~/.gemini/config/skills
ln -s ~/no-xcode/no-xcode ~/.gemini/config/skills/no-xcode

# Antigravity CLI (agy)
mkdir -p ~/.gemini/antigravity-cli/skills
ln -s ~/no-xcode/no-xcode ~/.gemini/antigravity-cli/skills/no-xcode
```

To check it loaded in the IDE, open **Customizations** in the agent side panel. For a single
project, put the folder in that project's `.agents/skills/` instead.
([Antigravity skills docs](https://antigravity.google/docs/skills))

### Claude Code

```sh
mkdir -p ~/.claude/skills
ln -s ~/no-xcode/no-xcode ~/.claude/skills/no-xcode
```

For a single project, use that project's `.claude/skills/` instead.

### ChatGPT (Codex app, CLI and IDE extension)

```sh
mkdir -p ~/.agents/skills
ln -s ~/no-xcode/no-xcode ~/.agents/skills/no-xcode
```

For a single project, use that project's `.agents/skills/` (also read by Antigravity). Restart
Codex if the skill doesn't appear. ([Codex skills docs](https://learn.chatgpt.com/docs/build-skills))

### Anything else

The skill is plain Markdown plus shell scripts. Tell your agent:

> Read `~/no-xcode/no-xcode/SKILL.md` and follow it for this iOS project.

Every scaffolded project also gets an `AGENTS.md` describing its own build loop, which many
agents read automatically.

## Requirements

- macOS with Xcode installed (used only from the command line) and an iOS simulator runtime
- `brew install xcodegen`
- For physical devices / TestFlight: an Apple Developer account. Sign in to Xcode's Accounts
  once, or use an App Store Connect API key.

## Quick start (by hand)

```sh
~/no-xcode/no-xcode/scripts/scaffold.sh ~/dev/myapp --name MyApp --bundle-id com.example.myapp --display "My App"
cd ~/dev/myapp
make test         # unit tests (Swift Testing)
make run          # simulator, test mode
make screenshot   # build/screenshot.png
make tour         # build/screenshots/Tour-*.png
make device-run DEVICE_NAME="My iPhone"
```

## What's inside

```
no-xcode/
  SKILL.md                     the instructions the agent follows
  scripts/scaffold.sh          new project from templates
  templates/                   Makefile, project.yml, tools/, SwiftUI app, unit + UI tests, CI, AGENTS.md
  references/
    project-yml.md             XcodeGen recipes: widgets, packages, entitlements, secrets, icons
    testing-harness.md         test mode, page objects, screenshot tours, simctl tricks
    device-and-release.md      pairing, signing without the GUI, TestFlight, CI
    gotchas.md                 failure modes and fixes
```

## License

MIT

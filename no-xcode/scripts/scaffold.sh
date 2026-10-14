#!/bin/bash
# Create a new terminal-driven iOS app from the no-xcode templates.
#
# Usage: scaffold.sh <dir> --name MyApp --bundle-id com.example.myapp
#                    [--team ABCDE12345] [--display "My App"] [--no-git]
#
# --name      Swift identifier used for the target, scheme, module and folder names.
# --team      Apple Developer team ID (DEVELOPMENT_TEAM). Defaults to the only valid
#             signing team in the keychain; otherwise left as __TEAM_ID__ for you to fill in.
# --display   Home-screen name. Defaults to --name.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
T="$SKILL_DIR/templates"

DIR="" NAME="" BUNDLE="" TEAM="" DISPLAY="" GIT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --bundle-id) BUNDLE="$2"; shift 2 ;;
    --team) TEAM="$2"; shift 2 ;;
    --display) DISPLAY="$2"; shift 2 ;;
    --no-git) GIT=0; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) DIR="$1"; shift ;;
  esac
done

[ -n "$DIR" ] && [ -n "$NAME" ] && [ -n "$BUNDLE" ] || { sed -n '2,12p' "$0"; exit 2; }
[[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo "--name must be a Swift identifier (letters, digits, _)" >&2; exit 2; }
[[ "$BUNDLE" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo "--bundle-id must look like com.example.app" >&2; exit 2; }
[ -e "$DIR/project.yml" ] && { echo "$DIR already has a project.yml; not overwriting" >&2; exit 1; }
DISPLAY="${DISPLAY:-$NAME}"

if [ -z "$TEAM" ]; then
  if TEAM=$("$T/tools/find-team.sh" --only 2>/dev/null); then
    echo "==> Using signing team $TEAM (only valid Apple Development certificate found)"
  else
    TEAM="__TEAM_ID__"
    echo "==> No single signing team found; DEVELOPMENT_TEAM left as __TEAM_ID__ in project.yml"
    echo "    and ExportOptions.plist. Simulator builds work without it. Teams available:"
    "$T/tools/find-team.sh" 2>/dev/null | sed 's/^/      /' || echo "      (none)"
  fi
fi

mkdir -p "$DIR"
cd "$DIR"

cp -R "$T/App" "$NAME"
cp -R "$T/Tests" "${NAME}Tests"
cp -R "$T/UITests" "${NAME}UITests"
cp -R "$T/tools" "$T/Config" .
cp "$T/Makefile" "$T/project.yml" "$T/ExportOptions.plist" "$T/Secrets.example.xcconfig" \
   "$T/AGENTS.md" "$T/CLAUDE.md" .
cp "$T/gitignore" .gitignore
cp "$T/asc.env.example" .asc.env.example
mkdir -p .github/workflows && cp "$T/github/ci.yml" .github/workflows/ci.yml
mv "$NAME/App.swift" "$NAME/${NAME}App.swift"
chmod +x tools/*.sh

# Substitute placeholders (perl reads values from the environment, so no escaping issues).
export APP="$NAME" BUNDLE_ID="$BUNDLE" TEAM_ID="$TEAM" DISPLAY_NAME="$DISPLAY"
grep -rlE "__(APP|BUNDLE_ID|TEAM_ID|DISPLAY_NAME)__" . --exclude-dir=.git | while read -r f; do
  perl -pi -e 's/__APP__/$ENV{APP}/g; s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g;
                s/__DISPLAY_NAME__/$ENV{DISPLAY_NAME}/g;
                s/__TEAM_ID__/$ENV{TEAM_ID}/g unless $ENV{TEAM_ID} eq "__TEAM_ID__"' "$f"
done

if [ "$GIT" = 1 ] && [ ! -d .git ]; then
  git init -q && git add -A && git commit -qm "Scaffold $NAME (no-xcode)" && echo "==> git repo initialized"
fi

command -v xcodegen >/dev/null || echo "!! xcodegen not found: brew install xcodegen"
cat <<MSG
==> Created $NAME in $(pwd)
    make test         unit tests
    make run          build + launch on the simulator (test mode)
    make screenshot   → build/screenshot.png
    make tour         → build/screenshots/Tour-*.png
MSG

#!/bin/bash
# Export all XCUITest screenshot attachments from an .xcresult into a flat folder
# with their human-readable names, so the agent can read them directly.
# Usage: export-screenshots.sh <result.xcresult> <output-dir>
set -euo pipefail

RESULT="${1:?usage: export-screenshots.sh <xcresult> <output-dir>}"
OUT="${2:?usage: export-screenshots.sh <xcresult> <output-dir>}"

rm -rf "$OUT"
mkdir -p "$OUT"
RAW="$OUT/.raw"
mkdir -p "$RAW"

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$RAW" >/dev/null

python3 - "$RAW" "$OUT" <<'PY'
import json, os, sys, shutil, re
raw, out = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(raw, "manifest.json")))
count = 0
for test in manifest:
    for a in test.get("attachments", []):
        src = a.get("exportedFileName")
        name = a.get("suggestedHumanReadableName") or src
        if not src or not name.lower().endswith(".png"):
            # keep only PNG screenshots
            if not (src and src.lower().endswith(".png")):
                continue
        # Strip the XCUITest "_0_<uuid>" suffix for a clean filename.
        clean = re.sub(r"_\d+_[0-9A-Fa-f-]+\.png$", ".png", name)
        if not clean.lower().endswith(".png"):
            clean += ".png"
        shutil.copy(os.path.join(raw, src), os.path.join(out, clean))
        count += 1
        print("  " + clean)
print(f"Exported {count} screenshot(s) to {out}")
PY

rm -rf "$RAW"

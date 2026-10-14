#!/bin/bash
# Print the UDID of an available iOS simulator.
# Usage: tools/sim-udid.sh ["iPhone 17 Pro"] [os-version, e.g. 26.0]
# Prefers an exact name match (booted first, then newest runtime). If the name doesn't
# exist on this machine, falls back to the newest available iPhone and says so on stderr.
set -euo pipefail
NAME="${1:-iPhone 17 Pro}"
OS="${2:-}"
JSON=$(mktemp -t sims)
trap 'rm -f "$JSON"' EXIT
xcrun simctl list devices available -j >"$JSON"
/usr/bin/python3 - "$JSON" "$NAME" "$OS" <<'PY'
import json, re, sys
path, name, want_os = sys.argv[1], sys.argv[2], sys.argv[3]
want = tuple(int(x) for x in want_os.split(".")) if want_os else None
pool = []
for runtime, devs in json.load(open(path))["devices"].items():
    m = re.search(r"\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    if not m:
        continue
    ver = tuple(int(x or 0) for x in m.groups())
    if want and ver[:len(want)] != want:
        continue
    pool += [(d["state"] == "Booted", ver, d) for d in devs]
if not pool:
    suffix = f" for iOS {want_os}" if want_os else ""
    sys.exit(f"sim-udid: no available iOS simulators{suffix}. Install a runtime: xcodebuild -downloadPlatform iOS")
exact = [p for p in pool if p[2]["name"] == name]
if exact:
    pick = max(exact, key=lambda p: (p[0], p[1]))
else:
    phones = [p for p in pool if p[2]["name"].startswith("iPhone")] or pool
    pick = max(phones, key=lambda p: (p[0], p[1]))
    version = ".".join(map(str, pick[1]))
    print(f'sim-udid: no simulator named "{name}"; using "{pick[2]["name"]}" (iOS {version})', file=sys.stderr)
print(pick[2]["udid"])
PY

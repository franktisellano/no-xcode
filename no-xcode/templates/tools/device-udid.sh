#!/bin/bash
# Print the CoreDevice identifier of a paired iPhone/iPad.
# Usage: tools/device-udid.sh ["Device Name"]
# With a name: that device. Without: the only paired iOS device, and refuses (listing them)
# if there are several, so a build never lands on someone else's phone by accident.
set -euo pipefail
NAME="${1:-}"
JSON=$(mktemp -t devices)
trap 'rm -f "$JSON"' EXIT
xcrun devicectl list devices --json-output "$JSON" -q >/dev/null 2>&1 || true
/usr/bin/python3 - "$JSON" "$NAME" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    devices = json.load(open(path))["result"]["devices"]
except Exception:
    sys.exit("device-udid: could not list devices (is Xcode installed?)")
ios = [d for d in devices
       if d.get("hardwareProperties", {}).get("platform") == "iOS"
       and d.get("connectionProperties", {}).get("pairingState") == "paired"]
label = lambda d: f'  {d["deviceProperties"].get("name")!r}  ({d["hardwareProperties"].get("marketingName") or d["hardwareProperties"].get("deviceType")}, {d["connectionProperties"].get("tunnelState")})'
if name:
    match = [d for d in ios if d["deviceProperties"].get("name") == name]
    if not match:
        sys.exit(f"device-udid: no paired device named {name!r}. Paired devices:\n" + ("\n".join(map(label, ios)) or "  (none)"))
    print(match[0]["identifier"])
elif len(ios) == 1:
    print(ios[0]["identifier"])
elif not ios:
    sys.exit("device-udid: no paired iOS device. Connect the phone by cable once, tap Trust, and enable Developer Mode.")
else:
    sys.exit("device-udid: several paired devices; pick one with DEVICE_NAME=\"...\":\n" + "\n".join(map(label, ios)))
PY

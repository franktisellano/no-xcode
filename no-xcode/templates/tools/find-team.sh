#!/bin/bash
# List the Apple Developer team IDs you have signing certificates for (DEVELOPMENT_TEAM).
# Usage: tools/find-team.sh          prints "TEAMID  Team name  (expires ...)" per valid cert
#        tools/find-team.sh --only   prints the team ID if exactly one is valid, else fails
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
security find-certificate -a -c "Apple Development" -p 2>/dev/null \
  | awk -v d="$TMP" '/BEGIN CERT/{n++} {print > (d "/" n ".pem")}'
for f in "$TMP"/*.pem; do
  [ -s "$f" ] || continue
  openssl x509 -in "$f" -noout -checkend 0 >/dev/null 2>&1 || continue   # skip expired
  subj=$(openssl x509 -in "$f" -noout -subject -nameopt multiline)
  ou=$(awk -F' = ' '/organizationalUnitName/{print $2}' <<<"$subj")
  o=$(awk -F' = ' '/organizationName/{print $2}' <<<"$subj")
  end=$(openssl x509 -in "$f" -noout -enddate | cut -d= -f2)
  echo "$ou  $o  (expires $end)"
done | sort -u -k1,1 >"$TMP/teams"
if [ "${1:-}" = "--only" ]; then
  [ "$(wc -l <"$TMP/teams")" -eq 1 ] || exit 1
  cut -d' ' -f1 "$TMP/teams"
else
  if [ -s "$TMP/teams" ]; then cat "$TMP/teams"
  else echo "No valid 'Apple Development' certificates in the keychain. See references/device-and-release.md."; exit 1; fi
fi

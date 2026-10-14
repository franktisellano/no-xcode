#!/bin/bash
# Run xcodebuild with the full log in build/xcodebuild.log and print only what matters:
# errors, signing/provisioning warnings, test failures, test totals and the result line.
# Exits with xcodebuild's status. Usage: tools/xcb.sh <xcodebuild args...>
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
LOG=build/xcodebuild.log

xcodebuild "$@" >"$LOG" 2>&1
status=$?

grep -E "error:|warning: .*(sign|provision|[Pp]rofile)|Signing Identity:|\*\* [A-Z ]+ (SUCCEEDED|FAILED) \*\*|Test Case .* failed|Executed [0-9]+ tests?|^✘|Test run with [0-9]+ tests?|Failing tests:|^\s+-\[|Testing failed:" "$LOG" \
  | grep -v "Executed 0 tests" | awk '!seen[$0]++' | head -n 80

if [ $status -ne 0 ] && ! grep -qE "error:|failed" "$LOG"; then
  echo "--- xcodebuild exited $status; last 30 lines of $LOG:"
  tail -n 30 "$LOG"
fi
exit $status

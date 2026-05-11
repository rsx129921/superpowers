#!/usr/bin/env bash
# Tier 1 unit test for platform-detect.sh
#
# platform-detect.sh emits the string "cc" on stdout when running on
# Claude Code, "non-cc" otherwise. Exit code is always 0 (fail-open
# semantics — detection failure must never block hook execution).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/platform-detect.sh"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — expected '$expected' got '$actual'"
        fail=$((fail + 1))
    fi
}

echo "test-platform-detect.sh"

# Use full bash path so env -i (which strips PATH) can still find the interpreter
BASH_BIN="$(command -v bash)"

# Case 1: CC environment (CLAUDE_PLUGIN_ROOT set, COPILOT_CLI unset)
actual=$(env -i CLAUDE_PLUGIN_ROOT=/some/path "$BASH_BIN" "$LIB")
assert_eq "cc detected" "cc" "$actual"

# Case 2: Copilot CLI (both vars set)
actual=$(env -i CLAUDE_PLUGIN_ROOT=/some/path COPILOT_CLI=1 "$BASH_BIN" "$LIB")
assert_eq "copilot cli detected as non-cc" "non-cc" "$actual"

# Case 3: Cursor (CURSOR_PLUGIN_ROOT set)
actual=$(env -i CURSOR_PLUGIN_ROOT=/some/path "$BASH_BIN" "$LIB")
assert_eq "cursor detected as non-cc" "non-cc" "$actual"

# Case 4: Nothing set (e.g. invoked outside a harness)
actual=$(env -i "$BASH_BIN" "$LIB")
assert_eq "no harness detected as non-cc" "non-cc" "$actual"

# Case 5: Exit code is 0 in all cases (fail-open)
set +e
env -i "$BASH_BIN" "$LIB" >/dev/null 2>&1
rc=$?
set -e
assert_eq "exit code is 0" "0" "$rc"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

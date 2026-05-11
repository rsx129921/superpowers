#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-session-start
#
# Contract:
#   - Non-CC platforms: exit 0, no stdout
#   - CC platform: emits CC-format JSON additionalContext with MCP availability list +
#     memory-aware skill directive
#
# This file is filled in by M2 Tasks 3 (this contract section) and 5 (CC behavior).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/cc-session-start"
BASH_BIN="$(command -v bash)"

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

echo "test-cc-session-start.sh"

set +e
actual=$(env -i "$BASH_BIN" "$HOOK" </dev/null 2>&1)
rc=$?
set -e
assert_eq "non-CC: no stdout" "" "$actual"
assert_eq "non-CC: exit 0" "0" "$rc"

# CC contract — real assertions added in Task 5.

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

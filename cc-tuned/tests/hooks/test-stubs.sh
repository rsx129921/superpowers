#!/usr/bin/env bash
# Tier 1 unit test for the three M1 stub hooks.
#
# Each stub must:
#   - exit 0 always (fail-open)
#   - emit nothing to stdout on non-CC platforms
#   - tolerate being invoked with no stdin (some hook events get stdin,
#     others don't — stubs must not block waiting for it)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="${SCRIPT_DIR}/../../hooks"
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

echo "test-stubs.sh"

for stub in cc-session-start cc-user-prompt-submit cc-pre-compact; do
    # Non-CC: no output, exit 0
    set +e
    actual=$(env -i "$BASH_BIN" "$HOOKS/$stub" </dev/null 2>&1)
    rc=$?
    set -e
    assert_eq "$stub: non-CC produces no stdout" "" "$actual"
    assert_eq "$stub: non-CC exits 0" "0" "$rc"

    # CC: stub exits 0, emits nothing (M1 stubs don't emit context yet; M2 will)
    set +e
    actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" "$HOOKS/$stub" </dev/null 2>&1)
    rc=$?
    set -e
    assert_eq "$stub: CC stub exits 0" "0" "$rc"
    assert_eq "$stub: CC stub emits nothing" "" "$actual"
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

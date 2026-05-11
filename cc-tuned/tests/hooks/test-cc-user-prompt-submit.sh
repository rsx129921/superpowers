#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-user-prompt-submit
#
# Contract:
#   - Non-CC platforms: drains stdin, exits 0, no stdout
#   - CC platform: reads {"prompt": "..."} from stdin, keyword-matches,
#     emits PLAIN TEXT on stdout with skill suggestion (or nothing on no-match)
#
# NOTE: Per M2 Task 1 research, this hook emits plain text (not JSON envelope).
# UserPromptSubmit + hookSpecificOutput JSON triggers a spurious first-session
# error banner per bug #17550. Plain text avoids the bug.
#
# This file is filled in by M2 Tasks 3 (this contract section) and 6 (CC behavior).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/cc-user-prompt-submit"
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

echo "test-cc-user-prompt-submit.sh"

# Non-CC contract: even with a prompt on stdin, output nothing
set +e
actual=$(env -i "$BASH_BIN" "$HOOK" <<< '{"prompt": "let'\''s build something"}' 2>&1)
rc=$?
set -e
assert_eq "non-CC: no stdout even with prompt input" "" "$actual"
assert_eq "non-CC: exit 0" "0" "$rc"

# CC contract — real assertions added in Task 6.

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

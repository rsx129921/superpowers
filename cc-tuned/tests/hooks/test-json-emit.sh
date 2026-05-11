#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/lib/json-emit.sh
#
# json-emit.sh exposes two bash functions when sourced:
#   escape_for_json <string>            → prints JSON-safe string body on stdout
#   emit_cc_hook_context <event> <text> → prints CC-format JSON envelope

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/json-emit.sh"
BASH_BIN="$(command -v bash)"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $(printf %s "$expected" | head -c 120)"
        echo "    actual:   $(printf %s "$actual" | head -c 120)"
        fail=$((fail + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   $needle"
        echo "    haystack: $(printf %s "$haystack" | head -c 200)"
        fail=$((fail + 1))
    fi
}

echo "test-json-emit.sh"

# escape_for_json — run in subshell that sources the lib
escape_in_subshell() {
    "$BASH_BIN" -c "source '$LIB'; escape_for_json \"\$1\"" _ "$1"
}

actual=$(escape_in_subshell 'plain text')
assert_eq "plain text passes through" 'plain text' "$actual"

actual=$(escape_in_subshell 'has "quotes"')
assert_eq 'double quotes escaped' 'has \"quotes\"' "$actual"

actual=$(escape_in_subshell 'back\slash')
assert_eq 'backslash escaped' 'back\\slash' "$actual"

actual=$(escape_in_subshell $'line one\nline two')
assert_eq 'newline becomes \n' 'line one\nline two' "$actual"

actual=$(escape_in_subshell $'with\ttab')
assert_eq 'tab becomes \t' 'with\ttab' "$actual"

# emit_cc_hook_context — JSON envelope shape
emit_in_subshell() {
    "$BASH_BIN" -c "source '$LIB'; emit_cc_hook_context \"\$1\" \"\$2\"" _ "$1" "$2"
}

actual=$(emit_in_subshell SessionStart 'hello world')
assert_contains "envelope contains hookSpecificOutput" "hookSpecificOutput" "$actual"
assert_contains "envelope contains hookEventName" '"hookEventName": "SessionStart"' "$actual"
assert_contains "envelope contains additionalContext" '"additionalContext"' "$actual"
assert_contains "envelope contains payload text" 'hello world' "$actual"

# JSON validity
if command -v python3 >/dev/null 2>&1; then
    set +e
    printf '%s' "$actual" | python3 -m json.tool >/dev/null 2>&1
    rc=$?
    set -e
    assert_eq "emitted JSON is valid" "0" "$rc"
fi

# Quotes in payload are escaped inside envelope
actual=$(emit_in_subshell UserPromptSubmit 'with "quotes" inside')
assert_contains "payload quotes escaped in envelope" '\"quotes\"' "$actual"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

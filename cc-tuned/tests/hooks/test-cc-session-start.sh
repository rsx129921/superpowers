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

# CC contract: emits CC-format JSON with MCP availability + memory-aware directive

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture 1: User settings has two memory-related MCPs
mkdir -p "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
cat > "$TMPDIR/home/.claude/settings.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}, "cognee-memory": {"command": "y"}}}
EOF
echo '{}' > "$TMPDIR/proj/.claude/settings.json"

set +e
actual=$(env -i PATH="/usr/bin:/bin" CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
assert_eq "CC (fixture 1): exit 0" "0" "$rc"

if printf '%s' "$actual" | grep -qF '"hookEventName": "SessionStart"'; then
    echo "  pass: CC (fixture 1): hookEventName SessionStart"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): missing SessionStart in envelope"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'episodic-memory'; then
    echo "  pass: CC (fixture 1): payload lists episodic-memory"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing episodic-memory"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'cognee-memory'; then
    echo "  pass: CC (fixture 1): payload lists cognee-memory"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing cognee-memory"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'memory-aware'; then
    echo "  pass: CC (fixture 1): payload mentions memory-aware directive"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing memory-aware directive"
    fail=$((fail + 1))
fi

# Fixture 2: No MCPs configured
rm -rf "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
mkdir -p "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
echo '{}' > "$TMPDIR/home/.claude/settings.json"
echo '{}' > "$TMPDIR/proj/.claude/settings.json"

set +e
actual=$(env -i PATH="/usr/bin:/bin" CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
assert_eq "CC (fixture 2 empty MCPs): exit 0" "0" "$rc"

if printf '%s' "$actual" | grep -qE '\(none|none detected'; then
    echo "  pass: CC (fixture 2): empty MCP list rendered as '(none detected)'"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 2): empty MCP list not handled"
    fail=$((fail + 1))
fi

# JSON validity (re-run a fixture)
cat > "$TMPDIR/home/.claude/settings.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}}}
EOF
set +e
actual=$(env -i PATH="/usr/bin:/bin" CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
if command -v python3 >/dev/null 2>&1; then
    set +e
    printf '%s' "$actual" | python3 -m json.tool >/dev/null 2>&1
    rc_json=$?
    set -e
    assert_eq "CC: emitted JSON is valid" "0" "$rc_json"
fi

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

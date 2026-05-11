#!/usr/bin/env bash
# Tier 1 unit test for mcp-introspect.sh
#
# mcp-introspect.sh accepts two args: paths to user-level and
# project-level settings.json files. It reads the `mcpServers` object
# from each, deduplicates, and emits sorted MCP names one per line.
# On any error, emits nothing and exits 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/mcp-introspect.sh"
BASH_BIN="$(command -v bash)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        fail=$((fail + 1))
    fi
}

echo "test-mcp-introspect.sh"

# Case 1: User settings has MCPs, project settings empty
cat > "$TMPDIR/user.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}, "cognee-memory": {"command": "y"}}}
EOF
echo '{}' > "$TMPDIR/project.json"
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory"
assert_eq "user-only MCPs detected, sorted" "$expected" "$actual"

# Cases 2-3 inherit user.json fixture from Case 1 (cognee-memory + episodic-memory)
# Case 2: Project settings adds a third MCP
cat > "$TMPDIR/project.json" <<'EOF'
{"mcpServers": {"obsidian": {"command": "z"}}}
EOF
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory
obsidian"
assert_eq "merged + sorted across both files" "$expected" "$actual"

# Case 3: Duplicate name across files — deduplicated
cat > "$TMPDIR/project.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "different"}}}
EOF
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory"
assert_eq "duplicate names deduplicated" "$expected" "$actual"

# Case 4: Missing files — emit nothing, exit 0
set +e
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/does-not-exist.json" "$TMPDIR/also-missing.json" 2>/dev/null)
rc=$?
set -e
assert_eq "missing files produce no output" "" "$actual"
assert_eq "missing files exit 0" "0" "$rc"

# Case 5: Malformed JSON — emit nothing, exit 0 (fail-open)
echo 'not valid json {{' > "$TMPDIR/bad.json"
set +e
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/bad.json" "$TMPDIR/bad.json" 2>/dev/null)
rc=$?
set -e
assert_eq "malformed JSON produces no output" "" "$actual"
assert_eq "malformed JSON exits 0" "0" "$rc"

# Case 6: settings.json without mcpServers key
echo '{"other": "stuff"}' > "$TMPDIR/no-mcp.json"
actual=$("$BASH_BIN" "$LIB" "$TMPDIR/no-mcp.json" "$TMPDIR/no-mcp.json")
assert_eq "settings without mcpServers emits nothing" "" "$actual"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

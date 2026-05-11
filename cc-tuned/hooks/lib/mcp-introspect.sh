#!/usr/bin/env bash
# mcp-introspect.sh USER_SETTINGS PROJECT_SETTINGS
#
# Reads the `mcpServers` object keys from each settings.json file,
# deduplicates, and emits sorted MCP names one per line on stdout.
# On any error (file missing, malformed JSON, jq absent), emits
# nothing and exits 0. Fail-open: detection failure must never block
# hook execution.
#
# Defaults if args omitted:
#   USER_SETTINGS    = $HOME/.claude/settings.json
#   PROJECT_SETTINGS = ./.claude/settings.json

set -u

USER_SETTINGS="${1:-$HOME/.claude/settings.json}"
PROJECT_SETTINGS="${2:-.claude/settings.json}"

extract_keys() {
    local file="$1"
    [ -f "$file" ] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r '.mcpServers // {} | keys[]?' "$file" 2>/dev/null || true
    else
        python3 - "$file" 2>/dev/null <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as fh:
        d = json.load(fh)
    for k in (d.get("mcpServers") or {}):
        print(k)
except Exception:
    pass
PYEOF
    fi
}

{
    extract_keys "$USER_SETTINGS"
    extract_keys "$PROJECT_SETTINGS"
} | tr -d '\r' | sort -u

exit 0

#!/usr/bin/env bash
# Tier 2 validator for cc-tuned/agents/*.md
#
# Contract:
#   - Each agent .md file has a YAML frontmatter block (--- delimited)
#   - Required frontmatter fields: name, description, tools, model
#   - The body (everything after the closing ---) is non-empty
#   - Banned frontmatter fields (silently ignored by CC for plugin subagents,
#     but their presence indicates author confusion): hooks, mcpServers,
#     permissionMode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../../agents"

fail=0
pass=0

echo "test-agent-frontmatter.sh"

if [ ! -d "$AGENTS_DIR" ]; then
    echo "  FAIL: agents directory not found at $AGENTS_DIR"
    exit 1
fi

shopt -s nullglob
agent_files=("$AGENTS_DIR"/*.md)
shopt -u nullglob

if [ "${#agent_files[@]}" -eq 0 ]; then
    echo "  FAIL: no agent files found in $AGENTS_DIR"
    exit 1
fi

for agent_file in "${agent_files[@]}"; do
    agent_name=$(basename "$agent_file" .md)

    # Check frontmatter delimiters
    if ! head -1 "$agent_file" | grep -qF -- '---'; then
        echo "  FAIL: $agent_name — missing opening frontmatter delimiter"
        fail=$((fail + 1))
        continue
    fi

    # Find the closing delimiter (line number)
    close_line=$(awk '/^---$/ { count++; if (count == 2) { print NR; exit } }' "$agent_file")
    if [ -z "$close_line" ]; then
        echo "  FAIL: $agent_name — missing closing frontmatter delimiter"
        fail=$((fail + 1))
        continue
    fi

    frontmatter=$(sed -n "2,$((close_line - 1))p" "$agent_file")
    body=$(tail -n +$((close_line + 1)) "$agent_file")

    # Required fields
    for field in name description tools model; do
        if ! printf '%s\n' "$frontmatter" | grep -qE "^${field}:"; then
            echo "  FAIL: $agent_name — missing required field: $field"
            fail=$((fail + 1))
            continue 2
        fi
    done

    # Banned fields (CC ignores them on plugin subagents; their presence is
    # an author-confusion signal)
    for field in hooks mcpServers permissionMode; do
        if printf '%s\n' "$frontmatter" | grep -qE "^${field}:"; then
            echo "  FAIL: $agent_name — banned field present: $field (silently ignored on plugin subagents; remove it)"
            fail=$((fail + 1))
            continue 2
        fi
    done

    # Name field matches filename
    name_value=$(printf '%s\n' "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
    if [ "$name_value" != "$agent_name" ]; then
        echo "  FAIL: $agent_name — name field ('$name_value') does not match filename"
        fail=$((fail + 1))
        continue
    fi

    # Body non-empty (>= 3 non-blank lines as a sanity check)
    body_lines=$(printf '%s\n' "$body" | grep -cE '^\S' || true)
    if [ "$body_lines" -lt 3 ]; then
        echo "  FAIL: $agent_name — body has fewer than 3 non-blank lines"
        fail=$((fail + 1))
        continue
    fi

    echo "  pass: $agent_name — frontmatter valid + body non-empty"
    pass=$((pass + 1))
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# platform-detect.sh
#
# Single source of truth for "are we running on Claude Code?" check.
# Emits "cc" on stdout if CC, "non-cc" otherwise. Always exits 0
# (fail-open). Sourced or invoked by every cc-tuned hook before any
# CC-specific work.
#
# Detection rules (slightly stricter than upstream hooks/session-start):
#   - CC: CLAUDE_PLUGIN_ROOT set, COPILOT_CLI unset, AND CURSOR_PLUGIN_ROOT unset
#   - Cursor: CURSOR_PLUGIN_ROOT set (Cursor may also set CLAUDE_PLUGIN_ROOT —
#     this branch deliberately treats that combination as non-CC so the
#     cc-tuned layer does not activate inside a Cursor session running the
#     superpowers plugin)
#   - Copilot CLI: COPILOT_CLI=1
#   - Codex / others / no harness: none of the above set
# Derived from but stricter than: hooks/session-start (which does not exclude
# CURSOR_PLUGIN_ROOT from the CC branch).

set -u

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ] && [ -z "${CURSOR_PLUGIN_ROOT:-}" ]; then
    echo "cc"
else
    echo "non-cc"
fi

exit 0

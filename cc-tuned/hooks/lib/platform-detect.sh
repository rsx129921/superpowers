#!/usr/bin/env bash
# platform-detect.sh
#
# Single source of truth for "are we running on Claude Code?" check.
# Emits "cc" on stdout if CC, "non-cc" otherwise. Always exits 0
# (fail-open). Sourced or invoked by every cc-tuned hook before any
# CC-specific work.
#
# Detection rules:
#   - CC sets CLAUDE_PLUGIN_ROOT (and does NOT set COPILOT_CLI)
#   - Cursor sets CURSOR_PLUGIN_ROOT
#   - Copilot CLI sets COPILOT_CLI=1
#   - Codex / others: none of the above set
# Source: existing hooks/session-start script's platform detection logic.

set -u

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ] && [ -z "${CURSOR_PLUGIN_ROOT:-}" ]; then
    echo "cc"
else
    echo "non-cc"
fi

exit 0

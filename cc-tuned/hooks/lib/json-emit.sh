#!/usr/bin/env bash
# json-emit.sh — JSON output helpers for cc-tuned hooks.
#
# Two functions exported on source:
#   escape_for_json <string>             → echoes JSON-safe string body
#   emit_cc_hook_context <event> <text>  → prints CC's hookSpecificOutput envelope
#
# Uses printf-based emission to avoid the bash 5.3+ heredoc hang documented
# in upstream hooks/session-start (see github.com/obra/superpowers/issues/571).
#
# Pure bash. No external commands required. Fail-open: sourcing this lib
# never aborts the caller, and emit functions write to stdout only.

set -u

# Escape a string for embedding inside a JSON string literal.
# Uses bash parameter substitution exclusively — fast, no external commands.
# Handles: backslash, double quote, newline, carriage return, tab.
escape_for_json() {
    local s="${1-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Emit a CC-format hook output envelope to stdout.
#   $1 = hookEventName (SessionStart | UserPromptSubmit | PreCompact)
#   $2 = additionalContext payload (raw text; this function escapes it)
emit_cc_hook_context() {
    local event="${1-}"
    local payload="${2-}"
    local escaped
    escaped=$(escape_for_json "$payload")
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "%s",\n    "additionalContext": "%s"\n  }\n}\n' \
        "$event" "$escaped"
}

# CC Hook JSON Output Contracts: Decision Record

**Date:** 2026-05-11
**Decision (per event):** See table below
**Authority:** Official Claude Code Hooks reference — https://code.claude.com/docs/en/hooks (verified live 2026-05-11)
**Supporting schema reference:** https://gist.github.com/FrancisBourre/50dca37124ecc43eaf08328cdcccdb34 (unofficial; corroborates official docs)

---

## Findings

### SessionStart

- **Format:**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": "<text>"
    }
  }
  ```
- **Context injection point:** Before the first prompt, at the start of the conversation.
- **Confirmed via:** Upstream `hooks/session-start` (working in production). The hook uses `printf` instead of a heredoc due to a bash 5.3+ heredoc hang (see: https://github.com/obra/superpowers/issues/571).
- **Consumption quirk:** Plain stdout is *also* consumed as context for SessionStart without JSON wrapping, but the upstream hook uses the JSON envelope to be explicit and platform-selective.

### UserPromptSubmit

- **Format:**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": "<text>",
      "sessionTitle": "<optional: sets session title>"
    }
  }
  ```
  Or, to block the prompt:
  ```json
  {
    "decision": "block",
    "reason": "<shown to user>",
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": "<text>"
    }
  }
  ```
- **Context injection point:** Alongside the submitted prompt (the model sees it as a system reminder next to the user's message).
- **Confirmed via:** Official hooks reference docs (https://code.claude.com/docs/en/hooks) listing `additionalContext` and `sessionTitle` as the supported `hookSpecificOutput` fields for this event.
- **Known bug (issue #17550):** On the **first message of a new session**, `hookSpecificOutput` JSON from a UserPromptSubmit hook triggers a spurious "UserPromptSubmit hook error" UI message, even though the hook exits 0 and the JSON is valid. The hook executes correctly; only the first-session display is broken. Subsequent messages work without issue.
  - **Workaround:** Output plain text to stdout instead of JSON. Per official docs, plain text stdout is also added as context for UserPromptSubmit. However, plain text does not support `decision: "block"` or `sessionTitle`.
  - **Impact on cc-user-prompt-submit (Task 5):** The M2 design for `cc-user-prompt-submit` uses keyword detection to decide whether to inject context. If we use JSON `hookSpecificOutput`, users will see an error banner on session start. **Recommendation: emit plain text stdout for the context-injection path; reserve JSON only if blocking is needed.** Document this in Task 5 implementation notes.

### PreCompact

- **Format:** PreCompact does **NOT** support `additionalContext` or `hookSpecificOutput`. The official schema defines only common output fields for this event:
  ```json
  {
    "continue": true,
    "stopReason": "<optional>",
    "suppressOutput": false
  }
  ```
  To block compaction:
  ```json
  {
    "decision": "block",
    "reason": "<shown to user>"
  }
  ```
- **Context injection point:** None. PreCompact cannot inject text into Claude's context. It can only allow or block compaction.
- **Confirmed via:** Official hooks reference docs listing no `hookSpecificOutput` fields for PreCompact; gist schema reference explicitly states "Uses only common output fields; no event-specific schema."
- **Impact on cc-pre-compact (Task 6):** The M2 design spec's assumption that PreCompact "uses the same envelope as SessionStart with the event name swapped" is **incorrect**. PreCompact cannot deliver a `additionalContext` payload. The hook's purpose must be limited to compaction control (allow/block) only. Any context injection that was planned for PreCompact must be moved to a different event (e.g., PostCompact, which does support `additionalContext`, or a SessionStart hook that fires on resume).

---

## Decision for each cc-tuned hook

| Hook | JSON envelope used | Notes |
|------|---------------------|-------|
| `cc-session-start` | `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<text>"}}` | Confirmed working in upstream production |
| `cc-user-prompt-submit` | Plain text stdout (not JSON) for context injection; JSON `{"decision": "block", "reason": "..."}` only if blocking is needed | JSON `hookSpecificOutput` causes spurious error on first session message (bug #17550) |
| `cc-pre-compact` | `{"decision": "block", "reason": "..."}` to block; empty/exit 0 to allow. **No `additionalContext` support.** | PreCompact cannot inject context; design spec assumption was incorrect |

---

## Open ambiguities

1. **PostCompact as alternative context-injection point for PreCompact's intended work:**
   If Task 6 needs to inject context (e.g., a "bootstrap preservation" reminder after compaction), PostCompact is the correct event — it fires after compaction and does support `additionalContext`. This is a design question for the Task 6 implementer, not a research blocker.

2. **UserPromptSubmit plain-text vs. JSON tradeoff:**
   The M2 design spec (§2.2) describes keyword-matching injection logic. If the only output path is plain text stdout, `sessionTitle` cannot be set and `decision: "block"` requires switching to JSON (which triggers the first-session bug). If blocking is not part of the M2 scope for this hook, plain text is strictly better. The Task 5 implementer should confirm whether blocking is in scope before choosing the output format.

3. **Bug #17550 fix timeline unknown:**
   The UserPromptSubmit first-session JSON error is a known upstream Claude Code bug with no confirmed fix date as of 2026-05-11. The plain-text workaround is stable and sufficient for M2's context-injection goal.

---

## Implications for Tasks 4–6

- **Task 4 (cc-session-start):** Use the canonical `hookSpecificOutput` envelope exactly as upstream `hooks/session-start` does. Use `printf` (not heredoc) to avoid the bash 5.3+ hang. No surprises.

- **Task 5 (cc-user-prompt-submit):** Output plain text stdout for context injection. Do NOT use `hookSpecificOutput` JSON for the normal (non-blocking) path — it will cause a spurious error banner on every session's first message. If blocking capability is needed, document the tradeoff.

- **Task 6 (cc-pre-compact):** PreCompact cannot inject `additionalContext`. The hook can only allow or block compaction. If the M2 spec intended context injection here, redirect that capability to PostCompact or fold it into the SessionStart hook (which fires on resume/clear as well as startup). The M2 milestone goal of "bootstrap preservation" likely maps better to PostCompact than PreCompact.

- **Task 2 (json-emit lib):** The centralized JSON-emit library must handle at least two distinct shapes: the `hookSpecificOutput` envelope (SessionStart, UserPromptSubmit) and the bare `decision` envelope (PreCompact, blocking paths). It should NOT attempt to emit a `hookSpecificOutput` wrapper for PreCompact.

---

## Evidence log

| Source | URL | Accessed |
|--------|-----|----------|
| Official CC hooks reference | https://code.claude.com/docs/en/hooks | 2026-05-11 |
| Official CC plugins reference | https://code.claude.com/docs/en/plugins-reference | 2026-05-11 |
| Unofficial hook schema gist | https://gist.github.com/FrancisBourre/50dca37124ecc43eaf08328cdcccdb34 | 2026-05-11 |
| UserPromptSubmit first-session bug | https://github.com/anthropics/claude-code/issues/17550 | 2026-05-11 |
| Upstream hooks/session-start | C:/dev/superpowers/hooks/session-start | 2026-05-11 (local) |

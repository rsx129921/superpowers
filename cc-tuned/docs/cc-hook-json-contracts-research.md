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

### PreCompact / PostCompact

- **PreCompact format:** `{"decision": "block", "reason": "..."}` to block compaction; exit 0 to allow. No `hookSpecificOutput` or `additionalContext` support.
- **PostCompact format:** Universal fields only (`continue`, `stopReason`, `suppressOutput`, `systemMessage`). Per official Claude Code hooks reference, PostCompact does NOT support `additionalContext` or `hookSpecificOutput`. GitHub feature requests #32026 and #40492 (for context injection on PostCompact) were closed as duplicates with no fix planned.
- **Implication:** Neither PreCompact nor PostCompact can inject `additionalContext`. The design spec's "preserve bootstrap across compaction" goal cannot be achieved via these events directly.
- **Workaround that DOES work:** Claude Code re-runs SessionStart hooks after compaction (per the upstream `startup|clear|compact` matcher in `hooks/hooks.json`). The existing cc-session-start hook with that same matcher already fires post-compaction, so its MCP-availability + memory-aware-directive injection covers the bootstrap-preservation goal implicitly. No separate compaction hook is needed in M2.

---

## Decision for each cc-tuned hook

| Hook | JSON envelope used | Notes |
|------|---------------------|-------|
| `cc-session-start` | `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<text>"}}` | Confirmed working in upstream production |
| `cc-user-prompt-submit` | Plain text stdout (not JSON) for context injection; JSON `{"decision": "block", "reason": "..."}` only if blocking is needed | JSON `hookSpecificOutput` causes spurious error on first session message (bug #17550) |
| `cc-pre-compact` | **DROP. No envelope works for context injection. Compaction-preservation is already covered by cc-session-start's `startup\|clear\|compact` matcher.** | No separate compaction hook needed in M2 |

---

## Open ambiguities

1. **UserPromptSubmit plain-text vs. JSON tradeoff:**
   The M2 design spec (§2.2) describes keyword-matching injection logic. If the only output path is plain text stdout, `sessionTitle` cannot be set and `decision: "block"` requires switching to JSON (which triggers the first-session bug). If blocking is not part of the M2 scope for this hook, plain text is strictly better. The Task 5 implementer should confirm whether blocking is in scope before choosing the output format.

3. **Bug #17550 fix timeline unknown:**
   The UserPromptSubmit first-session JSON error is a known upstream Claude Code bug with no confirmed fix date as of 2026-05-11. The plain-text workaround is stable and sufficient for M2's context-injection goal.

---

## Implications for M2 tasks

- **Task 4 (was: cc-pre-compact body):** Drop cc-pre-compact entirely. Delete the M1 stub at `cc-tuned/hooks/cc-pre-compact`, remove the PreCompact entry from `hooks/hooks.json`, delete its test file. Compaction preservation goal is covered by cc-session-start's `startup|clear|compact` matcher (Task 5).
- **Task 5 (cc-session-start):** Unchanged — use `hookSpecificOutput.additionalContext` envelope. The same hook now covers both startup and compaction-recovery use cases.
- **Task 6 (cc-user-prompt-submit):** Emit **plain text stdout** instead of JSON envelope. Plain text is documented to inject context AND avoids bug #17550's first-session error banner.

---

## Evidence log

| Source | URL | Accessed |
|--------|-----|----------|
| Official CC hooks reference | https://code.claude.com/docs/en/hooks | 2026-05-11 |
| Official CC plugins reference | https://code.claude.com/docs/en/plugins-reference | 2026-05-11 |
| Unofficial hook schema gist | https://gist.github.com/FrancisBourre/50dca37124ecc43eaf08328cdcccdb34 | 2026-05-11 |
| UserPromptSubmit first-session bug | https://github.com/anthropics/claude-code/issues/17550 | 2026-05-11 |
| Upstream hooks/session-start | C:/dev/superpowers/hooks/session-start | 2026-05-11 (local) |

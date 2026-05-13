# cc-tuned Layer

This directory is the **Claude Code-specific layer** of the rsx129921/superpowers fork. It adds CC-aware hooks and (in M3) memory-aware skills on top of the upstream superpowers core, without editing any upstream skill prose.

## Status

| Milestone | Status | What ships |
|-----------|--------|------------|
| M1 Foundation | **complete** | scaffold + stub hooks (merged 2026-05-11) |
| M2 Hook Layer | **complete** | real hook logic — MCP injection, keyword match, cc-pre-compact dropped |
| M3 Memory-Aware Skills | **complete** | memory-aware-brainstorming / -debugging / -planning (merged after M2) |
| M4 Upstream Sync v1 | not started | first post-fork merge |
| M5 Polish & Docs | **in progress** | audit + maintenance procedure + arch narrative shipped; fork README + gitconfig aliases (optional) + upstream-merge playbook (blocked on M4) still open |
| M6 Dedicated Subagents | **in progress** | four cc-tuned-* subagents registered via plugin.json agents field |

See [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md) for the full design.

## Architecture

The cc-tuned layer composes four small units. Each has one responsibility and a well-defined input/output; together they let upstream skills behave better on Claude Code without editing any upstream prose.

### Layer 1 — Platform detection

**File:** `hooks/lib/platform-detect.sh`

Every cc-tuned hook calls this script first and exits 0 with no output when the answer is not `cc`. This is the single gate that makes the entire layer additive — the same checked-out fork works on Codex, Gemini, Cursor, OpenCode, and Copilot CLI without behavioral change, because every hook short-circuits before doing anything CC-specific.

**Input:** none (reads environment). **Output:** prints `cc` or the detected platform name on stdout.

### Layer 2 — Session bootstrap

**Files:** `hooks/cc-session-start` + `hooks/lib/mcp-introspect.sh`

Registered against the `startup|clear|compact` SessionStart matcher in `hooks/hooks.json`. On every session start (and after every compaction event, which re-fires SessionStart), this hook:

1. Reads the user's MCP configuration via `mcp-introspect.sh` (scans `~/.claude/settings.json` and any `.claude/settings.json` in the project).
2. Emits an `additionalContext` JSON envelope listing the available MCP server names.
3. Adds a directive instructing the model to prefer memory-aware skill variants (the M3 family) when memory MCPs are configured.

**Why re-fire on compact:** post-compaction the model loses prior session context but SessionStart hooks fire again, so the MCP list and memory-aware directive get re-injected. There is no separate `cc-pre-compact` hook — PreCompact and PostCompact events don't accept `additionalContext` per the bug research in `docs/cc-hook-json-contracts-research.md`.

**Input:** SessionStart hook event JSON. **Output:** `hookSpecificOutput.additionalContext` string injected into the conversation.

### Layer 3 — Per-prompt skill suggestion

**Files:** `hooks/cc-user-prompt-submit` + `hooks/lib/json-emit.sh`

Fires on every user message. Reads `{"prompt": "..."}` from stdin, lowercases the text, and tries a small keyword table — a first-match-wins bash `case` block plus one `grep -qE` regex fallback for patterns that can't be expressed as globs. On match, emits a plain-text suggestion ("This prompt matches the `<skill>` trigger pattern…") plus a condensed Red Flags list.

**Why plain text and not JSON:** UserPromptSubmit + `hookSpecificOutput` JSON triggers Anthropic bug #17550 (a spurious first-session error banner). The hook uses a `cat <<EOF` heredoc instead. `hooks/lib/json-emit.sh` is still present for any non-UserPromptSubmit event that needs the JSON envelope.

**Tuning:** the keyword table is intentionally conservative — false negatives are fine (upstream skill discovery backstops them), but false positives erode the signal value of the injection. See `docs/keyword-table-maintenance.md` for the add/remove/tighten procedure and `docs/audits/` for dated audits.

**Input:** UserPromptSubmit event JSON. **Output:** plain text on stdout (or empty on no-match).

### Layer 4 — Memory-aware skill wrappers

**Files:** `skills/memory-aware-brainstorming/`, `skills/memory-aware-debugging/`, `skills/memory-aware-planning/`

Three prose-only skill wrappers, registered under `cc-tuned/skills/` via the `"skills"` field in `.claude-plugin/plugin.json`. Each wraps one upstream skill (brainstorming / systematic-debugging / writing-plans) with two extra phases:

1. **RECALL** — query `episodic-memory` and/or `cognee-memory` MCPs for prior context relevant to the task.
2. **Invoke** the wrapped upstream skill normally.
3. **COMMIT-offer** — at the end, propose 1–3 durable facts to cognify and ask the user before committing. Memory writes are never automatic.

The Layer 2 directive is what causes Claude to prefer these wrappers over the bare upstream skills — without it, skill discovery defaults to the upstream name. The wrappers are inert when memory MCPs aren't configured (they simply skip the RECALL/COMMIT phases).

### Runtime flow

```
Fresh session              Each user prompt              Skill firing (MCPs up)
─────────────              ────────────────              ─────────────────────────
CC startup                 user types message            Skill check
  │                          │                             │
  ▼                          ▼                             ▼
cc-session-start runs      cc-user-prompt-submit         Layer 2 directive →
  │                        runs                          prefer memory-aware-*
  ▼                          │                             │
introspect MCPs              ▼                             ▼
  │                        keyword match?                RECALL (episodic+cognee)
  ▼                          │ yes                         │
inject MCP list +            ▼                             ▼
memory-aware directive     emit plain-text               invoke upstream skill
                           injection                       │
                                                           ▼
                                                         COMMIT-offer
```

Each layer is independently testable (`cc-tuned/tests/hooks/test-platform-detect.sh`, `test-cc-session-start.sh`, `test-cc-user-prompt-submit.sh`, `test-mcp-introspect.sh`, `tests/skills/test-skill-frontmatter.sh`). The Tier 3 manual smoke test below exercises the full runtime composition.

## Subagents

Four dedicated subagents at `cc-tuned/agents/` bake in the soft-strip invariant and four-layer architecture so subagent-driven cc-tuned PRs don't re-paste context into every dispatch.

| Subagent | Role | Default model |
|----------|------|---------------|
| `superpowers:cc-tuned-implementer` | TDD-disciplined implementer for cc-tuned plan tasks | `sonnet` |
| `superpowers:cc-tuned-spec-reviewer` | Spec-compliance review with soft-strip invariant check | `haiku` |
| `superpowers:cc-tuned-code-quality-reviewer` | Code-quality review against cc-tuned conventions | `sonnet` |
| `superpowers:cc-tuned-hook-tester` | Runs the test suite + diagnoses failures | `haiku` |

These replace `general-purpose` for cc-tuned PRs only. For ad-hoc work outside the cc-tuned layer, `general-purpose` remains the right choice. Registration is a single `"agents": "./cc-tuned/agents/"` entry in `.claude-plugin/plugin.json` — same additive pattern as M3's `skills` registration.

## What lives here

| Path | Purpose |
|------|---------|
| `hooks/run-hook.cmd` | Polyglot bat+bash dispatcher (mirrors upstream pattern) |
| `hooks/lib/platform-detect.sh` | "Are we on CC?" check, sole source of truth |
| `hooks/lib/mcp-introspect.sh` | Read MCP server names from settings.json files |
| `hooks/lib/json-emit.sh` | escape_for_json + CC hookSpecificOutput envelope helpers (M2) |
| `hooks/cc-session-start` | MCP availability + memory-aware directive injection (M2) |
| `hooks/cc-user-prompt-submit` | Keyword-match user prompt, inject discipline reminder (plain text, M2) |
| `skills/memory-aware-brainstorming/SKILL.md` | M3: RECALL + cognify-offer wrapper around superpowers:brainstorming |
| `skills/memory-aware-debugging/SKILL.md` | M3: RECALL + cognify-offer wrapper around superpowers:systematic-debugging |
| `skills/memory-aware-planning/SKILL.md` | M3: RECALL + cognify-offer wrapper around superpowers:writing-plans |
| `tests/skills/test-skill-frontmatter.sh` | Tier 2 validator: SKILL.md frontmatter + wrap-don't-replace structure |
| `agents/cc-tuned-implementer.md` | M6: TDD-disciplined implementer subagent (knows soft-strip + four layers) |
| `agents/cc-tuned-spec-reviewer.md` | M6: spec-compliance reviewer subagent |
| `agents/cc-tuned-code-quality-reviewer.md` | M6: code-quality reviewer subagent |
| `agents/cc-tuned-hook-tester.md` | M6: hook-test runner + failure-diagnostic subagent |
| `tests/agents/test-agent-frontmatter.sh` | Tier 2 validator: subagent .md frontmatter + tools list + no banned fields |
| `docs/cc-plugin-subagents-declaration-research.md` | Decision record on plugin.json agents field (M6) |
| `docs/cc-plugin-skills-declaration-research.md` | Decision record on plugin.json skills declaration (M3 Task 1) |
| `docs/keyword-table-maintenance.md` | Evergreen procedure for adding/removing/tightening hook keyword patterns (M5) |
| `docs/audits/2026-05-11-keyword-table.md` | Dated audit of the keyword table — findings + tuning rationale (M5) |
| `tests/run-all.sh` | Tier 1+2 test entry point |
| `docs/plugin-hooks-research.md` | Decision record on where hook events register (M1 Task 1) |
| `docs/cc-hook-json-contracts-research.md` | Decision record on per-event JSON contracts (M2 Task 1) |

## Soft-strip guarantees

This layer is designed to coexist with upstream pulls. Properties to maintain:

1. **No upstream skill files are edited.** Ever. Memory-aware skills (M3) *wrap* upstream skills via `Skill` invocation; they do not duplicate or modify upstream content.
2. **Two upstream JSON files have small additive edits.** `hooks/hooks.json` (M1, M2 — registers hooks) and `.claude-plugin/plugin.json` (M3 — declares the cc-tuned/skills/ subtree). Both are list-append-style edits that conflict rarely. The design spec §5 has the conflict-resolution playbook.
3. **All hooks no-op on non-CC harnesses.** The fork remains installable on Codex, Gemini, Cursor, OpenCode, Copilot CLI — the cc-tuned layer just silently disables itself there.
4. **All hooks fail open.** Exit 0 with empty output on any error. Hooks never block a user turn or session start.

## Running tests

```bash
bash cc-tuned/tests/run-all.sh
```

Expected output ends with `All test files passed.` on a clean run.

## Manual smoke test (Tier 3)

Run this in a fresh Claude Code session with the plugin loaded after every M2+ change to the hook bodies.

### Setup
- Open a clean CC session (no prior context).
- Confirm at least one memory MCP is configured (episodic-memory or cognee-memory in your `~/.claude/settings.json` `mcpServers`).

### Check 1: SessionStart MCP injection
Open a new conversation. In your first turn, ask Claude:
> "What MCPs do you currently have available? Just list the names."

Expected: Claude lists the MCPs you have configured. If it says it doesn't know, `cc-session-start` is not injecting context — check `~/.claude/logs/` for hook errors and re-run `bash cc-tuned/tests/hooks/test-cc-session-start.sh`.

### Check 2: UserPromptSubmit keyword trigger
Send the user message exactly:
> "let's build a small todo CLI"

Expected: Claude invokes `superpowers:brainstorming` *before* asking any clarifying questions. The brainstorming skill's intro should appear in Claude's response.

If Claude dives straight into implementation without invoking brainstorming, `cc-user-prompt-submit` either didn't fire, didn't match, or didn't inject the suggestion. Check `~/.claude/logs/`.

### Check 3: Compaction preservation (covered implicitly)
There is no separate cc-pre-compact hook in the cc-tuned layer (PreCompact and PostCompact events do not accept `additionalContext` per Anthropic's hook contract — see `cc-tuned/docs/cc-hook-json-contracts-research.md`). The bootstrap-preservation goal is covered implicitly by cc-session-start: CC re-fires SessionStart hooks after compaction, so the MCP-availability + memory-aware injection runs again on the post-compaction model.

To spot-check: have a long-running conversation, let compaction fire, then send a follow-up that should trigger a skill (e.g., "this test is failing"). Expected: systematic-debugging still triggers post-compaction.

### Check 4: memory-aware skill activation (M3)
Confirm at least one of `episodic-memory` or `cognee-memory` is configured. Open a fresh CC session and send:
> "let's build a small library for parsing config files"

Expected sequence:
1. cc-session-start injects available MCPs + the memory-aware directive.
2. cc-user-prompt-submit fires on "let's build" pattern.
3. Claude invokes `memory-aware-brainstorming` (NOT bare `brainstorming`) because the SessionStart directive said to prefer memory-aware variants when MCPs are up.
4. The first response includes a RECALL summary from episodic-memory + cognee-memory.

If Claude invokes plain `superpowers:brainstorming` instead, the SessionStart directive is being ignored — escalate.

### Check 5: subagent discovery (M6)

Open a fresh CC session with the plugin loaded. Run `/agents` (or use the agent picker in your CC harness). Confirm the typeahead lists these four:

- `superpowers:cc-tuned-implementer`
- `superpowers:cc-tuned-spec-reviewer`
- `superpowers:cc-tuned-code-quality-reviewer`
- `superpowers:cc-tuned-hook-tester`

If any are missing, verify `.claude-plugin/plugin.json` has `"agents": "./cc-tuned/agents/"` and that the four .md files exist under `cc-tuned/agents/` with valid frontmatter (`bash cc-tuned/tests/agents/test-agent-frontmatter.sh` should pass).

### Failure-mode quick reference

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| Claude doesn't know about your MCPs | cc-session-start not firing or not injecting | `~/.claude/logs/`; verify `bash cc-tuned/tests/hooks/test-cc-session-start.sh` still green |
| "let's build X" doesn't trigger brainstorming | cc-user-prompt-submit not matching or not injecting | `~/.claude/logs/`; verify test-cc-user-prompt-submit.sh green; check keyword table in the hook |
| First-session error banner | UserPromptSubmit hook emitting JSON instead of plain text (bug #17550) | Confirm `cat <<EOF` in cc-user-prompt-submit, not `emit_cc_hook_context` |
| Skills stop triggering after compaction | cc-session-start not re-firing on `compact` matcher | Verify `hooks/hooks.json` has the cc-session-start entry with `startup\|clear\|compact` matcher |
| Claude invokes plain brainstorming despite MCPs being available | SessionStart directive ignored, or memory-aware skill not discovered by CC | Verify `/plugin list` shows memory-aware-* skills; verify plugin.json has `"skills": "./cc-tuned/skills/"` |

## Rip-cord

If you ever want to abandon the cc-tuned layer entirely:

```bash
# 1. Delete the layer
git rm -r cc-tuned/

# 2. Revert the two JSON additive edits
git checkout <upstream-SHA> -- hooks/hooks.json .claude-plugin/plugin.json

# 3. Commit
git commit -m "revert: remove cc-tuned layer"
```

That's it. Soft-strip designed for low commitment.

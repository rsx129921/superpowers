# cc-tuned Layer

This directory is the **Claude Code-specific layer** of the rsx129921/superpowers fork. It adds CC-aware hooks and (in M3) memory-aware skills on top of the upstream superpowers core, without editing any upstream skill prose.

## Status

| Milestone | Status | What ships |
|-----------|--------|------------|
| M1 Foundation | **complete** | scaffold + stub hooks (merged 2026-05-11) |
| M2 Hook Layer | **complete** | real hook logic — MCP injection, keyword match, cc-pre-compact dropped |
| M3 Memory-Aware Skills | **complete** | memory-aware-brainstorming / -debugging / -planning (merged after M2) |
| M4 Upstream Sync v1 | not started | first post-fork merge |
| M5 Polish & Docs | not started | final README pass |

See [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md) for the full design.

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
| `docs/cc-plugin-skills-declaration-research.md` | Decision record on plugin.json skills declaration (M3 Task 1) |
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

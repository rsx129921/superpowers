# cc-tuned Layer

This directory is the **Claude Code-specific layer** of the rsx129921/superpowers fork. It adds CC-aware hooks and (in M3) memory-aware skills on top of the upstream superpowers core, without editing any upstream skill prose.

## Status

| Milestone | Status | What ships |
|-----------|--------|------------|
| M1 Foundation | active | this scaffold + stub hooks |
| M2 Hook Layer | not started | real hook logic |
| M3 Memory-Aware Skills | not started | three companion skills |
| M4 Upstream Sync v1 | not started | first post-fork merge |
| M5 Polish & Docs | not started | final README pass |

See [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md) for the full design.

## What lives here

| Path | Purpose |
|------|---------|
| `hooks/run-hook.cmd` | Polyglot bat+bash dispatcher (mirrors upstream pattern) |
| `hooks/lib/platform-detect.sh` | "Are we on CC?" check, sole source of truth |
| `hooks/lib/mcp-introspect.sh` | Read MCP server names from settings.json files |
| `hooks/cc-session-start` | M2: inject MCP availability + memory-aware directive |
| `hooks/cc-user-prompt-submit` | M2: keyword-match user prompt, re-inject discipline |
| `hooks/cc-pre-compact` | M2: preserve bootstrap across compaction |
| `skills/` | M3: three `memory-aware-*` companion skills |
| `tests/run-all.sh` | Tier 1+2 test entry point |
| `docs/plugin-hooks-research.md` | Decision record on where hook events register |

## Soft-strip guarantees

This layer is designed to coexist with upstream pulls. Properties to maintain:

1. **No upstream skill files are edited.** Ever. Memory-aware skills (M3) *wrap* upstream skills via `Skill` invocation; they do not duplicate or modify upstream content.
2. **One upstream JSON file has small additive edits.** `hooks/hooks.json`. List-append edits that conflict rarely. Per the Task 1 decision record (`docs/plugin-hooks-research.md`), `.claude-plugin/plugin.json` is intentionally left untouched — declaring hooks there alongside the default `hooks/hooks.json` triggers CC's duplicate-detection error. The design spec §5 has the conflict-resolution playbook.
3. **All hooks no-op on non-CC harnesses.** The fork remains installable on Codex, Gemini, Cursor, OpenCode, Copilot CLI — the cc-tuned layer just silently disables itself there.
4. **All hooks fail open.** Exit 0 with empty output on any error. Hooks never block a user turn or session start.

## Running tests

```bash
bash cc-tuned/tests/run-all.sh
```

Expected output ends with `All test files passed.` on a clean run.

## Manual smoke test (Tier 3)

> This procedure becomes meaningful once M2 ships. M1 stubs are silent on success.

1. Open a fresh CC session with this plugin loaded.
2. Send the user message: `let's debug a failing test`.
3. Expected behavior:
   - `cc-user-prompt-submit` matches the `failing` keyword.
   - Injection suggests `superpowers:systematic-debugging`.
   - If `cognee-memory` MCP is up, `memory-aware-debugging` should trigger and recall prior debugging context.
4. If any step doesn't happen, see `cc-tuned/docs/` for troubleshooting.

## Rip-cord

If you ever want to abandon the cc-tuned layer entirely:

```bash
# 1. Delete the layer
git rm -r cc-tuned/

# 2. Revert the two JSON additive edits (find via git log -p plugin.json hooks/hooks.json)
git checkout <upstream-SHA> -- .claude-plugin/plugin.json hooks/hooks.json

# 3. Commit
git commit -m "revert: remove cc-tuned layer"
```

That's it. Soft-strip designed for low commitment.

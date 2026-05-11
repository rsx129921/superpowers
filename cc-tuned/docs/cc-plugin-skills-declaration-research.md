# Plugin Skills Declaration: Decision Record

**Date:** 2026-05-11
**Decision:** Place cc-tuned skills at `cc-tuned/skills/` and register via plugin.json `skills` field (`"./cc-tuned/skills/"`).
**Authority:** Official Claude Code Plugins reference — https://code.claude.com/docs/en/plugins-reference (Component path fields table; Path behavior rules section) — URL confirmed live 2026-05-11
**Empirical verification:** Deferred (subagent cannot run /plugin list)

## Findings

### Upstream pattern

- Upstream skills live at the default `skills/<name>/SKILL.md` path. Claude Code auto-discovers them with no `skills` field in `plugin.json`.
- Current `.claude-plugin/plugin.json` has **no `skills` field**; auto-discovery handles the upstream `skills/` directory entirely.

### Does plugin.json support a `skills` field?

**Yes.** The Component path fields table in the official reference lists:

| Field    | Type          | Description                                                                                              | Example               |
|----------|---------------|----------------------------------------------------------------------------------------------------------|-----------------------|
| `skills` | string\|array | Custom skill directories containing `<name>/SKILL.md` **(in addition to default `skills/`)** | `"./custom/skills/"` |

The complete schema example in the reference shows:

```json
{
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"]
}
```

### Can it point to non-default paths?

**Yes.** The field's explicit purpose is to register skill directories **outside** the standard `skills/` location. Multiple paths can be listed as an array.

### Format

- Single path string: `"./cc-tuned/skills/"` (relative to plugin root, must start with `./`)
- Array form: `["./cc-tuned/skills/"]`
- Each entry must be a **directory** containing `<name>/SKILL.md` subdirectories (not a path to individual SKILL.md files)

### Duplicate-detection behavior

**No conflict.** Unlike the `hooks` field (where explicitly declaring `./hooks/hooks.json` alongside the auto-discovered default causes a duplicate-detection error), the `skills` field uses **additive** semantics. Per the official Path behavior rules section:

> **Adds to the default**: `skills`. The default `skills/` directory is always scanned, and directories listed in `skills` are loaded alongside it.

Declaring `"./cc-tuned/skills/"` in `plugin.json` adds those skills on top of upstream's `skills/`; it does not replace or conflict with auto-discovery of `skills/`. There is no documented duplicate-detection error for `skills`.

This is the opposite of `commands`, `agents`, and `outputStyles`, which **replace** their default directories when declared in the manifest.

### Path rules for the `skills` field

From the official reference (Path behavior rules section):

- All paths must be relative to the plugin root and start with `./`
- When a skill path points to a directory containing a `SKILL.md` directly (e.g., `"skills": ["./"]` pointing to the root), the frontmatter `name` field determines the invocation name; directory basename is the fallback.
- Components from custom paths use the same naming and namespacing rules as auto-discovered skills.

## Decision and rationale

**Option B: Place skills at `cc-tuned/skills/` AND declare them in plugin.json's `skills` field.**

Rationale:

1. **Non-default path requires manifest declaration.** `cc-tuned/skills/` is not the default `skills/` location. Auto-discovery only scans `skills/` at the plugin root. Without a `skills` entry in `plugin.json`, skills at `cc-tuned/skills/` would be silently ignored.

2. **Additive semantics mean no conflict.** The `skills` field does not replace `skills/`; it supplements it. Upstream skills remain unaffected. No duplicate-detection error will occur. This is confirmed by the official docs' explicit statement that `skills` "adds to the default."

3. **Isolation from upstream is preserved.** Keeping our skills under `cc-tuned/skills/` instead of `skills/` avoids merge conflicts with upstream SKILL.md additions and keeps the cc-tuned subtree self-contained.

4. **This is the second additive edit to plugin.json beyond M1's soft-strip baseline.** M1 left `plugin.json` untouched (hooks used auto-discovery). This task requires adding a `skills` field. This is a deliberate and minimal manifest edit — one new key, one relative path. The M1 baseline remains otherwise intact.

5. **Lower risk than Option A.** Putting skills in `skills/` (Option A) would mix cc-tuned skills with upstream skills, creating merge conflicts every time upstream adds or renames a skill directory. Option B's one-line manifest edit is a smaller conflict surface.

## Implication for Tasks 3-6

- **Tasks 3, 4, 5** create skills at `cc-tuned/skills/<skill-name>/SKILL.md`.
- **Task 6** edits `.claude-plugin/plugin.json` to add `"skills": "./cc-tuned/skills/"`. This is a single-key addition to the existing metadata object. It is the only required manifest change for M3 skill registration.
- No changes to `hooks/hooks.json` or any other file are needed for skill discovery.

## Post-merge verification

Run `/plugin list` in a fresh CC session after merge; confirm the three memory-aware-* skills appear. Alternatively, run `claude --debug` and look for the `cc-tuned/skills/` directory listed in plugin loading output.

## Evidence log

| Source | URL | Accessed |
|--------|-----|----------|
| Official CC plugins reference (Component path fields table) | https://code.claude.com/docs/en/plugins-reference | 2026-05-11 |
| Official CC plugins reference (Path behavior rules section) | https://code.claude.com/docs/en/plugins-reference | 2026-05-11 |
| Official CC plugins reference (Complete schema example) | https://code.claude.com/docs/en/plugins-reference | 2026-05-11 |

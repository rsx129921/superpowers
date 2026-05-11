# Plugin Hooks Declaration: Decision Record

**Date:** 2026-05-10
**Decision:** Register cc-tuned hooks in `hooks/hooks.json`
**Authority:** Official Claude Code Plugins reference — https://code.claude.com/docs/en/plugins-reference (File locations reference table; Component path fields table) — URL confirmed live 2026-05-10
**Empirical verification:** Deferred (subagent cannot run /plugin list)

## Findings

- `.claude-plugin/plugin.json` **does support** a `hooks` field (type: `string|array|object`). Per the official schema, it accepts "Hook config paths or inline config" — for example, `"./my-extra-hooks.json"`. This field is intended for pointing to **non-default paths** or declaring hooks inline; it is NOT needed to activate the default hooks file.
- `hooks/hooks.json` **is** the canonical auto-discovered location. The official File locations reference table lists `hooks/hooks.json` as the default location for "Hook configuration." Claude Code loads it automatically — no declaration in `plugin.json` is required or expected.
- **If both are used for the same file**: Declaring `"hooks": "./hooks/hooks.json"` in `plugin.json` when `hooks/hooks.json` already exists at the default location causes a **duplicate detection error**. A real-world bug report (https://github.com/affaan-m/everything-claude-code/issues/103) documents exactly this: the fix was to remove the explicit `hooks` declaration from `plugin.json` and let auto-discovery handle it.
- **Precedence:** There is no precedence question for the default file. `hooks/hooks.json` is loaded automatically regardless of what `plugin.json` says. The `plugin.json` `hooks` field is only consulted for non-default paths or inline config, and only adds entries — it does not replace the auto-discovered file.

### Upstream pattern confirms this

The upstream `superpowers` repo currently follows the correct pattern:
- `.claude-plugin/plugin.json` has **no** `hooks` field.
- `hooks/hooks.json` declares the existing `SessionStart` hook.

This is exactly what the official docs prescribe. The upstream author has already resolved this correctly.

### What the official spec says about `plugin.json` `hooks` field

From the Component path fields table in the official reference:

| Field  | Type                  | Description                       | Example                    |
|--------|-----------------------|-----------------------------------|----------------------------|
| `hooks`| string\|array\|object | Hook config paths or inline config| `"./my-extra-hooks.json"`  |

The example (`"./my-extra-hooks.json"`) is deliberately a **non-default path** — not `./hooks/hooks.json`. This underscores that the field's purpose is to register hooks that live outside the standard location.

## Rationale

Register cc-tuned hooks in `hooks/hooks.json` because:

1. **It is the canonical auto-discovered location.** The official docs state this unambiguously: `hooks/hooks.json` in plugin root is the default hook configuration file (https://code.claude.com/docs/en/plugins-reference#file-locations-reference — URL confirmed live 2026-05-10).

2. **No `plugin.json` edit is needed for the default location.** Adding `"hooks": "./hooks/hooks.json"` to `plugin.json` would be redundant and would trigger a duplicate detection error (confirmed by real-world bug report).

3. **The upstream codebase already uses this pattern correctly.** The existing `SessionStart` hook in `hooks/hooks.json` works without any declaration in `plugin.json`. Our new hooks simply append entries to the same file.

4. **Minimal diff, minimal conflict surface.** All hook changes stay in one file. The design spec's stated goal of "two small JSON conflicts per upstream pull at most" is preserved.

## Implication for Task 6

Task 6 will edit `hooks/hooks.json` only. It will append three new hook entries:
- A second `SessionStart` entry (matcher `startup|clear|compact`) for `cc-session-start`
- A `UserPromptSubmit` entry for `cc-user-prompt-submit`
- A `PreCompact` entry for `cc-pre-compact`

The `.claude-plugin/plugin.json` manifest stays **untouched** by Task 6. No `hooks` field should be added to it.

## Post-Task-6 verification

See implementation plan Task 6 Step 4 and Task 9 Step 3 for the verification procedure.

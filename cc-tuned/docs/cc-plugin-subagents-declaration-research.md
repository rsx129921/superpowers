# cc-plugin subagents declaration research

**Date:** 2026-05-12
**Purpose:** Decide how to register the M6 dedicated cc-tuned subagents in the plugin so the soft-strip invariant holds.

## Question

Does `.claude-plugin/plugin.json` support a field for declaring custom subagent paths (analogous to the `skills` field added in M3)? If yes, what's the field name and value format?

## Findings

Source: Claude Code plugin reference (`https://code.claude.com/docs/en/plugin-reference`, fetched 2026-05-12).

### Field name and format

The manifest supports an `agents` field:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `agents` | `string \| array` | Custom agent files (replaces default `agents/`) | `"./custom/agents/reviewer.md"` |

A string value points to a directory or a single file. An array can list multiple files or directories. When the manifest specifies `agents`, the default `agents/` directory at plugin root is no longer scanned.

### Default discovery

Without an `agents` field, Claude Code auto-discovers subagents from `<plugin-root>/agents/`. The fork currently has no top-level `agents/` directory, so declaring `"agents": "./cc-tuned/agents/"` does not replace anything that already exists.

### Plugin subagent namespace

Plugin subagents appear in CC's `/agents` typeahead as `<plugin-name>:<agent-name>` per the docs. With the plugin name `superpowers` (per existing `plugin.json`), our four subagents will appear as:

- `superpowers:cc-tuned-implementer`
- `superpowers:cc-tuned-spec-reviewer`
- `superpowers:cc-tuned-code-quality-reviewer`
- `superpowers:cc-tuned-hook-tester`

### Security restrictions on plugin subagents

Per the docs, plugin subagents do NOT support:
- `hooks` frontmatter
- `mcpServers` frontmatter
- `permissionMode` frontmatter

These fields are silently ignored when CC loads the agent. If a subagent needs them, the user must copy the file to `.claude/agents/` or `~/.claude/agents/`. Our four subagents do not need any of these fields, so this restriction is acceptable.

## Decision

Use `"agents": "./cc-tuned/agents/"` in `.claude-plugin/plugin.json` — a single additive edit, exact mirror of M3's `"skills": "./cc-tuned/skills/"` declaration. The soft-strip invariant remains: still exactly two upstream files differ (`hooks/hooks.json` and `.claude-plugin/plugin.json`).

## Open questions (none blocking M6)

- Does CC respect `model` frontmatter on plugin subagents the same way it respects it on user-level subagents? Docs imply yes; verified in Tier 3 smoke test after merge.
- Will the `description` field's wording affect Claude's automatic delegation? Docs say "Claude uses each subagent's description to decide when to delegate." Worded carefully for each role.

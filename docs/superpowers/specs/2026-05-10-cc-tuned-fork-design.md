# CC-Tuned Superpowers Fork

**Date:** 2026-05-10
**Status:** Draft
**Fork:** rsx129921/superpowers (forked from obra/superpowers)
**Author:** Trace King

## Problem

Upstream superpowers is multi-harness by design — it supports Claude Code, Codex CLI, Codex App, Factory Droid, Gemini CLI, OpenCode, Cursor, and GitHub Copilot CLI. That portability is bought with a structural constraint: skills are pure prose loaded once at session start, with no per-session intelligence and no runtime introspection. The constraint is correct for upstream's scope, but produces two recurring frictions in daily Claude Code use:

1. **Skills don't auto-trigger reliably.** Three failure modes appear regularly:
   - **Rationalization** — Claude decides "this is too simple to need brainstorming" or "I can debug this without systematic-debugging" and skips the skill despite a matching trigger. The skill's own Red Flags table tries to fight this, but it loses sometimes.
   - **Pattern-blindness** — the user says something that should trigger a skill (e.g., "let's build X" → brainstorming) but Claude misses the cue and dives straight into implementation.
   - **Compaction amnesia** — bootstrap loads at session start, skills trigger correctly early on, then after context compaction Claude "forgets" the bootstrap discipline and stops invoking skills mid-session.

2. **Skills ignore available MCP servers.** brainstorming/systematic-debugging/writing-plans never reach for episodic-memory or cognee-memory to recall prior context on the topic at hand. The user has to manually remind Claude every time. The upstream skills can't bake this in because the MCPs aren't universally available across harnesses — but in a CC-only context, they nearly always are.

Both frictions share a root cause: **the bootstrap is a one-shot prose injection at session start with no runtime intelligence**. CC hooks fix this structurally.

## Goals

1. Add a CC-specific layer that addresses both frictions without editing upstream skill prose.
2. Keep upstream merges trivial — at most two small JSON conflicts per pull, no skill-file conflicts ever.
3. Stay installable on non-CC harnesses (the layer no-ops gracefully there).
4. No new abstractions beyond what the two frictions require — YAGNI ruthlessly.
5. Bootstrap GitHub milestones, issues, and labels so the fork has a real roadmap from day one.

## Non-Goals

- Slash-command shortcuts (`/brainstorm`, `/debug`, etc.) — user has not experienced this friction.
- Verification-before-completion as a Stop/PostToolUse hook — user has not experienced this friction; skill version is adequate.
- Statusline customization, output-style tuning, plan-mode integration, worktree-defaults rework — speculative, no proven friction.
- Absorbing the user's other plugins (CAIMS, episodic-memory, obsidian, gh-tracking) into the fork — they stay as separate composable plugins.
- Public distribution / marketplace publication — fork is a personal daily-driver. May reconsider after M5.
- CI workflows — single-user fork; local manual testing is sufficient at this scale.
- Wrapping any upstream skill beyond brainstorming/systematic-debugging/writing-plans — three is the floor and the ceiling for memory-aware variants.
- Auto-committing to memory — every memory write requires user approval per the user's existing CLAUDE.md routing rules.

## Design Principles

### Soft-strip, not hard-strip

The fork preserves all upstream files unchanged except for two additive JSON edits to `.claude-plugin/plugin.json` and `hooks/hooks.json`. New behavior lives in a single new top-level directory: `cc-tuned/`. Deleting `cc-tuned/` and reverting the two JSON hunks restores the upstream cleanly — the fork has a rip-cord.

### Wrap, don't replace

Memory-aware skills *invoke* the upstream skill they shadow rather than duplicate its content. When upstream improves `brainstorming/SKILL.md`, the memory-aware variant inherits the improvement for free. No merge work, no drift.

### Fail open

Every hook exits 0 with empty output on any error. Hooks must never block a user turn or prevent session start. Memory recall must never block; if an MCP times out, log and continue.

### No-op on non-CC harnesses

Every new hook detects platform via `$CLAUDE_PLUGIN_ROOT` (set) and `$COPILOT_CLI` (unset) and exits silently when the layer doesn't apply. The fork remains installable on Codex/Gemini/Cursor; the CC-tuned layer just silently disables itself there.

### Conservative keyword matching

The `cc-user-prompt-submit` keyword table is intentionally short and high-precision. False negatives (missed triggers) are acceptable — upstream skill discovery still works as fallback. False positives (noisy injection on every turn) erode the signal value of the injection itself.

## Design

### 1. File Layout

```
superpowers/                       (the fork)
├── .claude-plugin/
│   └── plugin.json                ← +hooks block (~5 lines)
├── hooks/
│   ├── hooks.json                 ← +3 entries (~15 lines)
│   ├── run-hook.cmd               ← unchanged
│   ├── session-start              ← unchanged (upstream owns)
│   └── ...                        ← all other upstream hooks unchanged
├── cc-tuned/                      ← NEW: entire CC-specific layer
│   ├── README.md
│   ├── hooks/
│   │   ├── cc-session-start
│   │   ├── cc-user-prompt-submit
│   │   ├── cc-pre-compact
│   │   └── lib/
│   │       ├── platform-detect.sh
│   │       └── mcp-introspect.sh
│   ├── skills/
│   │   ├── memory-aware-brainstorming/SKILL.md
│   │   ├── memory-aware-debugging/SKILL.md
│   │   └── memory-aware-planning/SKILL.md
│   └── tests/
│       └── hooks/
│           ├── test-platform-detect.sh
│           ├── test-keyword-match.sh
│           ├── test-pre-compact.sh
│           └── test-mcp-detection.sh
└── docs/superpowers/specs/
    └── 2026-05-10-cc-tuned-fork-design.md   (this file)
```

All hook scripts use the existing `run-hook.cmd` polyglot pattern (cmd-bat header + bash body) for Windows + Unix compatibility. The user's primary environment is Windows.

### 2. Hook Layer

Three new hooks, each targeting one specific failure mode.

#### 2.1 `cc-session-start` — MCP introspection

Registered on the `SessionStart` event with matcher `startup|clear|compact` (same as the upstream `session-start` hook). Both hooks run; CC executes them in registration order.

Behavior:
1. Calls `platform-detect.sh`. Exits 0 with empty output if not on CC.
2. Calls `mcp-introspect.sh` which:
   - Reads `~/.claude/settings.json` and `.claude/settings.json` for `mcpServers` config.
   - Inspects environment for active MCP tool prefixes (`mcp__*`).
   - Returns a deduplicated list of detected MCP names.
3. Emits `additionalContext` JSON containing:
   - A line listing detected MCPs by name.
   - A short directive: *"When you would invoke `superpowers:brainstorming`, `superpowers:systematic-debugging`, or `superpowers:writing-plans`, FIRST invoke the corresponding `memory-aware-*` variant if `episodic-memory` or `cognee-memory` is in the available MCPs list above."*
4. Content is identical session-to-session for a given MCP configuration, keeping the prompt cache warm.

#### 2.2 `cc-user-prompt-submit` — keyword match + rule re-injection

Registered on `UserPromptSubmit` with no matcher (fires on every user turn).

Behavior:
1. Platform detect. Exits silently if not on CC.
2. Reads the user prompt from stdin (`{"prompt": "..."}` JSON).
3. Pattern-matches a conservative keyword table:

| Pattern (case-insensitive) | Suggested skill |
|----------------------------|----------------|
| `let's build\|let's make\|let's create\|new feature\|implement` | `superpowers:brainstorming` |
| `failing\|broken\|bug\|test.*fail\|why is this\|doesn't work` | `superpowers:systematic-debugging` |
| `add tests\|TDD\|test first` | `superpowers:test-driven-development` |
| `plan\|spec\|design` (when `docs/superpowers/specs/` has no matching file) | `superpowers:writing-plans` |

4. On match, emits `additionalContext` with:
   - A targeted reminder: *"This prompt matches the `<skill>` trigger pattern. Per the using-superpowers bootstrap, you MUST invoke `<skill>` before any other action — including clarifying questions."*
   - A condensed re-injection of the using-superpowers Red Flags table (defeats rationalization).
5. No match → emit nothing. Don't pollute every turn with noise.

#### 2.3 `cc-pre-compact` — bootstrap preservation

Registered on `PreCompact`.

Behavior:
1. Platform detect. Exits silently if not on CC.
2. Emits a fixed string via `additionalContext`:
   > *"After this compaction completes: the using-superpowers bootstrap is still in effect. The compaction summary MUST include a note that superpowers skills (brainstorming, systematic-debugging, test-driven-development, writing-plans, verification-before-completion) remain available via the Skill tool and SHOULD be invoked when their trigger conditions match."*
3. The summarizer model receives this instruction as part of its input and incorporates it into the compacted summary, which the post-compaction model then sees.

### 3. Memory-Aware Skill Family

Three thin wrapper skills under `cc-tuned/skills/`. Each is <100 lines of prose. Each follows the same three-step structure: RECALL → invoke upstream skill → COMMIT (offer).

#### 3.1 `memory-aware-brainstorming`

Frontmatter description: *"Use this BEFORE any creative work when memory MCPs are available — recall prior context first, then brainstorm, then offer to commit durable decisions."*

Body:
1. **RECALL.** Before the first clarifying question:
   - `episodic-memory` search: project name + 2-3 concepts from the user's message.
   - `cognee-memory` GRAPH_COMPLETION: *"what conventions or decisions has the user made about `<topic>` in `<project>`?"*
   - Surface findings: *"I found prior context on this. Should I build on it, or are we starting fresh?"*
   - Empty result → say so briefly and proceed.
2. **BRAINSTORM.** Invoke `superpowers:brainstorming` and follow its checklist exactly.
3. **COMMIT.** After design is approved AND spec written:
   - Identify 1–3 durable decisions worth future recall.
   - Offer one-sentence cognify candidates.
   - Wait for user approval. Never auto-commit.

#### 3.2 `memory-aware-debugging`

Frontmatter description: *"Use when encountering any bug, test failure, or unexpected behavior AND memory MCPs are available."*

Body:
1. **RECALL.**
   - `episodic-memory` search: `<error message>` + project name.
   - `cognee-memory` GRAPH_COMPLETION: *"have we resolved errors of type `<category>` in `<project>`? what was the root cause?"*
   - Surface any prior fix: *"We hit this in `<session>`, root cause was `<X>`. Does that apply here?"*
2. **DEBUG.** Invoke `superpowers:systematic-debugging`.
3. **COMMIT.** After root cause identified and fix verified:
   - Distill: root cause (1 sentence), signal that pointed to it (1 sentence).
   - Offer to cognify as a project-tagged fact.
   - Skip if the bug was trivial (typo, off-by-one).

#### 3.3 `memory-aware-planning`

Frontmatter description: *"Use when starting any implementation plan AND memory MCPs are available."*

Body:
1. **RECALL.**
   - `cognee-memory` GRAPH_COMPLETION: *"what conventions does `<project>` follow for `<area>`?"* and *"what tools/libraries/patterns does `<project>` use for `<area>`?"*
   - `episodic-memory` search: prior plans in the same area.
   - Synthesize into a *"Conventions to follow"* section the plan must respect.
2. **PLAN.** Invoke `superpowers:writing-plans`.
3. **COMMIT.** If the plan introduces a new convention:
   - Offer to cognify as: *"`<project>` uses `<pattern>` for `<area>` because `<reason>`."*
   - Wait for approval.

### 4. JSON Manifest Edits

#### 4.1 `.claude-plugin/plugin.json`

Add a `hooks` array declaring the three new events. Exact JSON structure follows CC's plugin spec (resolved in the implementation plan). Estimated diff size: ~5 lines.

#### 4.2 `hooks/hooks.json`

Add three entries — one for each new event (SessionStart already exists; append a second matcher entry). Estimated diff size: ~15 lines.

Both files are list-append edits that conflict rarely with upstream changes.

### 5. Upstream-Merge Strategy

**Branch model:** All work commits to `main`. Upstream pulls happen as merge commits (not rebases), preserving both histories.

**Cadence:** One merge per upstream release tag (currently every few weeks).

**Conflict playbook:** Only two files can conflict by design:

| File | Likely conflict | Resolution |
|------|-----------------|------------|
| `.claude-plugin/plugin.json` | Upstream bumps version, adds keys near our edit | Keep both. Our `hooks` block stays. |
| `hooks/hooks.json` | Upstream adds a new hook entry | Keep both. Order irrelevant. |

Any conflict outside these two files signals drift — investigate before resolving.

**Useful alias** (suggested in `cc-tuned/README.md`, not auto-installed): `git log --first-parent --oneline main` to view fork-only history with upstream merges collapsed.

### 6. Testing

Three tiers, scaling effort to risk.

**Tier 1 — Hook unit tests** (`cc-tuned/tests/hooks/`)
- One test per hook script. Invokes with synthetic env + stdin; asserts on emitted JSON.
- Platform detection mocked by setting/unsetting `$CLAUDE_PLUGIN_ROOT`, `$CURSOR_PLUGIN_ROOT`, `$COPILOT_CLI`.
- Run via `bash cc-tuned/tests/run-all.sh`. Target runtime: <1s total.

**Tier 2 — Skill structure tests**
- Validate every new `SKILL.md` has required frontmatter (`name`, `description`).
- Validate body references the upstream skill it wraps.
- Static checks only.

**Tier 3 — Manual session smoke test** (documented in `cc-tuned/README.md`)
- Open fresh CC session, send: *"let's debug a failing test"*.
- Expected: `cc-user-prompt-submit` matches `failing` keyword → injects systematic-debugging suggestion → if cognee MCP is up, `memory-aware-debugging` triggers and recalls prior debugging.
- One-page checklist. Not automated.

### 7. GitHub Tracking

#### 7.1 Milestones

| # | Milestone | Acceptance |
|---|-----------|------------|
| M1 | Foundation: `cc-tuned/` scaffold, platform-detect, JSON edits, README | All three hooks register; CC `/plugin list` shows them; no-op on non-CC verified. |
| M2 | Hook Layer: all three hooks implemented + unit-tested | Tier 1 tests green; Tier 3 smoke test passes. |
| M3 | Memory-Aware Skills: three skill files written and wired to MCPs | Tier 2 tests green; manual recall+commit verification per skill. |
| M4 | Upstream Sync v1: first post-fork upstream merge | Clean merge with only the two expected JSON conflicts; fork tests pass post-merge. |
| M5 | Polish & Docs: fork README, `cc-tuned/README.md`, smoke-test docs | README clear enough for future-self after 6 months away. |

Each milestone gets one **umbrella tracker issue** with checkboxes for sub-tasks, plus individual sub-task issues that reference the umbrella with `Closes #N` in their PRs (the `gh-issue-tracking` framework's pattern).

#### 7.2 Issue templates

Keep all upstream templates. Add three fork-specific ones under `.github/ISSUE_TEMPLATE/`:
- `cc-friction.md` — captures real CC frictions for future fork work.
- `mcp-integration.md` — proposes a new MCP server as recall-aware.
- `upstream-merge.md` — tracking template for each upstream sync.

#### 7.3 Labels

| Label | Color | Use |
|-------|-------|-----|
| `cc-tuned` | blue | Anything touching `cc-tuned/`. |
| `upstream-sync` | green | Merge-from-upstream work. |
| `hook` | purple | Hook-related. |
| `skill` | yellow | Skill-related. |
| `friction` | red | Real-world pain captured from sessions. |
| `infra` | gray | Manifests, JSON, tests, docs. |

#### 7.4 PR template

Keep the upstream `.github/PULL_REQUEST_TEMPLATE.md` for the fork's own use (the discipline pays even on a personal fork), but strip the upstream-specific "warning to AI agents" / "94% rejection rate" framing — that's about contributing to obra/superpowers, not maintaining your own fork.

Retained sections: Problem / Approach / Testing / Existing PRs.

## Rollout Order

1. **M1 Foundation** — scaffold lands first. Verifies the plugin manifest + hooks.json edits don't break anything.
2. **M2 Hook Layer** — three hooks, fully tested, before any skill work.
3. **M3 Memory-Aware Skills** — depends on M2 (hooks must inject MCP availability before skills can rely on it).
4. **M4 Upstream Sync v1** — happens whenever upstream releases next after M3. Validates the merge playbook in practice.
5. **M5 Polish & Docs** — last; fast iteration on internal docs after the layer is proven.

## Risks & Open Questions

- **Plugin manifest hook declarations:** CC's plugin spec format for declaring hook events in `plugin.json` may differ from registering them in `hooks/hooks.json`. The implementation plan must verify which mechanism CC uses for plugin-declared hooks and update Section 4.1 accordingly.
- **MCP introspection reliability:** `mcp-introspect.sh` depends on parsing `~/.claude/settings.json` and `.claude/settings.json`. If those formats change, MCP detection breaks. Mitigation: fail open — missing detection means memory-aware skills don't trigger, but normal skills still work.
- **Keyword table maintenance:** False positives may emerge as user prompts evolve. Mitigation: M5 includes a documented review of the keyword table; tune based on actual session experience, not speculation.
- **Pre-compact hook timing:** CC's `PreCompact` hook contract (whether `additionalContext` reaches the summarizer or just the post-compaction model) needs to be confirmed against current CC behavior. If `additionalContext` only reaches the post-compaction model, the hook's value is reduced but still positive (it re-asserts bootstrap immediately after compaction).
- **Single-user testing limits:** Tier 3 smoke test is manual and single-eyes-on. Regressions in skill triggering may go unnoticed until they bite during real work. Mitigation: accept this risk for a personal daily-driver; revisit if the fork ever gains other users.

## Out-of-Scope (Future Work, Not Now)

- Slash-command shortcuts.
- Verification-as-hook enforcement.
- Statusline integration showing current skill state.
- Output-style awareness in skill prose.
- `memory-aware-tdd` / `memory-aware-finishing-branch` / `memory-aware-code-review` — only added if real friction emerges.
- Public marketplace publication.
- CI integration.
- Additional MCP wrappers beyond episodic-memory + cognee-memory.

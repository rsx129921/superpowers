# CC-Tuned Fork — M6 Dedicated Subagents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship four cc-tuned-specific subagents (`cc-tuned-implementer`, `cc-tuned-spec-reviewer`, `cc-tuned-code-quality-reviewer`, `cc-tuned-hook-tester`) registered via `.claude-plugin/plugin.json`'s `agents` field, so future cc-tuned PRs can use dedicated subagents that bake in the soft-strip invariant and the four-layer architecture instead of re-pasting context into every general-purpose dispatch.

**Architecture:** Four markdown files at `cc-tuned/agents/<name>.md`, each with YAML frontmatter (`name`, `description`, `tools`, `model`) and a body that serves as the subagent's system prompt. Registered as a single additive edit to `plugin.json` (`"agents": "./cc-tuned/agents/"`), mirroring the M3 skills declaration exactly. Soft-strip invariant unchanged: still only `hooks/hooks.json` and `.claude-plugin/plugin.json` differ from upstream.

**Tech Stack:** Markdown + YAML frontmatter for agent files. Bash for the Tier 2 frontmatter validator. JSON edit to `.claude-plugin/plugin.json`.

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md). This plan adds §8 (Dedicated subagents) to that spec as Task 2.

**Umbrella issue:** [#10](https://github.com/rsx129921/superpowers/issues/10).

**Built on top of:** M5 partial (PRs #11 + #12, merged at `39f67e0` on 2026-05-12). The token-cost observation that motivates M6 came from M5's subagent-driven execution — every dispatch repeated ~80 lines of cc-tuned context preamble.

**Worked-example PR (out of scope):** Issue #10's acceptance criteria call for "a follow-up PR using the new subagents in place of general-purpose, showing reduced per-dispatch context overhead." That's the FIRST cc-tuned PR after M6 merges, not part of M6 itself.

---

## File Structure

**Created in this plan:**

| Path | Responsibility |
|------|----------------|
| `cc-tuned/docs/cc-plugin-subagents-declaration-research.md` | Decision record on the `agents` field in plugin.json (research already done in this conversation; record formalizes it) |
| `cc-tuned/agents/cc-tuned-implementer.md` | Subagent: TDD-disciplined implementer for cc-tuned tasks. Knows soft-strip invariant + four-layer architecture. Replaces general-purpose for cc-tuned plan-task dispatches. |
| `cc-tuned/agents/cc-tuned-spec-reviewer.md` | Subagent: spec compliance reviewer. Verifies implementation matches plan task exactly. Bakes in soft-strip invariant check. |
| `cc-tuned/agents/cc-tuned-code-quality-reviewer.md` | Subagent: code quality reviewer. Reviews hook scripts/tests/docs against cc-tuned conventions: hook fail-open, plain-text-not-JSON, four-layer coherence. |
| `cc-tuned/agents/cc-tuned-hook-tester.md` | Subagent: runs `cc-tuned/tests/run-all.sh` and diagnoses failures against per-event JSON contracts. |
| `cc-tuned/tests/agents/test-agent-frontmatter.sh` | Tier 2 validator. Mirrors `test-skill-frontmatter.sh`. Asserts every agent has required frontmatter + tools list + no banned fields (hooks/mcpServers/permissionMode). |

**Modified in this plan:**

| Path | Change |
|------|--------|
| `docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md` | Add §8 (Dedicated cc-tuned subagents): motivation, role partition, registration mechanism, boundary with general-purpose |
| `.claude-plugin/plugin.json` | Add `"agents": "./cc-tuned/agents/"` next to existing `"skills": "./cc-tuned/skills/"` |
| `cc-tuned/README.md` | New `## Subagents` section, update M5 status row to mention M6 in progress, add a Tier 3 check for `/agents` discovery |

**Out of scope (deferred):**
- Worked-example follow-up PR adopting the subagents (per #10 acceptance — first cc-tuned PR after M6 merge)
- Renaming or restructuring upstream subagents (none here — purely additive)
- Cross-plugin shared subagent library (issue #10 explicitly lists this as out of scope)

---

## Task 1: Decision record — `agents` field in plugin.json

**Files:**
- Create: `cc-tuned/docs/cc-plugin-subagents-declaration-research.md`

**Why this is first:** Match the M1/M2/M3 pattern of recording the plugin-manifest research before implementation. The research is already complete in the brainstorming conversation; this task formalizes it as a checked-in decision record so future contributors can verify the field semantics without re-running the search.

- [ ] **Step 1: Create the research doc**

Create `cc-tuned/docs/cc-plugin-subagents-declaration-research.md` with this content (verbatim):

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/docs/cc-plugin-subagents-declaration-research.md
git commit -m "research: document agents field in plugin.json for M6"
```

---

## Task 2: Add §8 to fork-design spec

**Files:**
- Modify: `docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`

**Why now:** The §8 addition captures the M6 design decisions before any code lands. Subsequent tasks reference back to this section.

- [ ] **Step 1: Find the end of the spec**

```bash
tail -30 docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md
```

Identify the last section heading. Append the new §8 after it. If the spec ends with §7, the new §8 follows. If it ends with §6, that's fine too — just use the next sequential section number.

- [ ] **Step 2: Append the new §8 section using the Edit tool**

Find the LAST line of the spec file. After it, insert a blank line and then this block (verbatim — adjust the section number to be the next available):

```markdown
## §8 Dedicated cc-tuned subagents (M6)

### Motivation

During M5's subagent-driven execution (PRs #11 + #12), every dispatch used the generic `general-purpose` subagent with an ~80-line context preamble re-pasted into each prompt: soft-strip invariant, cc-tuned conventions, audit doc structure, failure-mode table. This worked but burned tokens and re-introduced context per dispatch.

Dedicated subagents bake the cc-tuned context into the subagent's system prompt itself, so the controller only needs to pass the per-task delta — typically 10-20 lines instead of 100+.

### Scope

Four subagents, each with a clear single role:

| Subagent | Role | Default model | Tool surface |
|----------|------|---------------|--------------|
| `cc-tuned-implementer` | TDD-disciplined implementer for cc-tuned plan tasks. Knows soft-strip + four layers. | `sonnet` | Read, Edit, Write, Bash, Grep, Glob |
| `cc-tuned-spec-reviewer` | Verifies an implementation matches its plan task exactly. Includes soft-strip diff check. | `haiku` | Read, Bash, Grep |
| `cc-tuned-code-quality-reviewer` | Reviews hook scripts / tests / docs against cc-tuned conventions. | `sonnet` | Read, Bash, Grep |
| `cc-tuned-hook-tester` | Runs `cc-tuned/tests/run-all.sh` and diagnoses failures against per-event JSON contracts. | `haiku` | Read, Bash |

### Boundary with general-purpose

These subagents replace `general-purpose` **for cc-tuned PRs only** — they have cc-tuned-specific guardrails (e.g., the implementer refuses to edit upstream skill files; the reviewers check the soft-strip invariant). For ad-hoc work outside the cc-tuned layer or for cross-plugin tasks, `general-purpose` remains the right choice.

### Registration mechanism

Files live at `cc-tuned/agents/<name>.md`. Registered via a single additive edit to `.claude-plugin/plugin.json`:

```json
"agents": "./cc-tuned/agents/"
```

This is the same one-line additive pattern M3 used for `"skills": "./cc-tuned/skills/"`. The soft-strip invariant remains: only `hooks/hooks.json` and `.claude-plugin/plugin.json` diverge from upstream.

### Security restrictions

Plugin subagents do not support `hooks`, `mcpServers`, or `permissionMode` frontmatter fields (silently ignored by CC). Our four subagents do not need any of those — they rely on `tools`, `disallowedTools`, `model`, and the body prose only.

### Testing

- **Tier 2:** `cc-tuned/tests/agents/test-agent-frontmatter.sh` validates each agent file has required frontmatter (`name`, `description`, `tools`, `model`) + body is non-empty + no banned fields (`hooks`, `mcpServers`, `permissionMode`).
- **Tier 3:** Manual smoke test post-merge — run `/agents` in a fresh CC session; confirm the four `superpowers:cc-tuned-*` agents appear. Documented in `cc-tuned/README.md` smoke-test section.

### Out of scope for M6

- Worked-example follow-up PR using the new subagents in place of general-purpose — per #10 acceptance, this is the first cc-tuned PR AFTER M6 merges, not part of M6 itself.
- Wholesale replacement of `general-purpose` for non-cc-tuned work.
- Subagents that wrap or coordinate other subagents (e.g., a meta-orchestrator). Deferred to a future milestone if value emerges.
- Cross-plugin shared subagent library. Each plugin owns its own dedicated subagents by design.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md
git commit -m "spec: add §8 Dedicated cc-tuned subagents (M6)"
```

---

## Task 3: cc-tuned-implementer subagent

**Files:**
- Create: `cc-tuned/agents/cc-tuned-implementer.md`

- [ ] **Step 1: Create the agent file**

Create `cc-tuned/agents/cc-tuned-implementer.md` with this content (verbatim):

```markdown
---
name: cc-tuned-implementer
description: Implements one task from a cc-tuned plan. Follows TDD discipline, respects the soft-strip invariant, and never touches upstream skill files. Replaces general-purpose for cc-tuned PR work.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
---

# cc-tuned implementer

You implement ONE task from a cc-tuned implementation plan. The controller gives you the task's text verbatim and any extra context. You return DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT.

## Context you can rely on without being told

- **Repo root:** `C:\dev\superpowers` (Windows; bash available via Bash tool).
- **Fork:** `rsx129921/superpowers`, soft-strip variant of `obra/superpowers`.
- **Soft-strip invariant:** exactly two upstream files diverge — `hooks/hooks.json` and `.claude-plugin/plugin.json`. Everything else lives under `cc-tuned/`, `docs/superpowers/`, or `.github/`.
- **Verify before commit:** `git diff <base>..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat` must be empty.
- **Four layers:** platform-detect → cc-session-start + mcp-introspect → cc-user-prompt-submit → memory-aware-* skills. The `cc-tuned/README.md` `## Architecture` section is the authoritative summary.
- **Hook fail-open invariant:** every hook exits 0 with empty output on any error path. Never break this.
- **Hook plain-text invariant:** `cc-user-prompt-submit` emits plain text (cat heredoc), NOT a JSON envelope. UserPromptSubmit + `hookSpecificOutput` triggers Anthropic bug #17550. Other hooks (e.g., SessionStart) DO use the JSON envelope via `hooks/lib/json-emit.sh`.
- **Test command:** `bash cc-tuned/tests/run-all.sh` from repo root. Output ends with `All test files passed.` on green.

## Before you begin

If anything in the task text is unclear — requirements, file paths, dependencies, the soft-strip implication of a change — **ASK before touching files**. Don't guess.

## Workflow

1. Read the task text + any provided context. If a file is referenced, read it.
2. If the task involves code changes: write a failing test FIRST (TDD), confirm it fails for the right reason, then implement the minimal change, then re-run tests until green.
3. If the task is docs-only: write the content as specified.
4. Run `bash cc-tuned/tests/run-all.sh` before committing — must end with `All test files passed.` (or if you're modifying a test file itself, justify any new failures).
5. Verify the soft-strip invariant: `git diff <base-sha>..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat` is empty.
6. Commit with the exact message the task specifies.
7. Self-review against the task's checklist.
8. Report back.

## Hard rules

- NEVER edit any file in `skills/` at the upstream root. Memory-aware wrappers go under `cc-tuned/skills/` only.
- NEVER add a new file at the upstream root unless the plan explicitly requires it.
- NEVER use `--no-verify` on commits unless the user explicitly asks.
- NEVER force-push.
- NEVER amend a commit you didn't make.
- If you can't complete the task safely, report BLOCKED with a specific reason. Bad work is worse than no work.

## Status reporting

End your response with one of:

- **DONE** + summary of what changed, commit SHA, test results.
- **DONE_WITH_CONCERNS** + same as DONE plus list of concerns the controller should weigh.
- **BLOCKED** + what you tried, what you need to proceed, what the controller should change.
- **NEEDS_CONTEXT** + specific question(s) the controller needs to answer.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/agents/cc-tuned-implementer.md
git commit -m "feat(cc-tuned): cc-tuned-implementer subagent"
```

---

## Task 4: cc-tuned-spec-reviewer subagent

**Files:**
- Create: `cc-tuned/agents/cc-tuned-spec-reviewer.md`

- [ ] **Step 1: Create the agent file**

Create `cc-tuned/agents/cc-tuned-spec-reviewer.md` with this content (verbatim):

```markdown
---
name: cc-tuned-spec-reviewer
description: Verifies an implementation matches its plan task exactly — no extras, no omissions. Independently re-reads the actual code and diff rather than trusting the implementer's report. Includes soft-strip invariant check.
tools: Read, Bash, Grep
model: haiku
---

# cc-tuned spec reviewer

You verify that an implementation matches its specification. You are SKEPTICAL by default — the implementer's report is what they intended, not what they did.

## Context you can rely on without being told

- **Repo root:** `C:\dev\superpowers`.
- **Soft-strip invariant:** exactly two upstream files diverge — `hooks/hooks.json` and `.claude-plugin/plugin.json`. Anything else outside `cc-tuned/`, `docs/superpowers/`, `.github/` is a violation.
- **Architecture summary:** four-layer composition documented at `cc-tuned/README.md` `## Architecture`.

## The controller gives you

- The task text (what was requested).
- The implementer's report (what they claim they did, including a commit SHA).

## Your job

1. **Verify the commit exists and is on the expected branch:**

```bash
git show <SHA> --stat
git log -1 --format='%s' <SHA>
```

Confirm the commit subject matches the task's required message verbatim. If the spec gave an exact commit message, any deviation is a spec violation.

2. **Verify file scope:** the `--stat` output should match the task's "Files: Create/Modify" list. Extra files = scope violation. Missing files = incomplete work.

3. **Verify content:** for each modified file, run `git show <SHA> -- <path>` and compare line-by-line against the task's specified content. Pay attention to:
   - Verbatim blocks (if the task says "exactly this content", any deviation matters)
   - Frontmatter or schema fields (missing required fields = violation)
   - Off-by-one section placements (inserted in the wrong place = violation)

4. **Verify soft-strip invariant:**

```bash
git diff <base-sha>..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat
```

Empty output = invariant holds. ANY output = violation; flag the specific file.

5. **Distinguish spec violations from judgment calls.** Style choices the task didn't constrain are NOT violations (e.g., the task says "add a section" and the implementer also chose to fix a typo nearby — note the typo fix but don't flag it as a violation unless the task explicitly forbade it).

## What NOT to do

- Do not assess code quality (separate code-quality-reviewer subagent handles that).
- Do not propose improvements.
- Do not trust the implementer's report — read the actual files and diff.

## Output format

End with one of:

- **✅ Spec compliant** + 1-2 sentence confirmation that each task requirement was met.
- **❌ Issues found** + bulleted list of specific deviations with file:line references. Each issue should clearly say: what the task required, what the implementer did, what needs to change.

If the soft-strip invariant fails, that's ALWAYS ❌ regardless of anything else.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/agents/cc-tuned-spec-reviewer.md
git commit -m "feat(cc-tuned): cc-tuned-spec-reviewer subagent"
```

---

## Task 5: cc-tuned-code-quality-reviewer subagent

**Files:**
- Create: `cc-tuned/agents/cc-tuned-code-quality-reviewer.md`

- [ ] **Step 1: Create the agent file**

Create `cc-tuned/agents/cc-tuned-code-quality-reviewer.md` with this content (verbatim):

```markdown
---
name: cc-tuned-code-quality-reviewer
description: Reviews cc-tuned code changes for quality, conventions, and consistency with the four-layer architecture. Flags hook fail-open violations, JSON-vs-plain-text mismatches, and inconsistencies with the failure-mode table.
tools: Read, Bash, Grep
model: sonnet
---

# cc-tuned code quality reviewer

You review code quality after spec compliance has already passed. Your job is to catch bugs, anti-patterns, and convention violations that the spec didn't address explicitly.

## Context you can rely on without being told

- **Repo root:** `C:\dev\superpowers`.
- **Architecture:** four layers documented in `cc-tuned/README.md` `## Architecture` section — platform-detect, session bootstrap, per-prompt skill suggestion, memory-aware skill wrappers.
- **Failure-mode table:** `cc-tuned/README.md` `### Failure-mode quick reference`. New failure modes introduced by code changes should be added.
- **Hook fail-open invariant:** every hook exits 0 with empty output on any error path. Trapping an error and continuing without surfacing it elsewhere is the FAIL-OPEN PATTERN, not a defect.
- **Hook plain-text invariant:** `cc-user-prompt-submit` MUST emit plain text (cat heredoc) for UserPromptSubmit events. JSON envelopes trigger bug #17550. Other hooks (SessionStart) DO use the JSON envelope. Mismatch is a defect.
- **Test conventions:** `cc-tuned/tests/hooks/` for hook tests, `cc-tuned/tests/skills/` for skill structure tests, `cc-tuned/tests/agents/` for subagent frontmatter tests. Each follows the assert-style format in `test-cc-user-prompt-submit.sh`.

## The controller gives you

- Base SHA + Head SHA bracketing the change under review.
- A short description of what the change accomplishes.
- A pointer to the plan/spec for the work.

## Your job

1. **Read the diff:**

```bash
git diff <BASE_SHA>..<HEAD_SHA>
git diff <BASE_SHA>..<HEAD_SHA> --stat
```

2. **Per-file quality assessment.** For each changed file ask:
   - Does this file have one clear responsibility? (Or did the change pile on unrelated concerns?)
   - Do names match what the code does (not how it works)?
   - Are there silent failures (`|| true`, swallowed exceptions) that should surface or trap differently?
   - Are comments load-bearing (explain WHY when non-obvious) or noise (restate the code)?

3. **cc-tuned-specific checks:**
   - **Hook code:** confirm `set -u` is set, platform-detect is called first, errors exit 0 (fail-open), no unquoted variable expansions.
   - **Hook keyword-table changes:** confirm a corresponding audit doc was added under `cc-tuned/docs/audits/<date>-*.md` OR the existing audit was updated. See `cc-tuned/docs/keyword-table-maintenance.md` for the procedure.
   - **Memory-aware skill body:** confirm it wraps an upstream skill (does not duplicate prose) and includes both RECALL and COMMIT-offer phases.
   - **Subagent body:** confirm frontmatter has required fields and tool list is minimal (no Web tools, no MCP tools unless justified).
   - **Test additions:** confirm at least one positive case AND one negative case for any new behavior.

4. **Forward concerns:** flag concerns the spec reviewer wouldn't catch — e.g., "this introduces a false-positive in the keyword hook that the test suite doesn't exercise," or "this comment will rot when X changes."

## Output format

```
Strengths: <2-4 bullets>
Issues:
  Critical: <must fix before merge — defects, broken invariants, security>
  Important: <should fix — silent failures, missing tests, convention violations>
  Minor: <nice to have — style, comment quality, naming>
Assessment: APPROVED | NEEDS CHANGES
```

If you find no critical or important issues, mark APPROVED even with minor notes. Reserve NEEDS CHANGES for material defects.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/agents/cc-tuned-code-quality-reviewer.md
git commit -m "feat(cc-tuned): cc-tuned-code-quality-reviewer subagent"
```

---

## Task 6: cc-tuned-hook-tester subagent

**Files:**
- Create: `cc-tuned/agents/cc-tuned-hook-tester.md`

- [ ] **Step 1: Create the agent file**

Create `cc-tuned/agents/cc-tuned-hook-tester.md` with this content (verbatim):

```markdown
---
name: cc-tuned-hook-tester
description: Runs the cc-tuned test suite and diagnoses failures against the per-event JSON contracts. Knows how to pipe synthetic prompt JSON to each hook and verify expected output shape.
tools: Read, Bash
model: haiku
---

# cc-tuned hook tester

You run the cc-tuned test suite and report failures with enough detail that the implementer can fix them on the first try.

## Context you can rely on without being told

- **Repo root:** `C:\dev\superpowers`.
- **Test entry point:** `bash cc-tuned/tests/run-all.sh` — runs all Tier 1 + Tier 2 tests.
- **Test files:**
  - `cc-tuned/tests/hooks/test-platform-detect.sh` — platform detection unit test
  - `cc-tuned/tests/hooks/test-mcp-introspect.sh` — MCP server discovery from settings.json
  - `cc-tuned/tests/hooks/test-json-emit.sh` — JSON envelope helpers
  - `cc-tuned/tests/hooks/test-cc-session-start.sh` — session bootstrap hook
  - `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` — per-prompt skill suggestion hook
  - `cc-tuned/tests/skills/test-skill-frontmatter.sh` — Tier 2 skill structure validation
  - `cc-tuned/tests/agents/test-agent-frontmatter.sh` — Tier 2 subagent structure validation (M6)
- **Green output:** ends with `All test files passed.` and a count of N/N test files passed.
- **JSON contracts** (research at `cc-tuned/docs/cc-hook-json-contracts-research.md`):
  - SessionStart: emit `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}` on stdout.
  - UserPromptSubmit: emit PLAIN TEXT on stdout (NOT JSON — bug #17550).
  - Both fail open: exit 0 with empty stdout on any error.

## The controller gives you

- A goal (usually: "run the suite and confirm green" or "diagnose this failure").
- Optionally a commit SHA bracket (for running tests at a specific state).

## Your job — for a green-confirmation run

1. Run `bash cc-tuned/tests/run-all.sh` from repo root.
2. Capture the last 10-15 lines of output.
3. If the final line is `All test files passed.` and the count summary matches expectations, report **PASSED** with the counts.
4. If not, switch to the diagnostic flow below.

## Your job — for a failure-diagnostic run

1. Run the full suite first to see all failures.
2. For each failing test:
   - Read the test file to understand the assertion.
   - Manually reproduce the failing assertion by running just the offending command (e.g., `printf '%s' '{"prompt":"X"}' | bash cc-tuned/hooks/cc-user-prompt-submit` to inspect raw output).
   - Compare actual vs expected output character-by-character if necessary.
3. Classify each failure:
   - **Implementation defect** — the hook produces wrong output for a valid input.
   - **Contract drift** — the test expects the old contract; the new behavior is actually correct but the test wasn't updated.
   - **Environment issue** — missing binary, wrong working directory, permission problem (rare in CI; common in local).
4. Report each failure as a separate item with:
   - Test name and assertion that failed
   - Actual output (truncated to first 500 chars if long)
   - Expected output
   - Your classification + one-sentence rationale
   - Suggested fix (which file to edit, which line, what to change)

## Output format

```
Suite result: PASSED | FAILED (<N> failures)
Test files: <passed>/<total>

[For PASSED, stop here.]

Failures (if FAILED):
1. <test-name>
   Assertion: <what was being tested>
   Actual: <observed output>
   Expected: <required output>
   Classification: implementation defect | contract drift | environment issue
   Suggested fix: <specific>
2. ...
```

## What NOT to do

- Do not modify any test file or hook to "make tests pass" — that's the implementer's job.
- Do not propose architectural changes — code-quality-reviewer handles that.
- Do not skip flaky failures — flakiness is a real defect, report it.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/agents/cc-tuned-hook-tester.md
git commit -m "feat(cc-tuned): cc-tuned-hook-tester subagent"
```

---

## Task 7: Register subagents in plugin.json

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Read the current manifest**

```bash
cat .claude-plugin/plugin.json
```

Confirm the file currently looks like:

```json
{
  "name": "superpowers",
  ...
  "skills": "./cc-tuned/skills/"
}
```

- [ ] **Step 2: Add the agents field using the Edit tool**

The current last property in the JSON object is `"skills": "./cc-tuned/skills/"`. Edit the file to add a comma after that value and a new line with the `agents` declaration. The final manifest should end:

```json
{
  ...
  "skills": "./cc-tuned/skills/",
  "agents": "./cc-tuned/agents/"
}
```

Use the Edit tool to replace the line:

```
"skills": "./cc-tuned/skills/"
```

with:

```
"skills": "./cc-tuned/skills/",
  "agents": "./cc-tuned/agents/"
```

(preserving the existing indentation — two spaces in this manifest).

- [ ] **Step 3: Verify the JSON is still valid**

```bash
cat .claude-plugin/plugin.json
```

Confirm visually that it's syntactically valid (brackets balanced, commas correct). Then validate by piping through Python or jq if available:

```bash
python -c "import json,sys; json.load(open('.claude-plugin/plugin.json')); print('valid')" 2>&1
```

Expected: `valid`. If Python is unavailable, fall back to:

```bash
node -e "JSON.parse(require('fs').readFileSync('.claude-plugin/plugin.json')); console.log('valid')" 2>&1
```

If neither is available, do a manual visual check — the file is small.

- [ ] **Step 4: Run the test suite (regression check)**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `All test files passed.` This change shouldn't break anything; it just registers a new component path.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "feat(cc-tuned): register cc-tuned/agents/ in plugin.json (M6)"
```

---

## Task 8: Tier 2 frontmatter validator for subagents

**Files:**
- Create: `cc-tuned/tests/agents/test-agent-frontmatter.sh`

**Why TDD-ish:** The validator is itself a test. We write the validator and then run it against the four agent files committed in Tasks 3-6. If the validator passes, we have evidence the frontmatter is well-formed. If it fails, the implementer fixes either the validator or the agent file.

- [ ] **Step 1: Create the validator script**

Create `cc-tuned/tests/agents/test-agent-frontmatter.sh` with this content (verbatim):

```bash
#!/usr/bin/env bash
# Tier 2 validator for cc-tuned/agents/*.md
#
# Contract:
#   - Each agent .md file has a YAML frontmatter block (--- delimited)
#   - Required frontmatter fields: name, description, tools, model
#   - The body (everything after the closing ---) is non-empty
#   - Banned frontmatter fields (silently ignored by CC for plugin subagents,
#     but their presence indicates author confusion): hooks, mcpServers,
#     permissionMode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../../agents"

fail=0
pass=0

echo "test-agent-frontmatter.sh"

if [ ! -d "$AGENTS_DIR" ]; then
    echo "  FAIL: agents directory not found at $AGENTS_DIR"
    exit 1
fi

shopt -s nullglob
agent_files=("$AGENTS_DIR"/*.md)
shopt -u nullglob

if [ "${#agent_files[@]}" -eq 0 ]; then
    echo "  FAIL: no agent files found in $AGENTS_DIR"
    exit 1
fi

for agent_file in "${agent_files[@]}"; do
    agent_name=$(basename "$agent_file" .md)

    # Check frontmatter delimiters
    if ! head -1 "$agent_file" | grep -qF '---'; then
        echo "  FAIL: $agent_name — missing opening frontmatter delimiter"
        fail=$((fail + 1))
        continue
    fi

    # Find the closing delimiter (line number)
    close_line=$(awk '/^---$/ { count++; if (count == 2) { print NR; exit } }' "$agent_file")
    if [ -z "$close_line" ]; then
        echo "  FAIL: $agent_name — missing closing frontmatter delimiter"
        fail=$((fail + 1))
        continue
    fi

    frontmatter=$(sed -n "2,$((close_line - 1))p" "$agent_file")
    body=$(tail -n +$((close_line + 1)) "$agent_file")

    # Required fields
    for field in name description tools model; do
        if ! printf '%s\n' "$frontmatter" | grep -qE "^${field}:"; then
            echo "  FAIL: $agent_name — missing required field: $field"
            fail=$((fail + 1))
            continue 2
        fi
    done

    # Banned fields (CC ignores them on plugin subagents; their presence is
    # an author-confusion signal)
    for field in hooks mcpServers permissionMode; do
        if printf '%s\n' "$frontmatter" | grep -qE "^${field}:"; then
            echo "  FAIL: $agent_name — banned field present: $field (silently ignored on plugin subagents; remove it)"
            fail=$((fail + 1))
            continue 2
        fi
    done

    # Name field matches filename
    name_value=$(printf '%s\n' "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
    if [ "$name_value" != "$agent_name" ]; then
        echo "  FAIL: $agent_name — name field ('$name_value') does not match filename"
        fail=$((fail + 1))
        continue
    fi

    # Body non-empty (>= 3 non-blank lines as a sanity check)
    body_lines=$(printf '%s\n' "$body" | grep -cE '^\S' || true)
    if [ "$body_lines" -lt 3 ]; then
        echo "  FAIL: $agent_name — body has fewer than 3 non-blank lines"
        fail=$((fail + 1))
        continue
    fi

    echo "  pass: $agent_name — frontmatter valid + body non-empty"
    pass=$((pass + 1))
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the validator standalone**

```bash
bash cc-tuned/tests/agents/test-agent-frontmatter.sh
```

Expected: `4 passed, 0 failed` (one pass per agent file from Tasks 3-6).

If a failure surfaces: most likely cause is a frontmatter typo in one of the agent files from earlier tasks. Fix the agent file (not the validator), re-commit it, then re-run.

- [ ] **Step 3: Confirm run-all.sh discovers the new test**

The existing `cc-tuned/tests/run-all.sh` uses a glob to find tests. Check its current discovery pattern:

```bash
grep -E 'find|glob|test-' cc-tuned/tests/run-all.sh | head -20
```

If it uses `find cc-tuned/tests -name 'test-*.sh'` or similar, the new file is auto-discovered. If it uses an explicit per-directory loop that doesn't include `agents/`, edit `run-all.sh` to also iterate `tests/agents/test-*.sh`.

- [ ] **Step 4: Run the full test suite**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: the suite now reports `7 / 7 test files passed` (was 6/6 in M5). Final line: `All test files passed.`

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/tests/agents/test-agent-frontmatter.sh
# If run-all.sh was edited:
# git add cc-tuned/tests/run-all.sh
git commit -m "test(cc-tuned): Tier 2 subagent frontmatter validator"
```

---

## Task 9: cc-tuned/README updates

**Files:**
- Modify: `cc-tuned/README.md`

- [ ] **Step 1: Add new file-map rows for the four agents + research doc + validator**

In `cc-tuned/README.md` find the "What lives here" table. After the existing `tests/skills/test-skill-frontmatter.sh` row, add these rows (in this order — match the existing style):

```markdown
| `agents/cc-tuned-implementer.md` | M6: TDD-disciplined implementer subagent (knows soft-strip + four layers) |
| `agents/cc-tuned-spec-reviewer.md` | M6: spec-compliance reviewer subagent |
| `agents/cc-tuned-code-quality-reviewer.md` | M6: code-quality reviewer subagent |
| `agents/cc-tuned-hook-tester.md` | M6: hook-test runner + failure-diagnostic subagent |
| `tests/agents/test-agent-frontmatter.sh` | Tier 2 validator: subagent .md frontmatter + tools list + no banned fields |
| `docs/cc-plugin-subagents-declaration-research.md` | Decision record on plugin.json agents field (M6) |
```

- [ ] **Step 2: Add a `## Subagents` section after `## Architecture`**

Find the end of the `## Architecture` section (the line just before `## What lives here`). Insert a new section before `## What lives here`:

```markdown
## Subagents

Four dedicated subagents at `cc-tuned/agents/` bake in the soft-strip invariant and four-layer architecture so subagent-driven cc-tuned PRs don't re-paste context into every dispatch.

| Subagent | Role | Default model |
|----------|------|---------------|
| `superpowers:cc-tuned-implementer` | TDD-disciplined implementer for cc-tuned plan tasks | `sonnet` |
| `superpowers:cc-tuned-spec-reviewer` | Spec-compliance review with soft-strip invariant check | `haiku` |
| `superpowers:cc-tuned-code-quality-reviewer` | Code-quality review against cc-tuned conventions | `sonnet` |
| `superpowers:cc-tuned-hook-tester` | Runs the test suite + diagnoses failures | `haiku` |

These replace `general-purpose` for cc-tuned PRs only. For ad-hoc work outside the cc-tuned layer, `general-purpose` remains the right choice. Registration is a single `"agents": "./cc-tuned/agents/"` entry in `.claude-plugin/plugin.json` — same additive pattern as M3's `skills` registration.
```

- [ ] **Step 3: Update the M5 status row and add an M6 row**

Find the existing M5 status row:

```markdown
| M5 Polish & Docs | **in progress** | audit + maintenance procedure + arch narrative shipped; fork README + gitconfig aliases (optional) + upstream-merge playbook (blocked on M4) still open |
```

Leave it unchanged (M5 still has open optional sub-tasks). Add a new M6 row immediately after it:

```markdown
| M6 Dedicated Subagents | **in progress** | four cc-tuned-* subagents registered via plugin.json agents field |
```

(After this PR merges, you'll update both rows in the worked-example PR or in a follow-up. For now, "in progress" reflects that M6 ships its core but Tier 3 smoke test happens post-merge.)

- [ ] **Step 4: Add a Tier 3 smoke-test check for `/agents` discovery**

In the existing "Manual smoke test (Tier 3)" section, find the existing `### Check 4: memory-aware skill activation (M3)` block. After it, add a new check:

```markdown
### Check 5: subagent discovery (M6)

Open a fresh CC session with the plugin loaded. Run `/agents` (or use the agent picker in your CC harness). Confirm the typeahead lists these four:

- `superpowers:cc-tuned-implementer`
- `superpowers:cc-tuned-spec-reviewer`
- `superpowers:cc-tuned-code-quality-reviewer`
- `superpowers:cc-tuned-hook-tester`

If any are missing, verify `.claude-plugin/plugin.json` has `"agents": "./cc-tuned/agents/"` and that the four .md files exist under `cc-tuned/agents/` with valid frontmatter (`bash cc-tuned/tests/agents/test-agent-frontmatter.sh` should pass).
```

- [ ] **Step 5: Verify the diff is scoped correctly**

```bash
git diff cc-tuned/README.md
```

Expected: four edits — file-map table rows added, new `## Subagents` section inserted, status table gets new M6 row, smoke-test gets new Check 5. No other lines touched.

- [ ] **Step 6: Run tests**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `7 / 7 test files passed.`

- [ ] **Step 7: Commit**

```bash
git add cc-tuned/README.md
git commit -m "docs(cc-tuned): document M6 subagents in cc-tuned/README"
```

---

## Task 10: Push branch and open PR

**Files:** none (git/gh operations only)

- [ ] **Step 1: Final soft-strip check**

```bash
git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat
```

Expected: ONE file shown — `.claude-plugin/plugin.json` (the only upstream-coupled change in this PR). Anything else outside that file = soft-strip violation; stop and investigate.

- [ ] **Step 2: Full test pass on the branch**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `7 / 7 test files passed.`

- [ ] **Step 3: Push the branch**

```bash
git push -u origin feature/m6-dedicated-subagents
```

- [ ] **Step 4: Comment on issue #10**

```bash
gh issue comment 10 --repo rsx129921/superpowers --body "M6 in flight on branch \`feature/m6-dedicated-subagents\`. PR opens with: research doc, §8 spec update, four cc-tuned-* subagents, plugin.json registration, Tier 2 frontmatter validator, README updates. Worked-example PR (adopting these subagents in place of general-purpose) deferred to a follow-up per acceptance criteria."
```

- [ ] **Step 5: Open the PR**

```bash
gh pr create --repo rsx129921/superpowers --base main --head feature/m6-dedicated-subagents \
  --title "feat(cc-tuned): M6 dedicated cc-tuned subagents (implementer + 3 reviewers)" \
  --body "$(cat <<'EOF'
## Summary

Closes #10's core scope (worked-example PR is the follow-up). Adds four cc-tuned-specific subagents registered via `.claude-plugin/plugin.json`'s `agents` field:

- `superpowers:cc-tuned-implementer` — TDD-disciplined implementer (sonnet)
- `superpowers:cc-tuned-spec-reviewer` — spec compliance + soft-strip diff check (haiku)
- `superpowers:cc-tuned-code-quality-reviewer` — cc-tuned-convention review (sonnet)
- `superpowers:cc-tuned-hook-tester` — test runner + failure diagnostics (haiku)

Each bakes in the soft-strip invariant, the four-layer architecture, and the relevant hook/test conventions so future cc-tuned PRs use them in place of `general-purpose` with minimal per-dispatch context.

## Soft-strip invariant

Still exactly two upstream files diverge from `obra/superpowers`: `hooks/hooks.json` (unchanged in this PR) and `.claude-plugin/plugin.json` (gains the `"agents": "./cc-tuned/agents/"` entry next to the M3 `"skills"` entry).

Verify: `git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat` shows only `.claude-plugin/plugin.json`.

## What ships

- `cc-tuned/agents/cc-tuned-implementer.md`
- `cc-tuned/agents/cc-tuned-spec-reviewer.md`
- `cc-tuned/agents/cc-tuned-code-quality-reviewer.md`
- `cc-tuned/agents/cc-tuned-hook-tester.md`
- `cc-tuned/tests/agents/test-agent-frontmatter.sh` — Tier 2 validator (4 passes added, suite now 7/7)
- `cc-tuned/docs/cc-plugin-subagents-declaration-research.md` — decision record
- `.claude-plugin/plugin.json` — adds `agents` entry
- `cc-tuned/README.md` — new `## Subagents` section, M6 status row, Tier 3 Check 5 for `/agents` discovery
- `docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md` — new §8 covering motivation, scope, registration, role boundaries

## Test plan

- [x] `bash cc-tuned/tests/run-all.sh` ends with `All test files passed.` (7/7 files)
- [x] Frontmatter validator covers all four agents
- [x] Soft-strip invariant verified
- [ ] Tier 3 smoke test (post-merge): `/agents` in a fresh CC session lists the four `superpowers:cc-tuned-*` entries

## Out of scope (follow-up)

Per #10 acceptance criteria, the worked-example PR that adopts these subagents in place of `general-purpose` for a real cc-tuned task is the FIRST cc-tuned PR after this merges, not part of M6 itself.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Verify PR is open**

```bash
gh pr view --repo rsx129921/superpowers --json url,state
```

Expected: state `OPEN`, URL printed.

---

## Self-Review Notes

Completed inline below.

**1. Spec coverage:** The brainstormed design called for:
- Four subagents (implementer + 3 reviewers) → Tasks 3-6 ✓
- Plugin.json registration via `agents` field → Task 7 ✓
- Tier 2 frontmatter validator mirroring M3's pattern → Task 8 ✓
- §8 spec update with motivation/scope/registration/boundary → Task 2 ✓
- Research decision record → Task 1 ✓
- cc-tuned/README Subagents section + Tier 3 smoke check → Task 9 ✓
- Soft-strip invariant preserved (only plugin.json touches upstream) → verified Task 10 Step 1 ✓
- PR + issue comment → Task 10 ✓

All design elements have at least one implementing task. ✓

**2. Placeholder scan:** No `TBD`/`TODO`/"implement later" in plan steps. Each agent body is fully written; the plugin.json edit is shown literally; the validator script is complete. ✓

**3. Type consistency:** All subagent names match across tasks: `cc-tuned-implementer`, `cc-tuned-spec-reviewer`, `cc-tuned-code-quality-reviewer`, `cc-tuned-hook-tester` are used consistently in tasks, README updates, plugin.json registration, and validator references. The frontmatter `name` field equals the filename basename in all four agents. ✓

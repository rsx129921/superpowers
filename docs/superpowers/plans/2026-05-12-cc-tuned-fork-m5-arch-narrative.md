# CC-Tuned Fork — M5 Architecture Narrative Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `## Architecture` section to `cc-tuned/README.md` (between `## Status` and `## What lives here`) covering how the four layers — platform detection, session bootstrap, per-prompt skill suggestion, memory-aware skill wrappers — compose at runtime.

**Architecture:** Single-file change. New section inserted by Edit tool. Includes four sub-sections (one per layer) plus a small ASCII runtime-flow diagram showing fresh-session vs. per-prompt vs. skill-firing chains.

**Tech Stack:** Markdown.

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md) §6 (M5 Polish & Docs).

**Umbrella issue:** [#5](https://github.com/rsx129921/superpowers/issues/5) — the arch-narrative sub-task. Two other unblocked sub-tasks (optional gitconfig aliases, optional fork-level README) are deferred to later PRs; the upstream-merge playbook stays blocked on M4. After this PR, #5 stays open for those three items.

**Built on top of:** M5 audit PR (#11, merged at `0e6e45e` on 2026-05-11). No new code or tests — pure documentation.

---

## File Structure

**Modified in this plan:**

| Path | Change |
|------|--------|
| `cc-tuned/README.md` | Insert new `## Architecture` section between lines 15 and 17 (between `## Status` and `## What lives here`). Update the status table M5 row to reflect arch-narrative shipped. |

**Out of scope:**
- Gitconfig aliases section (separate PR if pursued)
- Fork-level README banner (recommend skipping per soft-strip; tracked in #5)
- Upstream-merge playbook (blocked on M4)

---

## Task 1: Add Architecture section + update status row

**Files:**
- Modify: `cc-tuned/README.md`

- [ ] **Step 1: Create feature branch**

```bash
git checkout main
git pull origin main
git checkout -b feature/m5-arch-narrative
```

Expected: branch created, tracking implied for first push.

- [ ] **Step 2: Insert the Architecture section using the Edit tool**

In `cc-tuned/README.md`, find the line:

```markdown
See [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md) for the full design.
```

(this is the last line of the `## Status` section, currently line 15).

After that line, insert a blank line and then this entire block:

```markdown
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
```

- [ ] **Step 3: Update the M5 status table row**

In `cc-tuned/README.md`, find the existing M5 status table row:

```markdown
| M5 Polish & Docs | **in progress** | audit + maintenance procedure shipped; arch narrative + fork README + gitconfig aliases + upstream-merge playbook still open |
```

Replace with:

```markdown
| M5 Polish & Docs | **in progress** | audit + maintenance procedure + arch narrative shipped; fork README + gitconfig aliases (optional) + upstream-merge playbook (blocked on M4) still open |
```

- [ ] **Step 4: Verify the diff is scoped correctly**

```bash
git diff cc-tuned/README.md
```

Expected: only the new `## Architecture` section is inserted (single hunk between `## Status` and `## What lives here`), and the M5 status row is updated. No other changes.

- [ ] **Step 5: Verify soft-strip invariant**

```bash
git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat
```

Expected: empty output. (`docs/superpowers/plans/2026-05-12-cc-tuned-fork-m5-arch-narrative.md` is under `docs/superpowers/` so it's excluded.)

- [ ] **Step 6: Commit**

```bash
git add cc-tuned/README.md
git commit -m "docs(cc-tuned): add Architecture section to cc-tuned/README (M5)"
```

- [ ] **Step 7: Quick rendering sanity check**

```bash
head -120 cc-tuned/README.md
```

Confirm the new section appears between Status and What-lives-here, the four sub-sections are present, and the ASCII flow diagram renders without escape-character corruption.

- [ ] **Step 8: Run the test suite (regression check)**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `All test files passed.` This is a docs-only change so nothing should break, but verify.

---

## Task 2: Push branch and open PR

**Files:** none (git/gh operations only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feature/m5-arch-narrative
```

Expected: push succeeds, branch tracks origin.

- [ ] **Step 2: Comment on issue #5 noting which sub-task this addresses**

```bash
gh issue comment 5 --repo rsx129921/superpowers --body "Arch-narrative sub-task in flight on branch \`feature/m5-arch-narrative\`. PR incoming. After merge, remaining M5 sub-tasks are: optional gitconfig aliases, optional fork-level README banner (recommend skipping per soft-strip), and the M4-blocked upstream-merge playbook."
```

- [ ] **Step 3: Open the PR**

```bash
gh pr create --repo rsx129921/superpowers --base main --head feature/m5-arch-narrative \
  --title "docs(cc-tuned): add Architecture section to cc-tuned README (M5)" \
  --body "$(cat <<'EOF'
## Summary

Addresses the arch-narrative sub-task of #5. Adds an `## Architecture` section to `cc-tuned/README.md` (placed between `## Status` and `## What lives here`) that walks through the four-layer composition at runtime: platform detection → session bootstrap → per-prompt skill suggestion → memory-aware skill wrappers. Includes a small ASCII flow diagram showing the fresh-session, per-prompt, and skill-firing chains.

Pure documentation. No code or test changes.

## What's still open in #5

- Optional gitconfig aliases (deferred)
- Optional fork-level README banner — recommend skipping to preserve the soft-strip invariant (currently exactly 2 upstream files diverge from `obra/superpowers`)
- Upstream-merge playbook with worked example — blocked on M4

## Soft-strip invariant check

`git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat` is empty.

## Test plan

- [x] `bash cc-tuned/tests/run-all.sh` ends with `All test files passed.` (no regressions; this is a docs-only change)
- [x] New section renders cleanly between Status and What-lives-here
- [x] ASCII flow diagram doesn't have escape-character corruption
- [ ] Tier 3 smoke test in a real CC session — N/A for this PR (no behavior change)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL returned.

- [ ] **Step 4: Final verification**

```bash
gh pr view --repo rsx129921/superpowers --json url,state,statusCheckRollup
```

Expected: state `OPEN`, URL printed. (No CI configured on this fork at the moment, so no rollup statuses to wait for.)

---

## Self-Review Notes

Completed inline.

**1. Spec coverage:** The spec's §6 (M5 Polish & Docs) calls out "architecture overview, how the three hooks interact, MCP introspection mechanism" as the arch-narrative content. Task 1 Step 2's section covers all three: Layer 2 covers the MCP introspection, Layers 2+3 cover the hook interactions, and Layer 4 closes the loop with how the memory-aware skills consume the directive. The runtime-flow diagram makes the cross-layer composition visible. ✓

**2. Placeholder scan:** No `TBD`/`TODO`/"implement later" in plan steps. The single intentional placeholder language in the doc itself ("(blocked on M4)" for the playbook) reflects real blocking, not deferred work. ✓

**3. Type consistency:** N/A — pure prose doc, no type definitions or signatures.

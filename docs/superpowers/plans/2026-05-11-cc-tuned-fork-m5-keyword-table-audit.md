# CC-Tuned Fork — M5 Keyword-Table Audit + Maintenance Procedure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit every keyword pattern in `cc-tuned/hooks/cc-user-prompt-submit` against real and synthetic prompts, tune the table where false positives are confirmed, and document the maintenance procedure so future-you (or anyone else) can repeat the audit in one sitting.

**Architecture:** Two deliverable docs plus conditional hook tuning. The audit is a point-in-time snapshot (`cc-tuned/docs/audits/2026-05-11-keyword-table.md`); the maintenance procedure is evergreen (`cc-tuned/docs/keyword-table-maintenance.md`). Hook changes only happen if the audit surfaces patterns with ≥2 unambiguous false positives. Each per-skill audit pass is its own task (and commit) so per-skill work can be re-run independently.

**Tech Stack:** Markdown for both docs. Bash one-liners piping JSON to the existing `cc-user-prompt-submit` hook for the theoretical false-positive checks. `mcp__plugin_episodic-memory_episodic-memory__search` for the empirical pass (only available during execution — record findings, not raw search output).

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md) §6 (M5 Polish & Docs) and §2.2 (keyword table design).

**Umbrella issue:** [#5](https://github.com/rsx129921/superpowers/issues/5)

**Built on top of:** M2 (cc-user-prompt-submit, merged 2026-05-11 at 491b14b) — the audited hook. The keyword table has not changed since M2 ship.

---

## File Structure

**Created in this plan:**

| Path | Responsibility |
|------|----------------|
| `cc-tuned/docs/audits/2026-05-11-keyword-table.md` | One-shot audit findings: per-keyword classification, recommendations, link to any hook changes that resulted |
| `cc-tuned/docs/keyword-table-maintenance.md` | Evergreen procedure: how to add/remove/tighten patterns, how to run a false-positive sweep, the tuning bar |

**Conditionally modified (only if audit recommends changes):**

| Path | Change |
|------|--------|
| `cc-tuned/hooks/cc-user-prompt-submit` | Remove or tighten keywords with ≥2 unambiguous false positives |
| `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` | Add negative test cases that previously matched but no longer should |

**Modified at the end:**

| Path | Change |
|------|--------|
| `cc-tuned/README.md` | M5 status: add a line under the status table noting partial M5 (audit + maintenance) shipped; full M5 still has arch narrative, fork-README, gitconfig aliases, and the blocked playbook sub-task |

**Out of scope (deferred to later M5 PRs):**
- Architecture narrative in `cc-tuned/README.md`
- Fork-level `README.md`
- `.gitconfig` aliases
- Upstream-merge playbook (blocked on M4, which is itself blocked on upstream releasing past `f2cbfbe`)

---

## Task 1: Stub the audit document

**Files:**
- Create: `cc-tuned/docs/audits/2026-05-11-keyword-table.md`

**Why this is first:** Lock in the audit's structure before doing the analysis. Pre-filling the keyword column means subsequent tasks just fill cells, not freestyle.

- [ ] **Step 1: Create the audits directory and audit doc with header + methodology + empty per-skill tables**

Create `cc-tuned/docs/audits/2026-05-11-keyword-table.md` with this content:

```markdown
# Keyword Table Audit — 2026-05-11

**Audited file:** `cc-tuned/hooks/cc-user-prompt-submit`
**Hook last changed:** M2 ship (commit 491b14b, 2026-05-11)
**Auditor:** rsx129921
**Method:** combined episodic-memory empirical pass + theoretical false-positive enumeration. Per pattern: search episodic for prompts containing the keyword, classify up to 10 hits as true-positive / false-positive / ambiguous; then hand-craft 3 theoretical false-positive prompts and pipe them through the live hook to verify match behavior.

## Tuning bar

- **Remove** if ≥2 unambiguous false positives AND removal doesn't strand a common true-positive case
- **Tighten** (replace with phrase or regex) if removal would strand true-positives but a narrower form would not
- **Keep** if episodic shows mostly true-positives and theoretical false-positives feel contrived

Bias: the hook's design comment says "false negatives are fine; false positives erode the signal value." Lean toward remove/tighten when in doubt.

## Per-skill findings

### superpowers:brainstorming

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `let's build` | | | | | | |
| `let's make` | | | | | | |
| `let's create` | | | | | | |
| `new feature` | | | | | | |

### superpowers:systematic-debugging

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `failing` | | | | | | |
| `broken` | | | | | | |
| `bug` | | | | | | |
| `doesn't work` | | | | | | |
| `why is this` | | | | | | |
| `test.*fail` (regex) | | | | | | |

### superpowers:test-driven-development

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `add tests` | | | | | | |
| `tdd` | | | | | | |
| `test first` | | | | | | |
| `write tests` | | | | | | |

### superpowers:writing-plans

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `write a plan` | | | | | | |
| `write a spec` | | | | | | |
| `draft a plan` | | | | | | |
| `implementation plan` | | | | | | |
| `design doc` | | | | | | |

## Summary of recommendations

_To be filled in Task 6 after all four per-skill passes complete._

## Hook changes applied

_To be filled in Task 7 if the audit triggers any. If no changes apply, this section says "No hook changes — audit confirms all patterns within tuning bar."_
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): stub M5 keyword-table audit doc"
```

---

## Task 2: Audit brainstorming patterns

**Files:**
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill the four brainstorming rows)

**Why this is one task per skill:** Each skill's keyword set is independent. A commit per skill makes per-pattern work easy to revisit or revert.

- [ ] **Step 1: Episodic search for each of the 4 brainstorming keywords**

For each keyword `let's build`, `let's make`, `let's create`, `new feature`:

Run via the episodic-memory MCP tool:
```
mcp__plugin_episodic-memory_episodic-memory__search with query="<keyword>"
```

For each result returned (up to 10 per keyword), open the conversation context and classify the user-prompt that contained the match as:
- `true-positive` — the user was actually starting feature/component creation; brainstorming firing would help
- `false-positive` — the user was using the phrase conversationally / informationally; brainstorming firing would be intrusive
- `ambiguous` — could go either way

Record raw counts (not the prompts themselves — that would leak PII into the audit doc).

- [ ] **Step 2: Theoretical false-positive check for each pattern**

For each of the 4 patterns, write 3 hand-crafted prompts that contain the keyword but should NOT trigger brainstorming. Examples to start from (revise based on what looks plausible for your real usage):

```bash
# let's build
printf '%s' '{"prompt":"let'\''s build on the previous point you made"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s build a mental model of how this works"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s build consensus first"}' | bash cc-tuned/hooks/cc-user-prompt-submit

# let's make
printf '%s' '{"prompt":"let'\''s make sure we understand the constraints"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s make this clear: I want X not Y"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s make a decision and move on"}' | bash cc-tuned/hooks/cc-user-prompt-submit

# let's create
printf '%s' '{"prompt":"let'\''s create some space in the conversation for that"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s create a shared vocabulary"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"let'\''s create a checklist"}' | bash cc-tuned/hooks/cc-user-prompt-submit

# new feature
printf '%s' '{"prompt":"this is a new feature of Python 3.12"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"the new feature in our roadmap is auth"}' | bash cc-tuned/hooks/cc-user-prompt-submit
printf '%s' '{"prompt":"docs for the new feature look incomplete"}' | bash cc-tuned/hooks/cc-user-prompt-submit
```

Expected: each of these prints the brainstorming-injection text (confirming the hook matched). Count = 3 false positives per pattern if all 3 match.

A non-match would print nothing. Record the actual count.

- [ ] **Step 3: Fill rows in the audit doc**

Edit `cc-tuned/docs/audits/2026-05-11-keyword-table.md` and fill the four rows in the brainstorming table with the numbers and a one-line recommendation (`keep` / `tighten: <suggested replacement>` / `remove`). Leave the Notes column for anything unusual found in the episodic sample.

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): audit findings for brainstorming keywords"
```

---

## Task 3: Audit systematic-debugging patterns

**Files:**
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill the six debugging rows)

- [ ] **Step 1: Episodic search for each pattern**

For `failing`, `broken`, `bug`, `doesn't work`, `why is this`, regex `test.*fail`:

For the regex `test.*fail`, search episodic for prompts containing both `test` and `fail` and manually grep results for the regex. Classify up to 10 per pattern.

- [ ] **Step 2: Theoretical false-positive check**

Starter list (revise to taste, then run each via the same `printf | bash` pattern from Task 2):

- `failing` — `"my plan is failing to come together"`, `"the lighting in this room is failing"`, `"failing to see your point"`
- `broken` — `"broken English"`, `"a broken promise"`, `"this argument feels broken"`
- `bug` — `"there's a bug in this rhetorical argument"`, `"the bug report needs updating"`, `"don't bug me about it"`
- `doesn't work` — `"my keyboard doesn't work"`, `"that excuse doesn't work for me"`, `"the metaphor doesn't work"`
- `why is this` — `"why is this approach preferred?"`, `"why is this even controversial?"`, `"why is this taking so long to ship"`
- `test.*fail` — `"the test for that hypothesis would fail by design"`, `"a test of will, where most fail"`, `"that test failed to convince me"`

- [ ] **Step 3: Fill rows in the audit doc**

Same pattern as Task 2 Step 3.

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): audit findings for systematic-debugging keywords"
```

---

## Task 4: Audit TDD patterns

**Files:**
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill the four TDD rows)

- [ ] **Step 1: Episodic search**

For `add tests`, `tdd`, `test first`, `write tests`. These are short phrases — search and classify.

- [ ] **Step 2: Theoretical false-positive check**

Starter list:
- `add tests` — `"should I add tests to this list?"` (rare), `"who's going to add tests of the new metric to the dashboard"` (rare). This pattern is likely safe — record what you find.
- `tdd` — `"tdd is mentioned in the slack thread"`, `"I disagree with the strict tdd interpretation"`, `"the article on tdd"`. Pattern is acronym-y; collisions are mostly the topic word itself.
- `test first` — `"let's test first whether the user wants this"` (rare), `"in the test, first I check X"` (false-positive risk via word order). 
- `write tests` — `"the article said to write tests"`, `"how do you write tests for legacy code conceptually"`, `"write tests of attention before X"`. 

- [ ] **Step 3: Fill rows**

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): audit findings for TDD keywords"
```

---

## Task 5: Audit writing-plans patterns

**Files:**
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill the five writing-plans rows)

- [ ] **Step 1: Episodic search**

For `write a plan`, `write a spec`, `draft a plan`, `implementation plan`, `design doc`. Classify hits.

- [ ] **Step 2: Theoretical false-positive check**

Starter list:
- `write a plan` — `"can you write a plan summary for me"` (this is actually a true-positive ask), `"i need to write a plan for my vacation"`, `"how would you write a plan for someone new to TDD"`.
- `write a spec` — `"who's supposed to write a spec for this ticket"` (usually still TP), `"don't write a spec, just prototype"`, `"i'd rather write a spec by hand than use a template"`.
- `draft a plan` — typically TP. `"draft a plan B in case X fails"` is borderline.
- `implementation plan` — `"the implementation plan from last sprint"`, `"per the implementation plan we agreed to"`, `"is there an implementation plan doc somewhere"`.
- `design doc` — `"the design doc says X"`, `"i'm reading the design doc"`, `"link to the design doc?"`.

Note: `design doc` and `implementation plan` look high-risk for "referencing the artifact" false-positives.

- [ ] **Step 3: Fill rows**

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): audit findings for writing-plans keywords"
```

---

## Task 6: Synthesize recommendations summary

**Files:**
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill the "Summary of recommendations" section)

- [ ] **Step 1: Re-read all four per-skill tables**

Compile the recommendation column into a flat list, grouped by action.

- [ ] **Step 2: Write the summary section**

Replace the placeholder with three subsections in the audit doc:

```markdown
## Summary of recommendations

### Patterns to remove
- `<pattern>` (skill: `<skill>`) — <one-line reason based on FP counts>

### Patterns to tighten
- `<pattern>` → `<replacement>` (skill: `<skill>`) — <one-line reason and what the replacement preserves>

### Patterns to keep
- All others (list the keepers explicitly or say "the remaining N patterns").

### Net effect on hook signal
<2-3 sentences: estimated reduction in false-positive rate, any new false-negatives introduced, whether overall match rate goes up or down in practice.>
```

If no patterns warrant removal or tightening, write that explicitly: "Audit confirms all 19 patterns within tuning bar. No hook changes." This is a legitimate outcome and means Task 7 is a no-op.

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "docs(cc-tuned): synthesize keyword-table audit recommendations"
```

---

## Task 7 (conditional): Apply hook tuning via TDD

**Skip entirely if Task 6's summary says "No hook changes."**

**Files:**
- Modify: `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh`
- Modify: `cc-tuned/hooks/cc-user-prompt-submit`
- Modify: `cc-tuned/docs/audits/2026-05-11-keyword-table.md` (fill "Hook changes applied" section)

**Per-pattern TDD loop:** for each pattern flagged for remove or tighten, do this micro-sequence:

- [ ] **Step 1: Read the existing hook test to learn its pattern**

```bash
cat cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh | head -60
```

Note the existing positive-case format. Negative cases should follow the same shape: pipe a prompt, assert the output is empty (no skill suggestion emitted).

- [ ] **Step 2: For each pattern to change, write the failing negative test FIRST**

In `test-cc-user-prompt-submit.sh`, add a new test block per pattern, matching the existing style. Example shape (use the actual style from the existing tests):

```bash
echo "TEST: <pattern> no longer matches conversational use"
OUT=$(printf '%s' '{"prompt":"<the false-positive prompt from your audit>"}' \
    | bash "$REPO_ROOT/cc-tuned/hooks/cc-user-prompt-submit")
if [ -n "$OUT" ]; then
    echo "FAIL: expected no skill suggestion, got: $OUT"
    exit 1
fi
echo "OK"
```

- [ ] **Step 3: Run the test suite — expect new failures**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: the new negative cases fail because the current hook still matches the now-undesired patterns. Confirm the failures are exactly the ones you added (not regressions elsewhere).

- [ ] **Step 4: Edit cc-user-prompt-submit to apply removals and tightenings**

Edit the `case "$PROMPT_LC" in` block to drop removed globs and replace tightened ones. If a pattern moves to regex (no glob expressible), add a new `grep -qE` block below the existing `test.*fail` regex block.

- [ ] **Step 5: Re-run tests — all must pass**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `All test files passed.`

- [ ] **Step 6: Fill "Hook changes applied" in audit doc**

In `cc-tuned/docs/audits/2026-05-11-keyword-table.md`, replace the placeholder with a diff summary:

```markdown
## Hook changes applied

- Removed: `<pattern>` (skill `<skill>`)
- Tightened: `<old>` → `<new>` (skill `<skill>`)
- Added negative tests: <N> cases in test-cc-user-prompt-submit.sh

Patch commit: <sha or "in this PR">
```

- [ ] **Step 7: Commit hook + test changes together**

```bash
git add cc-tuned/hooks/cc-user-prompt-submit cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh cc-tuned/docs/audits/2026-05-11-keyword-table.md
git commit -m "fix(cc-tuned): tune keyword table per M5 audit findings"
```

---

## Task 8: Write the maintenance procedure doc

**Files:**
- Create: `cc-tuned/docs/keyword-table-maintenance.md`

- [ ] **Step 1: Write the maintenance doc**

Create `cc-tuned/docs/keyword-table-maintenance.md` with this content:

```markdown
# Keyword Table Maintenance

The `cc-tuned/hooks/cc-user-prompt-submit` hook fires on every user message and injects a skill-suggestion prompt when the user's text matches a small keyword table. This doc covers how to add, remove, or tighten patterns without eroding the hook's signal quality.

## How the keyword table works

A `case "$PROMPT_LC" in` block in `cc-tuned/hooks/cc-user-prompt-submit` does first-match-wins matching against a lowercased copy of the prompt. There is one additional `grep -qE` regex fallback for patterns that can't be expressed as a glob (currently `test.*fail`). On match, the hook emits a plain-text suggestion + condensed Red Flags list. On no match, the hook exits silently.

The design comment in the hook is explicit: **"false negatives are fine; false positives erode the signal value of the injection itself."** Tune accordingly.

## Adding a new pattern

1. Decide which skill the pattern should trigger. If unclear, the pattern is probably too broad.
2. Pick the narrowest glob (or regex) that catches the cases you care about. Prefer multi-word phrases over single words.
3. Add the glob to the appropriate `case` branch in `cc-tuned/hooks/cc-user-prompt-submit`. First-match-wins means order matters when patterns could overlap across skills — put the more specific pattern first.
4. Add at least one positive test case to `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` following the existing format.
5. Add at least one negative test case using a plausible false-positive prompt.
6. Run `bash cc-tuned/tests/run-all.sh` — must pass.
7. Run a false-positive sweep (procedure below) for the new pattern only, with 3 candidate prompts.
8. Commit hook + tests together.

## Removing or tightening a pattern

**Bar for removing:** ≥2 unambiguous false positives in real usage AND removal doesn't strand a common true-positive case (upstream skill discovery should still catch the intended ones).

**Bar for tightening:** the broad form false-positives, but a narrower phrase or regex would still catch the intended use.

**Procedure:**

1. Identify the negative prompts that should no longer match. Add them as negative test cases to `test-cc-user-prompt-submit.sh` FIRST.
2. Run tests — the new negatives must fail (confirming the current hook still matches them).
3. Edit `cc-user-prompt-submit` to remove or replace the pattern.
4. Re-run tests — all must pass.
5. Update the audit doc (or open a new dated audit doc in `cc-tuned/docs/audits/`) noting what changed and why.
6. Commit hook + tests + audit-doc update together.

## Running a false-positive sweep

Combined episodic + theoretical pass (the method used in the 2026-05-11 audit — see `cc-tuned/docs/audits/2026-05-11-keyword-table.md` as the worked example):

1. **Episodic pass.** For each pattern, search episodic-memory for prompts containing the keyword. Sample up to 10 hits. Classify each as true-positive / false-positive / ambiguous based on what the user was actually doing in that turn. If a pattern has fewer than 3 hits, mark "thin data" and lean more on the theoretical pass.

2. **Theoretical pass.** For each pattern, hand-craft 3 prompts that contain the keyword but should NOT trigger the skill. Pipe each through the live hook:

   ```bash
   printf '%s' '{"prompt":"<your candidate prompt>"}' | bash cc-tuned/hooks/cc-user-prompt-submit
   ```

   A match prints the skill-suggestion text. No match prints nothing. Count matches.

3. **Tabulate.** Per pattern, record episodic TP/FP/AMB counts + theoretical FP count + a one-line recommendation (`keep` / `tighten: <replacement>` / `remove`). The 2026-05-11 audit's tables show the format.

4. **Apply the tuning bar** (above) to decide.

## When NOT to use the keyword table

Upstream skill discovery already routes most prompts to the right skill via SKILL.md descriptions. This hook is for the patterns that benefit from a hard prompt — primarily because the user phrasing is ambiguous to skill-description matching ("let's build X" reads as casual brainstorming to the model, not as a feature-creation trigger).

If you find yourself adding a pattern because the model "should already know" — don't. Either trust skill discovery, or, if discovery is genuinely failing, file an issue against the upstream skill's description rather than papering over it here.

## Audit cadence

There is no schedule. Run a sweep when:
- You add or change a pattern
- You notice the hook firing on prompts it shouldn't (or not firing on prompts it should)
- Before any upstream-sync (M4+) that touches `hooks/hooks.json`, as a sanity check

Each sweep produces a new dated audit doc in `cc-tuned/docs/audits/`. Old audits are retained for historical reference — do not delete or overwrite.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/docs/keyword-table-maintenance.md
git commit -m "docs(cc-tuned): add keyword-table maintenance procedure"
```

---

## Task 9: Update cc-tuned README to reflect partial M5 progress

**Files:**
- Modify: `cc-tuned/README.md`

- [ ] **Step 1: Update the status table**

In `cc-tuned/README.md`, find the status table and change the M5 row from:

```markdown
| M5 Polish & Docs | not started | final README pass |
```

to:

```markdown
| M5 Polish & Docs | **in progress** | audit + maintenance procedure shipped; arch narrative + fork README + gitconfig aliases + upstream-merge playbook still open |
```

- [ ] **Step 2: Add a pointer to the maintenance doc in the file-map table**

In the "What lives here" table in `cc-tuned/README.md`, add two new rows in the same style as the existing entries (place them near the existing `docs/` rows):

```markdown
| `docs/keyword-table-maintenance.md` | Evergreen procedure for adding/removing/tightening hook keyword patterns (M5) |
| `docs/audits/2026-05-11-keyword-table.md` | Dated audit of the keyword table — findings + tuning rationale (M5) |
```

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/README.md
git commit -m "docs(cc-tuned): note partial M5 progress in README status"
```

---

## Task 10: Push branch and open PR

**Files:** none (git/gh operations only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feature/m5-keyword-table-audit
```

Expected: push succeeds, branch tracks origin.

- [ ] **Step 2: Comment on issue #5 noting which sub-tasks this PR addresses**

```bash
gh issue comment 5 --repo rsx129921/superpowers --body "Starting M5 with audit + maintenance procedure sub-tasks. PR incoming. Remaining unblocked work (arch narrative, fork README, gitconfig aliases) will follow in separate PRs. Upstream-merge playbook still blocked on M4."
```

- [ ] **Step 3: Open the PR**

```bash
gh pr create --repo rsx129921/superpowers --base main --head feature/m5-keyword-table-audit \
  --title "feat(cc-tuned): M5 keyword-table audit + maintenance procedure" \
  --body "$(cat <<'EOF'
## Summary

Addresses sub-tasks of #5:
- Document keyword-table maintenance procedure
- Audit the keyword table for false positives observed (or theoretically possible) since M2

## What ships

- `cc-tuned/docs/audits/2026-05-11-keyword-table.md` — dated audit: per-keyword TP/FP/AMB counts (episodic + theoretical) and recommendations
- `cc-tuned/docs/keyword-table-maintenance.md` — evergreen procedure for adding/removing/tightening patterns
- Conditional hook tuning + test additions if the audit surfaced clear false positives (see audit doc's "Hook changes applied" section)

## What's still open in #5

- Architecture narrative in `cc-tuned/README.md`
- Fork-level `README.md` (optional)
- Optional `.gitconfig` aliases
- Upstream-merge playbook with worked example — blocked on M4

## Soft-strip invariant check

Run `git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat`. Expected: empty output. All changes are inside the cc-tuned layer or in `docs/superpowers/plans/` (the plan doc for this work).

## Test plan

- [ ] `bash cc-tuned/tests/run-all.sh` ends with `All test files passed.`
- [ ] If hook was tuned, new negative test cases pass and confirm the previously-matching prompts no longer match
- [ ] Maintenance doc readable cold without referring to the audit doc
- [ ] Audit doc tables fully filled — no empty cells

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL returned.

- [ ] **Step 4: Verify the soft-strip invariant on the diff**

```bash
git diff main..HEAD -- ':!cc-tuned' ':!docs/superpowers' ':!.github' --stat
```

Expected: empty output. If anything appears outside those paths, stop and investigate before the PR is reviewed.

---

## Self-Review Notes

Run after writing the spec — completed inline below.

**1. Spec coverage:** The brainstorm covered (a) audit method = combined episodic + theoretical, (b) deliverable shape = two docs, (c) hook tuning conditional on findings, (d) test additions for tuned patterns, (e) M5 README status update, (f) PR + issue comment. All present in tasks 1-10. ✓

**2. Placeholder scan:** No `TBD`, `TODO`, or "implement later" in plan steps. Two intentional placeholders inside the audit doc itself (`_To be filled in Task 6_` and `_To be filled in Task 7 if..._`) — those are document content, not plan steps, and Tasks 6 and 7 explicitly replace them. ✓

**3. Type consistency:** Filenames consistent across tasks (`2026-05-11-keyword-table.md` audit doc, `keyword-table-maintenance.md` procedure doc, branch `feature/m5-keyword-table-audit`). Test file path `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` consistent. Issue number `#5` consistent. ✓

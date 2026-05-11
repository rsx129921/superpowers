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
| `let's build` | 0 | 0 | 0 | 3 | tighten: `let's build a` | Phrase not found in corpus. All 3 theoretical FPs matched (conversational: "build on the point", "build a mental model", "build consensus"). Pattern fires on any substring; needs an object noun to distinguish construction intent from conversational use. |
| `let's make` | 0 | 0 | 0 | 3 | tighten: `let's make a` | Phrase not found in corpus. All 3 theoretical FPs matched ("make sure", "make this clear", "make a decision"). Same root cause as `let's build` — too short to distinguish intent. |
| `let's create` | 0 | 0 | 0 | 3 | tighten: `let's create a` | Phrase not found in corpus. All 3 theoretical FPs matched ("create some space", "create a shared vocabulary", "create a checklist"). Note: "create a checklist" is debatable as a near-TP but no brainstorming is needed for checklist tasks. |
| `new feature` | 0 | 0 | 0 | 3 | tighten: `implement.*new feature\|add.*new feature\|new feature.*for` | Phrase not found in corpus as user-typed trigger. All 3 theoretical FPs matched (Python language feature, roadmap mention, docs sentence). Pure substring match is too broad; intent diverges sharply based on surrounding verbs. |

### superpowers:systematic-debugging

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `failing` | 0 | 0 | 0 | 3 | remove | Semantic search returned no verbatim hits (low-quality matches across unrelated projects). All 3 theoretical FPs matched: "plan is failing to come together", "lighting is failing", "failing to see your point". The word fires as both infinitive and predicate on arbitrary subjects; no form narrows it to code/system contexts without re-introducing the same broad-match problem. Concept is adequately covered by `test.*fail`, `broken`, and `doesn't work`. |
| `broken` | 0 | 0 | 0 | 3 | remove | Semantic search returned no verbatim hits. All 3 theoretical FPs matched: "broken English", "a broken promise", "this argument feels broken". Single-word adjective applies to any noun; no tightening short of a compound phrase reduces FP surface meaningfully. Removing leaves the debugging skill reachable via more specific patterns. |
| `bug` | 0 | 0 | 0 | 3 | tighten: `*"a bug"*\|*"the bug"*\|*"this bug"*\|*"that bug"*\|*"bugs"*` | Semantic search returned no verbatim hits. All 3 theoretical FPs matched: "bug in a rhetorical argument", "bug report needs updating", "don't bug me about it". The prior tighten recommendation (`" bug "` space-bounded) had two defects: (1) `" bug "` is present in "don't bug me" (spaces around the verb sense), so the FP was not removed; (2) `" bug "` requires a trailing space, so "fix the bug" (prompt-final) would not match — a real TP loss. The revised pattern requires a determiner (`a`, `the`, `this`, `that`) or the plural form before or as part of the word, which reliably constrains to the noun sense. TPs preserved: "fix the bug", "found a bug", "this bug is annoying", "the bugs in the system". FPs eliminated: "debug" (no determiner phrase), "debugger" (same), "don't bug me" (no determiner phrase), "don't bug me about it" (same). The `debug`/`debugger` accidental-TP side-effect from the original `*bug*` is intentionally dropped — those users are already in a debugging context and upstream skill discovery handles them. |
| `doesn't work` | 0 | 0 | 0 | 3 | remove | Semantic search returned no verbatim hits. All 3 theoretical FPs matched: "my keyboard doesn't work", "that excuse doesn't work for me", "the metaphor doesn't work". Despite being a phrase (more specific than single words), it applies universally to hardware, social, and lifestyle contexts in addition to code. No tightening reliably anchors it to software. |
| `why is this` | 0 | 0 | 0 | 3 | remove | Semantic search returned 15 results but all were low-quality matches on unrelated topics (farming game, FSM project) — no debugging context found. All 3 theoretical FPs matched: "why is this approach preferred?", "why is this even controversial?", "why is this taking so long to ship". Additionally, legitimate design/architecture questions ("why is this design pattern used", "why is this recommended in the docs") matched. The phrase is a generic interrogative with zero semantic anchoring to debugging. |
| `test.*fail` (regex) | 0 | 0 | 0 | 3 | keep | Episodic search for `test fail failing tests` returned no results. All 3 theoretical FPs matched: "test for that hypothesis would fail by design", "a test of will where most fail", "that test failed to convince me". However, the co-occurrence requirement (`test` AND `fail` within the same prompt) is materially more constraining than any single-word pattern. The FPs are literary or abstract phrasing uncommon in developer tool sessions. This pattern was kept deliberately in M2 and the audit confirms it remains the strongest signal in this group — recommend retain. |

### superpowers:test-driven-development

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `add tests` | 0 | 0 | 0 | 0 | keep | No episodic hits. Theoretical: all 3 candidates matched but were dev-context TPs or marginal (coverage/edge-case asks). No unambiguous FP. Keep — tight imperative phrasing. |
| `tdd` | 0 | 0 | 0 | 3 | keep | No episodic hits. Theoretical: 3/3 matched but all were TDD-as-topic meta-discussion in a dev context. In a CC session, mentioning the TDD acronym is overwhelmingly relevant to the TDD skill, even philosophy chat. FPs feel contrived outside dev context. Keep — low co-occurrence cost. |
| `test first` | 0 | 0 | 0 | 2 | keep | No episodic hits. Theoretical: 1 clear FP (UX-validation phrasing), 1 word-order non-match (pattern correctly excludes "test, first"), 1 TP-adjacent ambiguous. Below ≥2 unambiguous FP threshold. Keep. |
| `write tests` | 0 | 0 | 0 | 1 | keep | No episodic hits. Theoretical: 1 unambiguous FP ("tests of attention" — psychology phrase), 2 dev-context borderline TPs. Well below threshold. Keep. |

### superpowers:writing-plans

| Pattern | Episodic TP | Episodic FP | Episodic AMB | Theoretical FP (of 3) | Recommendation | Notes |
|---------|-------------|-------------|--------------|----------------------|----------------|-------|
| `write a plan` | 0 | 0 | 0 | 1 | keep | No episodic hits. One unambiguous FP (non-dev personal planning); the other two theoretical candidates were dev-context TPs or ambiguous meta-questions. Below ≥2 threshold; imperative phrasing keeps precision high in CC sessions. |
| `write a spec` | 0 | 0 | 0 | 1 | keep | No episodic hits. One unambiguous FP (negation: "don't write a spec, just prototype"); negation case cannot be excluded via glob without a narrowing prefix that would strand TPs. Second candidate ("I'd rather write a spec by hand") is dev-context ambiguous, not a clear FP. Below threshold. |
| `draft a plan` | 0 | 0 | 0 | 1 | keep | No episodic hits. One borderline FP ("draft a plan B" stock idiom); the `plan B` phrase is uncommon in pure dev-tool sessions and the skill firing is low-cost. Below threshold. |
| `implementation plan` | 0 | 0 | 0 | 3 | remove | No episodic user-prompt hits (100%-match results were skill-file injection artifacts, not user prompts). All 3 theoretical FPs were "referencing the artifact" category: citing a prior sprint's plan, deferring to an agreed plan, asking where the doc lives. Pattern fires whenever the noun phrase appears; no glob tighten reliably distinguishes creation intent from reference/navigation. |
| `design doc` | 0 | 0 | 0 | 3 | remove | No episodic user-prompt hits (same artifact-injection false signal as `implementation plan`). All 3 theoretical FPs were "referencing the artifact" category: citing what the doc says, reading it, asking for a link. Two-word noun phrase offers no inherent creation signal; FP surface is highest-risk in this batch. |

## Summary of recommendations

### Patterns to remove

- `failing` (skill: `superpowers:systematic-debugging`) — single-word predicate applies to arbitrary non-code subjects ("plan is failing", "lighting is failing"); no narrowing form resolves the FP surface, and the concept is covered by `test.*fail`.
- `broken` (skill: `superpowers:systematic-debugging`) — single-word adjective modifies any noun ("broken English", "a broken promise"); no tightening short of a compound phrase reduces FP surface meaningfully.
- `doesn't work` (skill: `superpowers:systematic-debugging`) — two-word phrase still applies universally to hardware, social, and lifestyle contexts; no anchoring glob reliably constrains it to software.
- `why is this` (skill: `superpowers:systematic-debugging`) — generic interrogative opener with zero semantic anchoring to debugging; all 3 theoretical FPs matched and episodic search returned only unrelated hits across 15 results.
- `implementation plan` (skill: `superpowers:writing-plans`) — noun phrase fires on reference/navigation prompts ("where is the plan?", "per the agreed plan") equally as on creation intent; no glob tighten reliably distinguishes creation from reference.
- `design doc` (skill: `superpowers:writing-plans`) — same artifact-reference problem as `implementation plan`; two-word noun phrase carries no inherent creation signal and produced the highest-risk FP surface in this batch.

### Patterns to tighten

- `let's build` → `let's build a` (skill: `superpowers:brainstorming`) — bare phrase fires on conversational uses ("build on the point", "build consensus"); appending `a` requires an object noun, constraining to construction intent.
- `let's make` → `let's make a` (skill: `superpowers:brainstorming`) — same root cause; "make sure", "make this clear", and "make a decision" all matched the bare form; the indefinite article requires a countable artifact.
- `let's create` → `let's create a` (skill: `superpowers:brainstorming`) — "create some space", "create a shared vocabulary", "create a checklist" all matched bare form; tighten to `let's create a` excludes the first two and constrains the third to artifact-creation contexts.
- `new feature` → `implement.*new feature\|add.*new feature\|new feature.*for` (skill: `superpowers:brainstorming`) — bare noun phrase fires on roadmap mentions and docs sentences; the replacement requires a creation verb (`implement`, `add`) or a `for` qualifier anchoring purpose, which preserves the true-positive signal while excluding feature-as-topic references.
- `bug` → `*"a bug"*\|*"the bug"*\|*"this bug"*\|*"that bug"*\|*"bugs"*` (skill: `superpowers:systematic-debugging`) — bare substring fires on "debug", "debugger", and "don't bug me"; requiring a determiner phrase (`a`/`the`/`this`/`that`) or the plural form constrains the match to the noun sense and preserves TPs ("fix the bug", "found a bug", "this bug is annoying").

### Patterns to keep

**superpowers:systematic-debugging**
- `test.*fail` (regex) — co-occurrence of `test` and `fail` is materially more constraining than any single-word pattern; literary FPs are uncommon in developer-tool sessions and the pattern was intentionally retained in M2.

**superpowers:test-driven-development**
- `add tests` — tight imperative phrasing; no unambiguous FP in theoretical enumeration.
- `tdd` — acronym mention in a CC session is overwhelmingly in-context; FPs feel contrived outside dev work.
- `test first` — one non-dev FP (UX-validation phrasing), below the ≥2 threshold.
- `write tests` — one unambiguous FP ("tests of attention"), well below threshold.

**superpowers:writing-plans**
- `write a plan` — one unambiguous non-dev FP; imperative form keeps precision high in CC sessions.
- `write a spec` — one FP (negation form); negation cannot be excluded via glob without stranding TPs.
- `draft a plan` — one borderline FP ("draft a plan B"); idiom is rare in pure dev-tool sessions and skill-firing cost is low.

### Net effect on hook signal

6 patterns removed and 5 tightened out of 19 total (8 kept unchanged). The removals eliminate the hook's broadest single-word and generic-phrase triggers, which collectively generated the most theoretical false-positive surface; the tightens preserve true-positive recall for the brainstorming and systematic-debugging skills while closing the main FP exposure. Because episodic data was thin across all four skills (zero verbatim hits in every corpus search), conclusions rest primarily on theoretical false-positive enumeration rather than measured session traffic — the actual false-positive reduction in practice is plausible but unquantified. No new false-negatives are expected for brainstorming (the replacements preserve all plausible creation-intent phrasings) or for TDD and writing-plans (all four patterns in each are kept). For systematic-debugging, removing `failing`, `broken`, and `doesn't work` leaves `test.*fail` and the tightened `bug` pattern as the main entry points, which is a deliberate trade of breadth for precision consistent with the hook's design comment.

## Hook changes applied

### Removed patterns (6)

- Removed: `*failing*` (skill `superpowers:systematic-debugging`)
- Removed: `*broken*` (skill `superpowers:systematic-debugging`)
- Removed: `*"doesn't work"*` (skill `superpowers:systematic-debugging`)
- Removed: `*"why is this"*` (skill `superpowers:systematic-debugging`)
- Removed: `*"implementation plan"*` (skill `superpowers:writing-plans`)
- Removed: `*"design doc"*` (skill `superpowers:writing-plans`)

### Tightened patterns (5)

- Tightened: `*"let's build"*` → `*"let's build a"*` (skill `superpowers:brainstorming`) — glob
- Tightened: `*"let's make"*` → `*"let's make a"*` (skill `superpowers:brainstorming`) — glob
- Tightened: `*"let's create"*` → `*"let's create a"*` (skill `superpowers:brainstorming`) — glob
- Tightened: `*"new feature"*` → regex `implement.*new feature|add.*new feature|new feature.*for` (skill `superpowers:brainstorming`) — moved to new `grep -qE` block
- Tightened: `*bug*` → `*"a bug"*|*"the bug"*|*"this bug"*|*"that bug"*|*" bugs "*|*" bugs"|"bugs "*` (skill `superpowers:systematic-debugging`) — glob (see syntax decision below)
  - **Follow-up fix (Task 7):** The initial tighten used `*bugs*` (substring) for the plural form, which inadvertently matched `debugs` (e.g. "she debugs the code") because `debugs` contains the substring `bugs`. The `*bugs*` alternate was replaced with three boundary-anchored alternates — `*" bugs "*` (middle), `*" bugs"` (end), `"bugs "*` (start) — eliminating the `debugs` false positive. FPs now also eliminated: "she debugs the code", "it debugs memory leaks", "the profiler debugs the allocation".

### Bug syntax decision: glob literal (audit recommendation)

Applied the audit's explicit glob recommendation rather than the regex word-boundary alternative (`(^| )bugs?( |$)`). Rationale: the audit doc already evaluated both forms and chose the determiner-phrase approach on the grounds that it (1) eliminates the "don't bug me" FP that would survive even the space-bounded regex (` bug ` has spaces around the verb sense), (2) avoids the prompt-final TP loss ("fix the bug" with no trailing space wouldn't match the space-bounded form), and (3) loses only adjective+bare-noun constructions ("weird bug") that were never corpus-confirmed as true positives. The existing positive test "weird bug in the parser" was therefore updated to "fix the bug in the parser" to reflect what the tightened pattern actually covers.

### Test changes

- Added negative tests: 13 cases in `test-cc-user-prompt-submit.sh`
  - 6 for removed patterns (one per removal)
  - 4 for tightened brainstorming patterns (three bare-phrase, one bare-noun-phrase)
  - 3 for tightened bug pattern (`debug`, `don't bug me`, adjective-only)
- Updated positive tests: 5 existing tests modified
  - `"let's create something"` → `"let's create a tool"` (tighten: requires article)
  - `"weird bug in the parser"` → `"fix the bug in the parser"` (tighten: requires determiner)
  - `"draft the implementation plan"` → `"draft a plan for the migration"` (removal: new prompt uses kept `draft a plan` pattern)
  - `"kick off a design doc"` → converted to negative test `"removed: design doc"` (removal)
  - `"build is broken"` → converted to negative test `"removed: broken"` (removal)
  - Added 2 new positive tests for `implement.*new feature` and `add.*new feature` regex paths
  - Relabeled `"failing trigger"` → `"test.*fail regex (was: failing trigger)"` (prompt "test is failing again" still matches via `test.*fail` regex; label updated to reflect the changed trigger pathway)
  - Updated inline Red Flags / plain-text verification probes from `"let's build something"` to `"let's build a todo app"` (the bare form no longer matches after tighten)
- Removed positive tests: 0 (all converted to negatives or updated)

Patch commit: in this PR

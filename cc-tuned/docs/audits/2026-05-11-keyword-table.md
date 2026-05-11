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
| `bug` | 0 | 0 | 0 | 3 | tighten: `*"a bug"*\|*" bug "*` | Semantic search returned no verbatim hits. All 3 theoretical FPs matched: "bug in a rhetorical argument", "bug report needs updating", "don't bug me about it". Additional issue: `debug` and `debugger` incidentally match via substring (these are TPs, but the match is accidental). Tightening to `"a bug"` and `" bug "` (space-bounded) removes the verb sense ("don't bug me") and most noun-as-insect cases while preserving "there's a bug", "found a bug", "there is a bug". The `debug`/`debugger` substring match is preserved as a side-effect. |
| `doesn't work` | 0 | 0 | 0 | 3 | remove | Semantic search returned no verbatim hits. All 3 theoretical FPs matched: "my keyboard doesn't work", "that excuse doesn't work for me", "the metaphor doesn't work". Despite being a phrase (more specific than single words), it applies universally to hardware, social, and lifestyle contexts in addition to code. No tightening reliably anchors it to software. |
| `why is this` | 0 | 0 | 0 | 3 | remove | Semantic search returned 15 results but all were low-quality matches on unrelated topics (farming game, FSM project) — no debugging context found. All 3 theoretical FPs matched: "why is this approach preferred?", "why is this even controversial?", "why is this taking so long to ship". Additionally, legitimate design/architecture questions ("why is this design pattern used", "why is this recommended in the docs") matched. The phrase is a generic interrogative with zero semantic anchoring to debugging. |
| `test.*fail` (regex) | 0 | 0 | 0 | 3 | keep | Episodic search for `test fail failing tests` returned no results. All 3 theoretical FPs matched: "test for that hypothesis would fail by design", "a test of will where most fail", "that test failed to convince me". However, the co-occurrence requirement (`test` AND `fail` within the same prompt) is materially more constraining than any single-word pattern. The FPs are literary or abstract phrasing uncommon in developer tool sessions. This pattern was kept deliberately in M2 and the audit confirms it remains the strongest signal in this group — recommend retain. |

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

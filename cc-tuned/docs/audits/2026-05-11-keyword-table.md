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

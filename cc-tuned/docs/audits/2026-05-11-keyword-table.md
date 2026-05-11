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

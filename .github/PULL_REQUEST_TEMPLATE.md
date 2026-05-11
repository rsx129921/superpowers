<!--
For the rsx129921/superpowers fork. The template below is intentionally
short but disciplined — even on a personal fork, capturing the *why* now
saves future-you from re-deriving it in six months.
-->

## Problem
<!-- The specific friction or gap this PR closes. If it's a CC friction,
     reference the corresponding `cc-friction` issue. If it's an upstream
     sync, reference the `upstream-merge` tracking issue. -->

## What this PR changes
<!-- 1-3 sentences. What, not why. -->

## Alternatives considered
<!-- Optional but useful. What did you try first? Why was it worse? -->

## Testing

| Tier | Status | Notes |
|------|--------|-------|
| Tier 1 (hook unit tests) | <!-- pass / N/A --> | |
| Tier 2 (skill structure) | <!-- pass / N/A --> | |
| Tier 3 (manual session)  | <!-- pass / N/A --> | |

## Existing PRs / Issues
<!-- Closes #N (umbrella tracker), Related: #N, #N -->

## Self-checks

- [ ] Touches only `cc-tuned/` and the two known additive JSON edits — or upstream sync is acknowledged
- [ ] Hooks no-op on non-CC harnesses (if hook changes)
- [ ] Memory-aware skills degrade gracefully if MCPs absent (if skill changes)
- [ ] One coherent change — not a bundle of unrelated work

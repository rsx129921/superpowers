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

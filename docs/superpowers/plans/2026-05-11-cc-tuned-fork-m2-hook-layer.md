# CC-Tuned Fork — M2 Hook Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace M1 stub bodies in the three cc-tuned hooks with real CC-tuned logic — MCP introspection injection (cc-session-start), keyword-matched skill re-injection (cc-user-prompt-submit), bootstrap preservation (cc-pre-compact) — and prove the behavior via Tier 1 unit tests on the JSON each hook emits.

**Architecture:** Each hook keeps the M1 platform-detect → non-CC-exit-silent guard, then on the CC branch builds an `additionalContext` payload and emits it as the CC-specific JSON shape (`hookSpecificOutput.additionalContext`). A new shared library `cc-tuned/hooks/lib/json-emit.sh` factors out JSON string escaping and the printf emit envelope (the upstream session-start hook proves printf is required — bash 5.3+ has a heredoc-hang bug worth avoiding here). Tests assert on the emitted JSON content (presence of expected substrings, valid JSON structure), not on model behavior.

**Tech Stack:** Bash 4+, JSON (printf-emitted, jq-validated in tests), upstream session-start as reference for CC hook output contract.

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md) §2 (Hook Layer).

**Umbrella issue:** [#2](https://github.com/rsx129921/superpowers/issues/2)

**Built on top of:** M1 (merged 2026-05-11 at 79fbf36). All M1 scaffolding (cc-tuned/, polyglot dispatcher, platform-detect, mcp-introspect, stub hooks, test harness, hooks.json wiring) is in place. M2 only adds bodies to the stubs and tests for the bodies.

---

## File Structure

**Created in this plan:**

| Path | Responsibility |
|------|----------------|
| `cc-tuned/hooks/lib/json-emit.sh` | Shared bash library: escape_for_json() + emit_cc_hook_context() |
| `cc-tuned/tests/hooks/test-json-emit.sh` | Unit test for the json-emit library |
| `cc-tuned/tests/hooks/test-cc-session-start.sh` | Replaces test-stubs.sh for cc-session-start; tests real MCP injection |
| `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` | Replaces test-stubs.sh for cc-user-prompt-submit; tests keyword table |
| `cc-tuned/tests/hooks/test-cc-pre-compact.sh` | Replaces test-stubs.sh for cc-pre-compact; tests fixed-string output |
| `cc-tuned/docs/cc-hook-json-contracts-research.md` | Decision record on JSON shape per event (Task 1) |

**Modified in this plan:**

| Path | Change |
|------|--------|
| `cc-tuned/hooks/cc-session-start` | Stub body replaced with MCP-availability injection |
| `cc-tuned/hooks/cc-user-prompt-submit` | Stub body replaced with keyword match + skill suggestion |
| `cc-tuned/hooks/cc-pre-compact` | Stub body replaced with bootstrap-preservation injection |
| `cc-tuned/README.md` | Status table M2 → "active" then later "complete"; smoke test section expanded |

**Deleted in this plan:**

| Path | Why |
|------|-----|
| `cc-tuned/tests/hooks/test-stubs.sh` | M1 stub-contract test ("CC emits nothing") becomes false once M2 makes hooks emit content. Replaced by per-hook test files that cover both the non-CC no-op contract and the CC-real-behavior contract. |

**Out of scope (deferred to M3+):**
- Memory-aware skills that consume the injected MCP availability context (that's M3).
- Improved keyword tables based on real-session false-positive observations (that's M5).
- Worktree-aware behavior changes (none of these hooks need that).

---

## Task 1: Research CC hook JSON contracts for UserPromptSubmit and PreCompact

**Files:**
- Create: `cc-tuned/docs/cc-hook-json-contracts-research.md`

**Why this is first:** The upstream `hooks/session-start` script handles the SessionStart event and emits CC-format JSON as `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}`. For UserPromptSubmit and PreCompact, the contract isn't documented in any file in this repo. Without confirming the shape, our hooks might emit JSON that CC ignores. Same risk pattern as M1 Task 1 — resolve via empirical research before writing code.

- [ ] **Step 1: Read upstream session-start as the canonical reference**

```bash
cat hooks/session-start | grep -B2 -A6 "hookSpecificOutput"
```

Capture the printf format string upstream uses. Confirm:
- CC's JSON key is `hookSpecificOutput.additionalContext` (nested object)
- The nested object also carries `hookEventName` matching the registered event name
- Format-string approach (printf with embedded JSON) avoids bash 5.3+ heredoc hang

- [ ] **Step 2: Search Anthropic's plugin docs for the per-event JSON shape**

Use WebSearch:

```
WebSearch: "Claude Code hook UserPromptSubmit additionalContext hookSpecificOutput JSON"
WebSearch: "Claude Code hook PreCompact additionalContext hookSpecificOutput JSON"
WebFetch: https://code.claude.com/docs/en/plugins-reference (re-fetch to verify still live and find hook event reference)
```

Capture per-event documentation answering:
1. Does CC consume `additionalContext` for UserPromptSubmit? Where does the injected text appear in the model's context (before user prompt? part of prompt? separate channel)?
2. Does CC consume `additionalContext` for PreCompact? Does it reach the compaction-summarizer model, the post-compaction model, or both?
3. Is the JSON envelope the same as SessionStart (`hookSpecificOutput.additionalContext` with `hookEventName` updated), or different?

- [ ] **Step 3: Document findings**

Write `cc-tuned/docs/cc-hook-json-contracts-research.md`:

```markdown
# CC Hook JSON Output Contracts: Decision Record

**Date:** 2026-05-11
**Decision (per event):** See table below
**Authority:** <docs URL + last-verified date>

## Findings

### SessionStart
- Format: `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<text>"}}`
- Confirmed via: upstream hooks/session-start (working in production)

### UserPromptSubmit
- Format: <fill in from docs>
- Consumption: <where the injected text appears — before prompt, part of prompt, etc.>

### PreCompact
- Format: <fill in from docs>
- Consumption: <which model sees it — summarizer, post-compaction, both>

## Decision for each cc-tuned hook

| Hook | JSON envelope used |
|------|---------------------|
| cc-session-start | `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<text>"}}` |
| cc-user-prompt-submit | <determined by Step 2> |
| cc-pre-compact | <determined by Step 2> |

## Open ambiguities

<If docs are silent or unclear on any event, document the ambiguity and pick the
lower-risk option that mimics SessionStart's envelope. False output emitted in the
wrong shape will be silently ignored by CC; the worst case is the hook becomes a no-op
in practice. We can iterate.>

## Implications for Tasks 4-6

Tasks 4, 5, 6 will emit JSON in the format recorded here. If a hook's shape later
turns out to be wrong, a follow-up M2.1 patch can update it without re-doing the
whole milestone — the json-emit lib (Task 2) centralizes the envelope.
```

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/docs/cc-hook-json-contracts-research.md
git commit -m "$(cat <<'EOF'
research: document CC hook JSON output contracts for M2

Resolves the Risk that UserPromptSubmit and PreCompact may use different
JSON envelopes than SessionStart's hookSpecificOutput.additionalContext.
Findings recorded in cc-tuned/docs/cc-hook-json-contracts-research.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add lib/json-emit.sh + unit test (TDD)

**Files:**
- Create: `cc-tuned/hooks/lib/json-emit.sh`
- Test: `cc-tuned/tests/hooks/test-json-emit.sh`

**Why before the hook tasks:** All three M2 hooks need to escape arbitrary text into a JSON string value and emit a JSON envelope. Factoring this once avoids three near-duplicate copies. The upstream `hooks/session-start` proves the printf-based approach is necessary (bash 5.3+ heredoc hang).

- [ ] **Step 1: Write the failing test**

Create `cc-tuned/tests/hooks/test-json-emit.sh`:

```bash
#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/lib/json-emit.sh
#
# json-emit.sh exposes two bash functions when sourced:
#   escape_for_json <string>      → prints JSON-safe string body on stdout
#   emit_cc_hook_context <event> <text> → prints CC-format JSON envelope

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/json-emit.sh"
BASH_BIN="$(command -v bash)"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $(printf %s "$expected" | head -c 120)"
        echo "    actual:   $(printf %s "$actual" | head -c 120)"
        fail=$((fail + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   $needle"
        echo "    haystack: $(printf %s "$haystack" | head -c 200)"
        fail=$((fail + 1))
    fi
}

echo "test-json-emit.sh"

# escape_for_json — basic cases
# Run helper in a subshell that sources the lib, so we don't mutate caller env.
escape_in_subshell() {
    "$BASH_BIN" -c "source '$LIB'; escape_for_json \"\$1\"" _ "$1"
}

actual=$(escape_in_subshell 'plain text')
assert_eq "plain text passes through" 'plain text' "$actual"

actual=$(escape_in_subshell 'has "quotes"')
assert_eq 'double quotes escaped' 'has \"quotes\"' "$actual"

actual=$(escape_in_subshell 'back\slash')
assert_eq 'backslash escaped' 'back\\slash' "$actual"

actual=$(escape_in_subshell $'line one\nline two')
assert_eq 'newline becomes \n' 'line one\nline two' "$actual"

actual=$(escape_in_subshell $'with\ttab')
assert_eq 'tab becomes \t' 'with\ttab' "$actual"

# emit_cc_hook_context — JSON envelope shape
emit_in_subshell() {
    "$BASH_BIN" -c "source '$LIB'; emit_cc_hook_context \"\$1\" \"\$2\"" _ "$1" "$2"
}

actual=$(emit_in_subshell SessionStart 'hello world')
assert_contains "envelope contains hookSpecificOutput" "hookSpecificOutput" "$actual"
assert_contains "envelope contains hookEventName" '"hookEventName": "SessionStart"' "$actual"
assert_contains "envelope contains additionalContext" '"additionalContext"' "$actual"
assert_contains "envelope contains payload text" 'hello world' "$actual"

# JSON validity
if command -v python3 >/dev/null 2>&1; then
    set +e
    printf '%s' "$actual" | python3 -m json.tool >/dev/null 2>&1
    rc=$?
    set -e
    assert_eq "emitted JSON is valid" "0" "$rc"
fi

# Quotes in payload are escaped
actual=$(emit_in_subshell UserPromptSubmit 'with "quotes" inside')
assert_contains "payload quotes escaped in envelope" '\"quotes\"' "$actual"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable:
```bash
chmod +x cc-tuned/tests/hooks/test-json-emit.sh
```

- [ ] **Step 2: Run test to verify it fails (TDD red phase)**

```bash
bash cc-tuned/tests/hooks/test-json-emit.sh
```

Expected: fails because `cc-tuned/hooks/lib/json-emit.sh` doesn't exist. Confirm.

- [ ] **Step 3: Write minimal implementation**

Create `cc-tuned/hooks/lib/json-emit.sh`:

```bash
#!/usr/bin/env bash
# json-emit.sh — JSON output helpers for cc-tuned hooks.
#
# Two functions exported on source:
#   escape_for_json <string>             → echoes JSON-safe string body
#   emit_cc_hook_context <event> <text>  → prints CC's hookSpecificOutput envelope
#
# Uses printf-based emission to avoid the bash 5.3+ heredoc hang documented
# in upstream hooks/session-start (see github.com/obra/superpowers/issues/571).
#
# Pure bash. No external commands required. Fail-open: sourcing this lib
# never aborts the caller, and emit functions write to stdout only.

set -u

# Escape a string for embedding inside a JSON string literal.
# Uses bash parameter substitution exclusively — fast, no external commands.
# Handles: backslash, double quote, newline, carriage return, tab.
escape_for_json() {
    local s="${1-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Emit a CC-format hook output envelope to stdout.
#   $1 = hookEventName (SessionStart | UserPromptSubmit | PreCompact)
#   $2 = additionalContext payload (raw text; this function escapes it)
emit_cc_hook_context() {
    local event="${1-}"
    local payload="${2-}"
    local escaped
    escaped=$(escape_for_json "$payload")
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "%s",\n    "additionalContext": "%s"\n  }\n}\n' \
        "$event" "$escaped"
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-json-emit.sh
```

Expected: all assertions pass (count: 5 escape tests + 4 envelope tests + 1 JSON-validity test + 1 escape-inside-envelope test = 11 assertions).

- [ ] **Step 5: Commit (with --chmod=+x)**

```bash
git add cc-tuned/hooks/lib/json-emit.sh cc-tuned/tests/hooks/test-json-emit.sh
git update-index --chmod=+x cc-tuned/hooks/lib/json-emit.sh
git update-index --chmod=+x cc-tuned/tests/hooks/test-json-emit.sh
git commit -m "$(cat <<'EOF'
feat(cc-tuned): json-emit.sh helper + unit test

Centralized JSON escaping and CC hookSpecificOutput envelope emission
for the three M2 hooks. Pure bash, no external commands. Uses
printf-based emission to avoid the bash 5.3+ heredoc hang documented
in upstream hooks/session-start.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Delete test-stubs.sh + replace with per-hook test scaffolding

**Files:**
- Delete: `cc-tuned/tests/hooks/test-stubs.sh`
- Create: `cc-tuned/tests/hooks/test-cc-session-start.sh` (initial: contract-only tests, more added in Task 5)
- Create: `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` (initial: contract-only tests, more added in Task 6)
- Create: `cc-tuned/tests/hooks/test-cc-pre-compact.sh` (initial: contract-only tests, more added in Task 4)

**Why this task:** M1's test-stubs.sh asserts "CC stub emits nothing" — that becomes FALSE in M2 when hooks emit real JSON. Three options: (a) update test-stubs.sh to accept either-empty-or-JSON (messy), (b) delete and replace with per-hook tests (clean), (c) keep test-stubs.sh as a minimum contract but loosen the CC assertion (split responsibility). Going with (b): one test file per hook = clean responsibility, easier failure diagnosis when M2 hooks regress.

Each new file starts with the same minimum-contract tests that previously lived in test-stubs.sh (non-CC: no stdout, exit 0). Tasks 4-6 will append CC-behavior tests to each respective file.

- [ ] **Step 1: Create test-cc-pre-compact.sh (contract-only for now)**

```bash
#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-pre-compact
#
# Contract:
#   - Non-CC platforms: exit 0, no stdout
#   - CC platform: emits CC-format JSON additionalContext with bootstrap-preservation note
#
# This file is filled in by M2 Tasks 3 (this contract section) and 4 (CC behavior).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/cc-pre-compact"
BASH_BIN="$(command -v bash)"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — expected '$expected' got '$actual'"
        fail=$((fail + 1))
    fi
}

echo "test-cc-pre-compact.sh"

# Non-CC contract
set +e
actual=$(env -i "$BASH_BIN" "$HOOK" </dev/null 2>&1)
rc=$?
set -e
assert_eq "non-CC: no stdout" "" "$actual"
assert_eq "non-CC: exit 0" "0" "$rc"

# CC contract — placeholder: real assertions added in Task 4
# (Currently asserts no stdout, which will FAIL after Task 4 lands the real body —
#  Task 4 must replace this block with the CC-behavior assertions.)

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable: `chmod +x cc-tuned/tests/hooks/test-cc-pre-compact.sh`

- [ ] **Step 2: Create test-cc-session-start.sh (contract-only)**

```bash
#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-session-start
#
# Contract:
#   - Non-CC platforms: exit 0, no stdout
#   - CC platform: emits CC-format JSON additionalContext with MCP availability list +
#     memory-aware skill directive
#
# This file is filled in by M2 Tasks 3 (this contract section) and 5 (CC behavior).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/cc-session-start"
BASH_BIN="$(command -v bash)"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — expected '$expected' got '$actual'"
        fail=$((fail + 1))
    fi
}

echo "test-cc-session-start.sh"

set +e
actual=$(env -i "$BASH_BIN" "$HOOK" </dev/null 2>&1)
rc=$?
set -e
assert_eq "non-CC: no stdout" "" "$actual"
assert_eq "non-CC: exit 0" "0" "$rc"

# CC contract — real assertions added in Task 5.

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable.

- [ ] **Step 3: Create test-cc-user-prompt-submit.sh (contract-only)**

```bash
#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-user-prompt-submit
#
# Contract:
#   - Non-CC platforms: drains stdin, exits 0, no stdout
#   - CC platform: reads {"prompt": "..."} from stdin, keyword-matches,
#     emits CC-format JSON with skill suggestion (or nothing on no-match)
#
# This file is filled in by M2 Tasks 3 (this contract section) and 6 (CC behavior).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/cc-user-prompt-submit"
BASH_BIN="$(command -v bash)"

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — expected '$expected' got '$actual'"
        fail=$((fail + 1))
    fi
}

echo "test-cc-user-prompt-submit.sh"

# Non-CC contract: even with a prompt on stdin, output nothing
set +e
actual=$(env -i "$BASH_BIN" "$HOOK" <<< '{"prompt": "let'\''s build something"}' 2>&1)
rc=$?
set -e
assert_eq "non-CC: no stdout even with prompt input" "" "$actual"
assert_eq "non-CC: exit 0" "0" "$rc"

# CC contract — real assertions added in Task 6.

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable.

- [ ] **Step 4: Delete test-stubs.sh**

```bash
git rm cc-tuned/tests/hooks/test-stubs.sh
```

- [ ] **Step 5: Verify the harness still works**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: still passes (now 5 test files: platform-detect, mcp-introspect, json-emit, cc-pre-compact contract, cc-session-start contract, cc-user-prompt-submit contract). The assertion counts shift but everything is green.

Note: test-cc-* files will gain MORE assertions in Tasks 4-6.

- [ ] **Step 6: Commit (with chmod for the three new files)**

```bash
git add cc-tuned/tests/hooks/test-cc-pre-compact.sh cc-tuned/tests/hooks/test-cc-session-start.sh cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh
git update-index --chmod=+x cc-tuned/tests/hooks/test-cc-pre-compact.sh
git update-index --chmod=+x cc-tuned/tests/hooks/test-cc-session-start.sh
git update-index --chmod=+x cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh
git commit -m "$(cat <<'EOF'
test(cc-tuned): split test-stubs.sh into per-hook test files

Removes the M1 stub-contract test (which asserts "CC emits nothing" —
becomes false in M2 when hooks emit real JSON) and replaces it with
three per-hook test files. Each starts with the non-CC contract
assertions from test-stubs.sh; CC-behavior assertions arrive in
Tasks 4-6 per hook.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: cc-pre-compact — bootstrap preservation injection (TDD)

**Files:**
- Modify: `cc-tuned/hooks/cc-pre-compact` (replace stub body)
- Modify: `cc-tuned/tests/hooks/test-cc-pre-compact.sh` (add CC-behavior assertions)

**Why this hook first:** Simplest behavior — emit a fixed string, no input parsing, no dynamic content. Builds confidence in the json-emit lib before tackling the harder hooks.

The fixed message per spec §2.3:
> *"After this compaction completes: the using-superpowers bootstrap is still in effect. The compaction summary MUST include a note that superpowers skills (brainstorming, systematic-debugging, test-driven-development, writing-plans, verification-before-completion) remain available via the Skill tool and SHOULD be invoked when their trigger conditions match."*

- [ ] **Step 1: Update test-cc-pre-compact.sh with CC-behavior assertions**

Edit `cc-tuned/tests/hooks/test-cc-pre-compact.sh`. After the non-CC contract block (just before the `echo "  ${pass} passed, ${fail} failed"` line), add:

```bash
# CC contract: emits CC-format JSON with bootstrap-preservation message
set +e
actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" "$HOOK" </dev/null 2>&1)
rc=$?
set -e
assert_eq "CC: exit 0" "0" "$rc"

# Output should contain the JSON envelope markers
if printf '%s' "$actual" | grep -qF '"hookSpecificOutput"'; then
    echo "  pass: CC: emits hookSpecificOutput envelope"
    pass=$((pass + 1))
else
    echo "  FAIL: CC: missing hookSpecificOutput envelope"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF '"hookEventName": "PreCompact"'; then
    echo "  pass: CC: hookEventName is PreCompact"
    pass=$((pass + 1))
else
    echo "  FAIL: CC: hookEventName not PreCompact"
    fail=$((fail + 1))
fi

# Bootstrap-preservation phrase must be in the additionalContext
if printf '%s' "$actual" | grep -qF 'using-superpowers bootstrap is still in effect'; then
    echo "  pass: CC: payload contains bootstrap-preservation phrase"
    pass=$((pass + 1))
else
    echo "  FAIL: CC: payload missing bootstrap-preservation phrase"
    fail=$((fail + 1))
fi

# Skill names should be enumerated for the summarizer
for skill in brainstorming systematic-debugging test-driven-development writing-plans verification-before-completion; do
    if printf '%s' "$actual" | grep -qF "$skill"; then
        echo "  pass: CC: payload mentions $skill"
        pass=$((pass + 1))
    else
        echo "  FAIL: CC: payload missing $skill"
        fail=$((fail + 1))
    fi
done

# JSON validity
if command -v python3 >/dev/null 2>&1; then
    set +e
    printf '%s' "$actual" | python3 -m json.tool >/dev/null 2>&1
    rc=$?
    set -e
    assert_eq "CC: emitted JSON is valid" "0" "$rc"
fi
```

The new assertion count: 2 (non-CC) + 3 (envelope) + 5 (skill names) + 1 (JSON valid) = 11 total per run.

- [ ] **Step 2: Run test to verify it fails (TDD red phase)**

```bash
bash cc-tuned/tests/hooks/test-cc-pre-compact.sh
```

Expected: CC-branch assertions FAIL (stub still emits nothing). Confirm.

- [ ] **Step 3: Replace the stub body in cc-pre-compact**

Replace the entire file `cc-tuned/hooks/cc-pre-compact` with:

```bash
#!/usr/bin/env bash
# cc-pre-compact
#
# Fires before Claude Code compacts the conversation. Injects a fixed
# additionalContext directive instructing the compaction summarizer to
# preserve the using-superpowers bootstrap discipline across the
# compaction handoff. Without this, after compaction the model often
# "forgets" that superpowers skills are still available.
#
# Per design spec §2.3.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

if [ "$PLATFORM" != "cc" ]; then
    exit 0
fi

# shellcheck source=lib/json-emit.sh disable=SC1091
source "${SCRIPT_DIR}/lib/json-emit.sh"

read -r -d '' MESSAGE <<'EOF' || true
After this compaction completes: the using-superpowers bootstrap is still in effect. The compaction summary MUST include a note that superpowers skills (brainstorming, systematic-debugging, test-driven-development, writing-plans, verification-before-completion) remain available via the Skill tool and SHOULD be invoked when their trigger conditions match.
EOF

emit_cc_hook_context "PreCompact" "$MESSAGE"

exit 0
```

Notes:
- `read -r -d '' VAR <<'EOF' ... EOF` is the bash idiom for assigning a multi-line heredoc to a variable without eating leading whitespace.
- The `|| true` after `read` accommodates `read`'s exit-1 when no delimiter is found at EOF (expected for `-d ''`).
- `set -u` (no `-e`) preserves fail-open semantics. The `|| true` and the explicit `exit 0` belt-and-suspenders ensure non-zero never escapes.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-cc-pre-compact.sh
```

Expected: all 11 assertions pass.

- [ ] **Step 5: Verify the harness still runs all tests cleanly**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: all test files green, summary `N / N test files passed`.

- [ ] **Step 6: Commit**

```bash
git add cc-tuned/hooks/cc-pre-compact cc-tuned/tests/hooks/test-cc-pre-compact.sh
git commit -m "$(cat <<'EOF'
feat(cc-tuned): cc-pre-compact emits bootstrap-preservation directive

Replaces the M1 stub body with the fixed PreCompact additionalContext
from design spec §2.3. The injected note tells the compaction
summarizer to preserve a reminder that superpowers skills remain
available post-compaction. Closes the "compaction amnesia" failure
mode identified in the design.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: cc-session-start — MCP availability injection (TDD)

**Files:**
- Modify: `cc-tuned/hooks/cc-session-start` (replace stub body)
- Modify: `cc-tuned/tests/hooks/test-cc-session-start.sh` (add CC-behavior assertions)

**Spec §2.1 behavior:**
1. Platform-detect (already done in stub).
2. Call mcp-introspect.sh to get the list of available MCPs.
3. Emit `additionalContext` containing:
   - A line listing detected MCPs by name (e.g., "Available MCPs: episodic-memory, cognee-memory").
   - The memory-aware directive (verbatim from spec).
4. Empty MCP list still produces output (with "Available MCPs: (none detected)") — keeps behavior consistent across configurations.

- [ ] **Step 1: Update test-cc-session-start.sh with CC-behavior assertions**

Edit the file. After the non-CC contract block, add a test fixture helper and CC-branch assertions:

```bash
# CC contract: emits CC-format JSON with MCP availability + memory-aware directive
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture 1: User settings has two MCPs we care about
mkdir -p "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
cat > "$TMPDIR/home/.claude/settings.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}, "cognee-memory": {"command": "y"}}}
EOF
echo '{}' > "$TMPDIR/proj/.claude/settings.json"

# Invoke hook with CLAUDE_PLUGIN_ROOT set + HOME pointing at our fixture
set +e
actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
assert_eq "CC (fixture 1): exit 0" "0" "$rc"

if printf '%s' "$actual" | grep -qF '"hookEventName": "SessionStart"'; then
    echo "  pass: CC (fixture 1): hookEventName SessionStart"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): missing SessionStart in envelope"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'episodic-memory'; then
    echo "  pass: CC (fixture 1): payload lists episodic-memory"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing episodic-memory"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'cognee-memory'; then
    echo "  pass: CC (fixture 1): payload lists cognee-memory"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing cognee-memory"
    fail=$((fail + 1))
fi

if printf '%s' "$actual" | grep -qF 'memory-aware'; then
    echo "  pass: CC (fixture 1): payload mentions memory-aware directive"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 1): payload missing memory-aware directive"
    fail=$((fail + 1))
fi

# Fixture 2: No MCPs configured anywhere
rm -rf "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
mkdir -p "$TMPDIR/home/.claude" "$TMPDIR/proj/.claude"
echo '{}' > "$TMPDIR/home/.claude/settings.json"
echo '{}' > "$TMPDIR/proj/.claude/settings.json"

set +e
actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
assert_eq "CC (fixture 2 empty MCPs): exit 0" "0" "$rc"

if printf '%s' "$actual" | grep -qE '\(none|none detected'; then
    echo "  pass: CC (fixture 2): empty MCP list rendered as '(none detected)'"
    pass=$((pass + 1))
else
    echo "  FAIL: CC (fixture 2): empty MCP list not handled"
    fail=$((fail + 1))
fi

# JSON validity (re-run fixture 1)
cat > "$TMPDIR/home/.claude/settings.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}}}
EOF
set +e
actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake HOME="$TMPDIR/home" \
    "$BASH_BIN" -c "cd '$TMPDIR/proj' && '$HOOK'" </dev/null 2>&1)
rc=$?
set -e
if command -v python3 >/dev/null 2>&1; then
    set +e
    printf '%s' "$actual" | python3 -m json.tool >/dev/null 2>&1
    rc_json=$?
    set -e
    assert_eq "CC: emitted JSON is valid" "0" "$rc_json"
fi
```

New assertion count: 2 (non-CC contract) + 4 (fixture 1: exit, event, two MCPs, directive) + 2 (fixture 2: exit, none-detected) + 1 (JSON valid) = 9 total.

- [ ] **Step 2: Run test to verify CC assertions fail (red phase)**

```bash
bash cc-tuned/tests/hooks/test-cc-session-start.sh
```

Expected: CC-branch assertions fail. Confirm.

- [ ] **Step 3: Replace stub body in cc-session-start**

Replace `cc-tuned/hooks/cc-session-start` with:

```bash
#!/usr/bin/env bash
# cc-session-start
#
# Fires on SessionStart event (matcher: startup|clear|compact). Inspects
# the MCP server config and injects an additionalContext line telling
# the model which MCPs are available + when to invoke memory-aware
# variants of brainstorming/systematic-debugging/writing-plans.
#
# Idempotent for a given MCP configuration — same content session to
# session means CC's prompt cache stays warm across invocations.
#
# Per design spec §2.1.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

if [ "$PLATFORM" != "cc" ]; then
    exit 0
fi

# shellcheck source=lib/json-emit.sh disable=SC1091
source "${SCRIPT_DIR}/lib/json-emit.sh"

# Drain stdin if CC sent any (SessionStart event historically does not, but
# defending against future changes). cat blocks until pipe closes — safe
# here because we don't process the data.
cat >/dev/null 2>&1 || true

# Collect MCP names — one per line on stdout from mcp-introspect.sh.
# Fail-open: any error → empty list → "(none detected)" message.
MCPS=$(bash "${SCRIPT_DIR}/lib/mcp-introspect.sh" 2>/dev/null || true)

# Build the human-readable MCP-list line.
if [ -z "$MCPS" ]; then
    MCP_LINE="Available MCPs: (none detected)"
else
    # Join newline-separated names with ", ".
    MCP_LINE="Available MCPs: $(printf '%s\n' "$MCPS" | paste -sd, - | sed 's/,/, /g')"
fi

# Build the full additionalContext payload.
PAYLOAD=$(cat <<EOF
${MCP_LINE}

When you would invoke superpowers:brainstorming, superpowers:systematic-debugging, or superpowers:writing-plans, FIRST check whether memory-aware variants apply: if episodic-memory or cognee-memory is in the available MCPs list above, prefer the corresponding memory-aware skill so prior context is recalled before doing new work.
EOF
)

emit_cc_hook_context "SessionStart" "$PAYLOAD"

exit 0
```

Notes:
- `paste -sd,` joins newline-separated lines with commas. The `sed 's/,/, /g'` adds a space after each comma for readability.
- The payload is the same byte-for-byte for a given MCP configuration → CC's prompt cache stays warm.
- `cat <<EOF` (no quoting on EOF) allows `${MCP_LINE}` expansion inside the heredoc.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-cc-session-start.sh
```

Expected: all 9 assertions pass.

- [ ] **Step 5: Verify harness**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add cc-tuned/hooks/cc-session-start cc-tuned/tests/hooks/test-cc-session-start.sh
git commit -m "$(cat <<'EOF'
feat(cc-tuned): cc-session-start injects MCP availability + memory-aware directive

Replaces the M1 stub body with real SessionStart behavior per design
spec §2.1. Reads MCP server names via mcp-introspect.sh, formats them
as a human-readable list, and emits additionalContext containing the
list plus a directive telling the model to prefer memory-aware skill
variants when episodic-memory or cognee-memory is available.

Content is idempotent for a given MCP configuration, preserving CC
prompt cache warmness across sessions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: cc-user-prompt-submit — keyword match + skill suggestion (TDD)

**Files:**
- Modify: `cc-tuned/hooks/cc-user-prompt-submit` (replace stub body)
- Modify: `cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh` (add CC-behavior assertions)

**Spec §2.2 behavior (refined for M2 — see deviation note below):**

1. Platform-detect (already done).
2. Read `{"prompt": "..."}` from stdin. Parse out the prompt text.
3. Match against a keyword table (case-insensitive):

| Pattern | Suggested skill |
|---------|-----------------|
| `let's build\|let's make\|let's create\|new feature` | `superpowers:brainstorming` |
| `failing\|broken\|bug\|test.*fail\|why is this\|doesn't work` | `superpowers:systematic-debugging` |
| `add tests\|TDD\|test first\|write tests` | `superpowers:test-driven-development` |
| `write a plan\|write a spec\|draft a plan\|implementation plan\|design doc` | `superpowers:writing-plans` |

4. On match: emit `additionalContext` containing the targeted skill suggestion + a condensed Red Flags reminder. The skill suggestion text:
   > *"This prompt matches the `<skill>` trigger pattern. Per the using-superpowers bootstrap, you MUST invoke `<skill>` before any other action — including clarifying questions."*
5. No match: emit nothing (no JSON, just `exit 0`).

**Deviation from spec §2.2 keyword table:**
The spec had `let's build|let's make|let's create|new feature|implement` for brainstorming and `plan|spec|design` for writing-plans (with a "no matching file" predicate). Dropping `implement` (too generic — false-positives on routine work) and replacing `plan|spec|design` with specific phrases (avoids triggering on every architecture conversation). The predicate is no longer needed with the conservative phrases. The spec section §2.2 should be updated post-M2 to reflect the actual implemented table (Task 7 README update or a follow-up M5 polish).

- [ ] **Step 1: Update test-cc-user-prompt-submit.sh with CC-behavior assertions**

Add after the non-CC block. Each keyword group gets a positive test + the no-match group gets a negative test.

```bash
# Helper: invoke hook on CC with a synthetic prompt JSON on stdin
invoke_cc_hook() {
    local prompt_json="$1"
    env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" "$HOOK" <<< "$prompt_json" 2>&1
}

assert_skill_suggested() {
    local label="$1" prompt="$2" expected_skill="$3"
    local prompt_json
    prompt_json=$(printf '{"prompt": "%s"}' "$prompt")
    local output
    output=$(invoke_cc_hook "$prompt_json")
    if printf '%s' "$output" | grep -qF "$expected_skill"; then
        echo "  pass: $label → $expected_skill"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label → expected $expected_skill, output was:"
        echo "    $(printf '%s' "$output" | head -c 200)"
        fail=$((fail + 1))
    fi
}

assert_no_suggestion() {
    local label="$1" prompt="$2"
    local prompt_json
    prompt_json=$(printf '{"prompt": "%s"}' "$prompt")
    local output
    output=$(invoke_cc_hook "$prompt_json")
    if [ -z "$output" ]; then
        echo "  pass: $label (no suggestion)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label expected no output, got:"
        echo "    $(printf '%s' "$output" | head -c 200)"
        fail=$((fail + 1))
    fi
}

# brainstorming triggers
assert_skill_suggested "let'\''s build trigger"  "let'\''s build a todo app"  "superpowers:brainstorming"
assert_skill_suggested "let'\''s make trigger"   "let'\''s make a parser"      "superpowers:brainstorming"
assert_skill_suggested "let'\''s create trigger" "let'\''s create something"   "superpowers:brainstorming"
assert_skill_suggested "new feature trigger"     "I want a new feature for X"  "superpowers:brainstorming"

# systematic-debugging triggers
assert_skill_suggested "failing trigger"    "test is failing again"          "superpowers:systematic-debugging"
assert_skill_suggested "broken trigger"     "build is broken"                "superpowers:systematic-debugging"
assert_skill_suggested "bug trigger"        "weird bug in the parser"        "superpowers:systematic-debugging"
assert_skill_suggested "doesn't work trigger" "this doesn'\''t work"         "superpowers:systematic-debugging"

# TDD triggers
assert_skill_suggested "add tests trigger"  "add tests for this function"    "superpowers:test-driven-development"
assert_skill_suggested "TDD trigger"        "let'\''s use TDD here"          "superpowers:test-driven-development"

# writing-plans triggers
assert_skill_suggested "write a plan trigger"     "write a plan for this work"  "superpowers:writing-plans"
assert_skill_suggested "implementation plan trigger" "draft the implementation plan" "superpowers:writing-plans"

# Negative cases — should emit nothing
assert_no_suggestion "casual conversation"  "how are you today"
assert_no_suggestion "just a question"      "what time is it"
assert_no_suggestion "a routine task"       "rename this variable"

# Red Flags table re-injection should be present in any matched output
output=$(invoke_cc_hook '{"prompt": "let'\''s build something"}')
if printf '%s' "$output" | grep -qiE 'red flag|rationaliz|MUST invoke'; then
    echo "  pass: matched output includes discipline re-injection"
    pass=$((pass + 1))
else
    echo "  FAIL: matched output missing discipline re-injection"
    fail=$((fail + 1))
fi

# JSON validity on a matched output
if command -v python3 >/dev/null 2>&1; then
    output=$(invoke_cc_hook '{"prompt": "let'\''s build something"}')
    set +e
    printf '%s' "$output" | python3 -m json.tool >/dev/null 2>&1
    rc_json=$?
    set -e
    assert_eq "matched output is valid JSON" "0" "$rc_json"
fi
```

Total new assertions: 4 (brainstorming) + 4 (debugging) + 2 (TDD) + 2 (writing-plans) + 3 (no-match) + 1 (Red Flags) + 1 (JSON valid) = 17 new. Plus 2 from non-CC contract = 19 total.

- [ ] **Step 2: Run test to verify CC assertions fail (red phase)**

```bash
bash cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh
```

Expected: CC assertions fail.

- [ ] **Step 3: Replace stub body in cc-user-prompt-submit**

```bash
#!/usr/bin/env bash
# cc-user-prompt-submit
#
# Fires on every user message. Reads {"prompt": "..."} from stdin,
# pattern-matches against a small keyword table, and on match emits
# additionalContext containing a targeted skill suggestion plus a
# condensed Red Flags re-injection (defeating the rationalization
# failure mode where Claude knows a skill exists but skips it).
#
# Conservative matching by design: false negatives are fine (upstream
# skill discovery still works); false positives erode the signal
# value of the injection.
#
# Per design spec §2.2 (with the keyword table tightened in M2 — see
# cc-tuned/README.md and docs/superpowers/specs §2.2 for the actual
# implemented table).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

# Always drain stdin (UserPromptSubmit always sends a payload).
PROMPT_JSON=$(cat 2>/dev/null || true)

if [ "$PLATFORM" != "cc" ]; then
    exit 0
fi

# shellcheck source=lib/json-emit.sh disable=SC1091
source "${SCRIPT_DIR}/lib/json-emit.sh"

# Extract the prompt text from {"prompt": "..."} JSON. Prefer jq, fall
# back to python3, else fail open (no injection on parse failure).
extract_prompt() {
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$PROMPT_JSON" | jq -r '.prompt // empty' 2>/dev/null
    else
        printf '%s' "$PROMPT_JSON" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("prompt") or "")
except: pass' 2>/dev/null
    fi
}

PROMPT=$(extract_prompt)
if [ -z "$PROMPT" ]; then
    exit 0
fi

# Lowercase for case-insensitive matching (POSIX-portable).
PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Pattern-match against the keyword table. First match wins.
SKILL=""
case "$PROMPT_LC" in
    *"let's build"*|*"let's make"*|*"let's create"*|*"new feature"*)
        SKILL="superpowers:brainstorming"
        ;;
    *failing*|*broken*|*bug*|*"doesn't work"*|*"why is this"*)
        SKILL="superpowers:systematic-debugging"
        ;;
    *"add tests"*|*tdd*|*"test first"*|*"write tests"*)
        SKILL="superpowers:test-driven-development"
        ;;
    *"write a plan"*|*"write a spec"*|*"draft a plan"*|*"implementation plan"*|*"design doc"*)
        SKILL="superpowers:writing-plans"
        ;;
esac

# Additional pattern for systematic-debugging that uses a regex (test.*fail)
if [ -z "$SKILL" ] && printf '%s' "$PROMPT_LC" | grep -qE 'test.*fail'; then
    SKILL="superpowers:systematic-debugging"
fi

# No match → emit nothing
if [ -z "$SKILL" ]; then
    exit 0
fi

# Build the additionalContext payload: targeted suggestion + Red Flags re-injection.
PAYLOAD=$(cat <<EOF
This prompt matches the ${SKILL} trigger pattern. Per the using-superpowers bootstrap, you MUST invoke ${SKILL} before any other action — including clarifying questions.

Red Flags (rationalizations that mean STOP — you're talking yourself out of using the skill):
- "This is just a simple question" → Questions are tasks. Check for skills.
- "I need more context first" → Skill check comes BEFORE clarifying questions.
- "Let me explore the codebase first" → Skills tell you HOW to explore. Check first.
- "I can check git/files quickly" → Files lack conversation context. Check for skills.
- "This doesn't need a formal skill" → If a skill exists, use it.
- "I remember this skill" → Skills evolve. Read current version.
- "The skill is overkill" → Simple things become complex. Use it.
- "I'll just do this one thing first" → Check BEFORE doing anything.

Invoke ${SKILL} now via the Skill tool.
EOF
)

emit_cc_hook_context "UserPromptSubmit" "$PAYLOAD"

exit 0
```

Notes:
- The case-insensitive match via `tr` + bash glob `case` is portable and fast — no external commands per match attempt.
- The `test.*fail` regex is handled separately via grep because bash `case` globs don't support regex.
- Red Flags content is a condensed version of the upstream `using-superpowers/SKILL.md` Red Flags table — preserves the discipline-driving language without duplicating the full skill prose.
- First-match wins (brainstorming pattern checked before debugging, etc.). The order is intentional: brainstorming is the most discipline-critical to trigger early.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh
```

Expected: all 19 assertions pass.

If any pattern matches a negative case ("how are you today" etc.), tune the case patterns to be more specific.

- [ ] **Step 5: Verify harness**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: all test files green.

- [ ] **Step 6: Commit**

```bash
git add cc-tuned/hooks/cc-user-prompt-submit cc-tuned/tests/hooks/test-cc-user-prompt-submit.sh
git commit -m "$(cat <<'EOF'
feat(cc-tuned): cc-user-prompt-submit emits keyword-matched skill suggestions

Replaces the M1 stub body with keyword-matching behavior per design
spec §2.2. Reads {"prompt": "..."} from stdin, matches against a
conservative keyword table (4 skill groups), and on match emits
additionalContext containing the targeted skill suggestion plus a
condensed Red Flags table re-injection. No-match emits nothing.

Keyword table tightened from spec: dropped 'implement' (too generic)
and replaced 'plan|spec|design' with specific phrases like 'write a
plan' or 'implementation plan' to avoid triggering on routine
architecture conversation.

Closes both the rationalization and pattern-blindness failure modes
identified in the design.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update cc-tuned/README.md with M2 status + smoke-test details

**Files:**
- Modify: `cc-tuned/README.md`

**Why:** M2 changes the layer's behavior (hooks emit real content). The README's Status table needs updating and the Manual Smoke Test section needs to become *actionable* — the M1 placeholder was "this becomes meaningful once M2 ships."

- [ ] **Step 1: Update the Status table**

In `cc-tuned/README.md`, find the Status table. Change M1 from "active" to "complete" and M2 from "not started" to "complete":

Before:
```
| M1 Foundation | active | this scaffold + stub hooks |
| M2 Hook Layer | not started | real hook logic |
```

After:
```
| M1 Foundation | complete | scaffold + stub hooks (merged 2026-05-11) |
| M2 Hook Layer | complete | real hook logic — MCP injection, keyword match, bootstrap preservation |
```

- [ ] **Step 2: Replace the Manual Smoke Test section with the M2 actionable version**

Find the section starting with `## Manual smoke test (Tier 3)`. Replace its entire body with:

```markdown
## Manual smoke test (Tier 3)

Run this in a fresh Claude Code session with the plugin loaded after every M2+ change to the hook bodies.

### Setup
- Open a clean CC session (no prior context).
- Confirm at least one memory MCP is configured (episodic-memory or cognee-memory in your `~/.claude/settings.json` `mcpServers`).

### Check 1: SessionStart MCP injection
Open a new conversation. In your first turn, ask Claude:
> "What MCPs do you currently have available? Just list the names."

Expected: Claude lists the MCPs you have configured. If it says it doesn't know, `cc-session-start` is not injecting context — check `~/.claude/logs/` for hook errors.

### Check 2: UserPromptSubmit keyword trigger
Send the user message exactly:
> "let's build a small todo CLI"

Expected: Claude invokes `superpowers:brainstorming` *before* asking any clarifying questions. The brainstorming skill's intro should appear in Claude's response.

If Claude dives straight into implementation without invoking brainstorming, `cc-user-prompt-submit` either didn't fire, didn't match, or didn't inject the suggestion. Check `~/.claude/logs/`.

### Check 3: PreCompact preservation
This is the hardest to verify directly because compaction is opaque. The closest manual check: have a long-running conversation, let compaction fire, then send a follow-up that should trigger a skill (e.g., "this test is failing"). Expected: systematic-debugging still triggers post-compaction.

If skills stop triggering after a compaction event, `cc-pre-compact` is not preserving bootstrap context — but this is a discipline failure, not a hard error, so it's hard to false-alarm on a single observation.

### Failure-mode quick reference
| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| Claude doesn't know about your MCPs | cc-session-start not firing or not injecting | `~/.claude/logs/`; verify `bash cc-tuned/tests/hooks/test-cc-session-start.sh` still green |
| "let's build X" doesn't trigger brainstorming | cc-user-prompt-submit not matching or not injecting | `~/.claude/logs/`; verify test-cc-user-prompt-submit.sh green; check keyword table in the hook |
| Skills stop triggering after compaction | cc-pre-compact not preserving bootstrap | Hard to verify directly; rely on test-cc-pre-compact.sh assertions |
```

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/README.md
git commit -m "$(cat <<'EOF'
docs(cc-tuned): update README for M2 — status table + actionable smoke test

M2 Hook Layer is now complete: hooks emit real content. The Status
table reflects M1+M2 done; the Manual Smoke Test section becomes
concrete with three checks (MCP availability, keyword trigger,
compaction preservation) and a failure-mode quick-reference table.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: M2 acceptance verification + PR

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test harness**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: all test files pass. Total file count is now 7 (platform-detect, mcp-introspect, json-emit, cc-session-start, cc-user-prompt-submit, cc-pre-compact, plus any from M1 still present). Assertion count is meaningfully higher than M1.

Capture and report the full output.

- [ ] **Step 2: Verify upstream-files invariant**

```bash
git fetch upstream 2>/dev/null || true
git diff upstream/main..HEAD -- ':!cc-tuned' ':!docs/superpowers/specs' ':!docs/superpowers/plans' ':!.github' --stat
```

Expected: only `hooks/hooks.json` (still — no new upstream files touched by M2). Anything else is drift.

- [ ] **Step 3: Verify no-op on non-CC for all three hooks (still works after M2)**

```bash
BASH_BIN=$(command -v bash)
env -i "$BASH_BIN" cc-tuned/hooks/cc-session-start </dev/null && echo "cc-session-start non-CC: silent OK"
env -i "$BASH_BIN" cc-tuned/hooks/cc-user-prompt-submit </dev/null && echo "cc-user-prompt-submit non-CC: silent OK"
env -i "$BASH_BIN" cc-tuned/hooks/cc-pre-compact </dev/null && echo "cc-pre-compact non-CC: silent OK"
```

Expected: each prints "silent OK" (the hook emitted nothing AND exited 0).

- [ ] **Step 4: Verify CC hooks emit valid JSON (spot check)**

```bash
echo '{"prompt": "let'\''s build a todo app"}' | env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" cc-tuned/hooks/cc-user-prompt-submit | python3 -m json.tool >/dev/null && echo "user-prompt-submit emits valid JSON"
env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" cc-tuned/hooks/cc-pre-compact </dev/null | python3 -m json.tool >/dev/null && echo "pre-compact emits valid JSON"
env -i CLAUDE_PLUGIN_ROOT=/fake "$BASH_BIN" cc-tuned/hooks/cc-session-start </dev/null | python3 -m json.tool >/dev/null && echo "session-start emits valid JSON"
```

Expected: three "emits valid JSON" lines.

- [ ] **Step 5: Update the M2 umbrella issue (#2)**

```bash
gh issue comment 2 --repo rsx129921/superpowers --body "$(cat <<'EOF'
## M2 Acceptance Verification

All M2 sub-tasks complete on `feature/m2-hook-layer`:

- [x] CC hook JSON contracts researched (Task 1)
- [x] cc-tuned/hooks/lib/json-emit.sh + tests (Task 2)
- [x] test-stubs.sh split into per-hook test files (Task 3)
- [x] cc-pre-compact bootstrap-preservation injection (Task 4)
- [x] cc-session-start MCP-availability injection (Task 5)
- [x] cc-user-prompt-submit keyword-match + skill suggestion (Task 6)
- [x] cc-tuned/README.md updated (Task 7)

## Acceptance verification

- [x] `bash cc-tuned/tests/run-all.sh`: all test files passed
- [x] Each hook emits valid JSON on CC, nothing on non-CC
- [x] Soft-strip invariant intact (no new upstream-file edits in M2)
- [ ] **DEFERRED to controller** — Tier 3 manual smoke test in a real CC session

Closes this issue on PR merge.
EOF
)"
```

- [ ] **Step 6: Open the M2 PR**

```bash
git push -u origin feature/m2-hook-layer
gh pr create --repo rsx129921/superpowers \
  --base main \
  --head feature/m2-hook-layer \
  --title "[M2] Hook Layer: real bodies for cc-session-start, cc-user-prompt-submit, cc-pre-compact" \
  --body "$(cat <<'BODY'
## Problem

M1 landed the cc-tuned layer scaffold with no-op stub hooks. M2 replaces the stub bodies with the real behavior described in the design spec §2: MCP availability injection, keyword-matched skill suggestions with discipline re-injection, and bootstrap preservation across compaction.

## What this PR changes

- Adds `cc-tuned/hooks/lib/json-emit.sh` helper for CC-format JSON envelope emission
- Replaces M1 stub body in `cc-tuned/hooks/cc-pre-compact` with bootstrap-preservation directive
- Replaces M1 stub body in `cc-tuned/hooks/cc-session-start` with MCP-availability injection + memory-aware directive
- Replaces M1 stub body in `cc-tuned/hooks/cc-user-prompt-submit` with keyword-match + Red Flags re-injection
- Splits `test-stubs.sh` into per-hook test files; each gets contract tests + behavior tests
- Adds `cc-tuned/docs/cc-hook-json-contracts-research.md` documenting the per-event JSON shape
- Updates `cc-tuned/README.md` status table + replaces placeholder smoke test with actionable procedure

No changes to `hooks/hooks.json` — M1's wiring is unchanged in M2. Soft-strip invariant: still only one upstream file edited.

## Alternatives considered

- Keep `test-stubs.sh` and loosen the "CC emits nothing" assertion: rejected — splits responsibility across two abstractions when per-hook tests are cleaner.
- Inline JSON escaping in each hook: rejected — three near-duplicate copies of the escape function. Extracted to lib instead.
- Use the spec's verbatim keyword table (`plan|spec|design`, etc.): rejected — too noisy. Tightened to specific phrases (`write a plan`, `implementation plan`, etc.). Documented as deviation in commit message + spec §2.2 will be updated in M5 polish.

## Testing

| Tier | Status | Notes |
|------|--------|-------|
| Tier 1 (hook unit tests) | pass | All test files green via `bash cc-tuned/tests/run-all.sh` |
| Tier 2 (skill structure) | N/A | No skills in M2 |
| Tier 3 (manual session)  | deferred | Procedure documented in cc-tuned/README.md — to be run by controller |

## Existing PRs / Issues

Closes #2.
Builds on M1 (merged in PR #6).

## Self-checks

- [x] Touches only `cc-tuned/` and `docs/superpowers/plans/`
- [x] Hooks no-op on non-CC harnesses (verified per-hook)
- [x] Each CC hook emits valid JSON (Python json.tool spot-check)
- [x] Memory-aware skills degrade gracefully — N/A, no skills in M2

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

Then attach milestone + labels (since `gh pr create --milestone` may not stick — same pattern as M1 needed):

```bash
gh api repos/rsx129921/superpowers/issues/$(gh pr view --json number -q .number) --method PATCH -F milestone=2 -f 'labels[]=cc-tuned' -f 'labels[]=hook'
```

---

## Self-Review

**Spec coverage:**
- [ ] §2.1 cc-session-start: MCP introspection + injection — Task 5
- [ ] §2.2 cc-user-prompt-submit: keyword match + re-injection — Task 6 (with documented keyword-table deviation)
- [ ] §2.3 cc-pre-compact: bootstrap preservation — Task 4
- [ ] Cross-cutting fail-open requirement — every hook keeps `set -u` no `-e`, explicit `exit 0`
- [ ] No-op on non-CC — every hook's non-CC branch preserved from M1, tested per-hook
- [ ] Soft-strip invariant — no new upstream-file edits; verified in Task 8 Step 2

**Placeholder scan:** Decision-record placeholders (`<docs URL>`, `<fill in from docs>`) in Task 1's template are intentional — filled in by the implementer during research. No `TBD`/`TODO`/"implement later" patterns elsewhere.

**Type/name consistency:**
- Function names (`escape_for_json`, `emit_cc_hook_context`) consistent across Task 2 (lib creation) and Tasks 4-6 (lib usage).
- Hook script names (`cc-pre-compact`, `cc-session-start`, `cc-user-prompt-submit`) consistent.
- Skill names (`superpowers:brainstorming`, etc.) match upstream skill naming.

**Known plan-time risks:**
- Task 1 may discover that UserPromptSubmit or PreCompact use a different JSON envelope than SessionStart. Tasks 4-6 reference `emit_cc_hook_context` with the event name as first arg — if the envelope differs, Task 2's lib needs branching by event. The plan accommodates this via Task 1's decision record.
- The keyword table in Task 6 may produce false positives in real use. Tests cover unambiguous cases; real-world tuning is deferred to M5.
- The PreCompact JSON contract is the most under-documented event. If CC doesn't consume `additionalContext` for PreCompact, this hook becomes a no-op in practice. Worst case: ship M2 as-is, M5 revisits with empirical data from real sessions.

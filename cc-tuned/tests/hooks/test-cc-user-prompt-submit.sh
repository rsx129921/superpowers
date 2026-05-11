#!/usr/bin/env bash
# Tier 1 unit test for cc-tuned/hooks/cc-user-prompt-submit
#
# Contract:
#   - Non-CC platforms: drains stdin, exits 0, no stdout
#   - CC platform: reads {"prompt": "..."} from stdin, keyword-matches,
#     emits PLAIN TEXT on stdout with skill suggestion (or nothing on no-match)
#
# NOTE: Per M2 Task 1 research, this hook emits plain text (not JSON envelope).
# UserPromptSubmit + hookSpecificOutput JSON triggers a spurious first-session
# error banner per bug #17550. Plain text avoids the bug.
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

# CC contract: keyword-matched plain-text skill suggestions

# Helper: invoke hook on CC with synthetic prompt JSON on stdin
invoke_cc_hook() {
    local prompt_json="$1"
    env -i CLAUDE_PLUGIN_ROOT=/fake PATH="/usr/bin:/bin" "$BASH_BIN" "$HOOK" <<< "$prompt_json" 2>&1
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
assert_skill_suggested "let's build trigger"    "let's build a todo app"  "superpowers:brainstorming"
assert_skill_suggested "let's make trigger"     "let's make a parser"     "superpowers:brainstorming"
assert_skill_suggested "let's create trigger"   "let's create a tool"     "superpowers:brainstorming"
assert_skill_suggested "new feature trigger"    "I want a new feature for X" "superpowers:brainstorming"
assert_skill_suggested "implement new feature trigger" "implement a new feature in the auth module" "superpowers:brainstorming"
assert_skill_suggested "add new feature trigger"       "add a new feature for power users"          "superpowers:brainstorming"

# systematic-debugging triggers
# "test is failing again" — now hits the test.*fail regex, not the removed *failing* glob
assert_skill_suggested "test.*fail regex (was: failing trigger)" "test is failing again"      "superpowers:systematic-debugging"
# bug triggers (tightened to determiner/plural forms)
assert_skill_suggested "bug trigger (the)"      "fix the bug in the parser"  "superpowers:systematic-debugging"
assert_skill_suggested "bug trigger (a)"        "found a bug in the handler" "superpowers:systematic-debugging"
assert_skill_suggested "bug trigger (this)"     "this bug is annoying"       "superpowers:systematic-debugging"
assert_skill_suggested "bug trigger (that)"     "that bug keeps coming back" "superpowers:systematic-debugging"
assert_skill_suggested "bug trigger (bugs)"     "there are bugs in the code" "superpowers:systematic-debugging"
assert_skill_suggested "test.*fail regex fallback" "the unit tests fail intermittently" "superpowers:systematic-debugging"

# TDD triggers
assert_skill_suggested "add tests trigger"      "add tests for this function" "superpowers:test-driven-development"
assert_skill_suggested "TDD trigger"            "let's use TDD here"          "superpowers:test-driven-development"
assert_skill_suggested "test first trigger"     "let's write the test first"  "superpowers:test-driven-development"

# writing-plans triggers
assert_skill_suggested "write a plan trigger"        "write a plan for this work"     "superpowers:writing-plans"
assert_skill_suggested "draft a plan trigger"        "draft a plan for the migration" "superpowers:writing-plans"
assert_skill_suggested "write a spec trigger"        "write a spec for the new API"   "superpowers:writing-plans"

# Negative cases — should emit nothing
assert_no_suggestion "casual conversation" "how are you today"
assert_no_suggestion "just a question"     "what time is it"
assert_no_suggestion "a routine task"      "rename this variable"

# Negative cases for REMOVED patterns (must no longer fire)
assert_no_suggestion "removed: failing (non-test context)" "the plan is failing to come together"
assert_no_suggestion "removed: broken"                     "build is broken"
assert_no_suggestion "removed: doesn't work"               "this doesn't work"
assert_no_suggestion "removed: why is this"                "why is this taking so long"
assert_no_suggestion "removed: implementation plan"        "the implementation plan from last sprint"
assert_no_suggestion "removed: design doc"                 "the design doc says we should use postgres"

# Negative cases for TIGHTENED brainstorming patterns
assert_no_suggestion "tightened: let's build (no article)"  "let's build consensus here"
assert_no_suggestion "tightened: let's make (no article)"   "let's make sure this is right"
assert_no_suggestion "tightened: let's create (no article)" "let's create some space for discussion"
assert_no_suggestion "tightened: new feature (no verb)"     "Python's new feature is interesting"

# Negative cases for TIGHTENED bug pattern (must require determiner or plural)
assert_no_suggestion "tightened: bug (debug)"               "debug this issue"
assert_no_suggestion "tightened: bug (don't bug me)"        "don't bug me about it"
assert_no_suggestion "tightened: bug (adjective-only)"      "weird bug in the parser"

# Red Flags / discipline re-injection present in matched output
output=$(invoke_cc_hook '{"prompt": "let'\''s build a todo app"}')
if printf '%s' "$output" | grep -qiE 'red flag|rationaliz|MUST invoke'; then
    echo "  pass: matched output includes discipline re-injection"
    pass=$((pass + 1))
else
    echo "  FAIL: matched output missing discipline re-injection"
    fail=$((fail + 1))
fi

# Plain-text emit verification: matched output is NOT JSON
output=$(invoke_cc_hook '{"prompt": "let'\''s build a todo app"}')
if printf '%s' "$output" | grep -qF '"hookSpecificOutput"'; then
    echo "  FAIL: matched output is JSON envelope — should be plain text (bug #17550)"
    fail=$((fail + 1))
else
    echo "  pass: matched output is plain text (not JSON envelope)"
    pass=$((pass + 1))
fi

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]

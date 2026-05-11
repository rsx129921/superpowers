# CC-Tuned Fork — M1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `cc-tuned/` layer scaffold (directory tree, polyglot hook dispatcher, platform-detect + MCP-introspect helpers, three stub hook scripts wired into Claude Code via manifest edits, test harness, README) so subsequent milestones can implement real hook logic and skills against a working foundation.

**Architecture:** Soft-strip layer under a single new top-level directory `cc-tuned/`. All hooks no-op on non-CC harnesses via shared `platform-detect.sh`. Hook scripts use the same polyglot bat+bash pattern as upstream's `hooks/run-hook.cmd` for Windows + Unix compatibility. Two additive JSON edits to upstream files (`.claude-plugin/plugin.json` and/or `hooks/hooks.json` — Task 1 determines which) register the hooks with CC. Stub scripts in M1 are no-op stubs (platform-detect → exit 0); real logic comes in M2.

**Tech Stack:** Bash 4+, JSON, Windows cmd.exe (polyglot dispatch), Claude Code plugin spec. No language runtimes, no package dependencies, no network calls.

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md) §1 (File Layout), §4 (JSON Manifest Edits).

**Umbrella issue:** [#1](https://github.com/rsx129921/superpowers/issues/1)

---

## File Structure

**Created in this plan:**

| Path | Responsibility |
|------|----------------|
| `cc-tuned/README.md` | Layer overview, soft-strip guarantees, manual smoke-test placeholder |
| `cc-tuned/hooks/run-hook.cmd` | Polyglot bat+bash dispatcher for cc-tuned hooks |
| `cc-tuned/hooks/lib/platform-detect.sh` | Single source of truth for "are we on CC?" check |
| `cc-tuned/hooks/lib/mcp-introspect.sh` | Reads settings.json files; emits deduplicated list of available MCP names |
| `cc-tuned/hooks/cc-session-start` | Stub: platform-detect → exit 0 (real logic in M2) |
| `cc-tuned/hooks/cc-user-prompt-submit` | Stub: platform-detect → exit 0 (real logic in M2) |
| `cc-tuned/hooks/cc-pre-compact` | Stub: platform-detect → exit 0 (real logic in M2) |
| `cc-tuned/tests/run-all.sh` | Discovers and runs all `test-*.sh` files |
| `cc-tuned/tests/hooks/test-platform-detect.sh` | Tier 1 unit test for platform-detect |
| `cc-tuned/tests/hooks/test-mcp-introspect.sh` | Tier 1 unit test for mcp-introspect |
| `cc-tuned/tests/hooks/test-stubs.sh` | Tier 1 test verifying stub hooks exit 0 silently on non-CC |
| `cc-tuned/docs/plugin-hooks-research.md` | Decision record from Task 1 (where CC reads hook declarations) |

**Modified in this plan:**

| Path | Edit |
|------|------|
| `.claude-plugin/plugin.json` | Add `hooks` block if Task 1 confirms plugin.json is the mechanism |
| `hooks/hooks.json` | Add 3 new entries (UserPromptSubmit, PreCompact, supplementary SessionStart) if Task 1 confirms hooks.json is the mechanism |

Task 1 determines which file gets edited (possibly both).

**Out of scope for M1 (deferred to M2/M3):**
- Real hook logic (M2)
- Memory-aware skills (M3)
- Tier 3 manual smoke test execution (deferred until M2 ships real logic)

---

## Task 1: Research CC plugin hooks declaration format

**Files:**
- Create: `cc-tuned/docs/plugin-hooks-research.md`

**Why this is first:** Spec §4 explicitly flags as a Risk that "CC's plugin spec format for declaring hook events in `plugin.json` may differ from registering them in `hooks/hooks.json`." Every subsequent task that wires hooks depends on knowing which file CC actually reads. Resolve this before writing any JSON edits.

- [ ] **Step 1: Read existing manifest to ground the question**

Open `.claude-plugin/plugin.json`. Note that it currently declares NO `hooks` array. Open `hooks/hooks.json`. Note it does declare a SessionStart hook with matcher `startup|clear|compact`. The empirical question: when CC loads this plugin, where does it look for hook event registrations?

- [ ] **Step 2: Check official Claude Code plugin docs**

Search Anthropic's plugin docs for "hooks" declaration syntax. Use `WebFetch` or `WebSearch` tool:

```
WebSearch: "Claude Code plugin manifest hooks declaration .claude-plugin/plugin.json"
```

Capture:
1. Does the plugin spec support a top-level `hooks` field in `plugin.json`?
2. Does it specify `hooks/hooks.json` as the canonical location, or is it auto-discovered?
3. If both are supported, which takes precedence?

- [ ] **Step 3: Empirical sanity check (optional but recommended)**

Open Claude Code with the current plugin loaded. Run `/plugin list` and inspect the loaded hooks for `superpowers`. Confirm the existing SessionStart hook from `hooks/hooks.json` is shown. This confirms `hooks/hooks.json` is at minimum *one* working location.

- [ ] **Step 4: Make the decision and document**

Write `cc-tuned/docs/plugin-hooks-research.md`:

```markdown
# Plugin Hooks Declaration: Decision Record

**Date:** YYYY-MM-DD
**Decision:** Register cc-tuned hooks in `<chosen-file>`
**Authority:** <link to docs OR "empirical: confirmed via /plugin list">

## Findings

- `.claude-plugin/plugin.json` <supports / does not support> a `hooks` field.
- `hooks/hooks.json` <is / is not> the canonical auto-discovered location.
- <If both work>: Precedence order is <X>.

## Rationale

<Why we chose this file. If hooks.json: simpler, matches existing upstream
pattern. If plugin.json: more explicit, declares intent in one manifest.>

## Implication for Task 6

Task 6 will edit `<chosen-file>` only. The other JSON manifest stays untouched.
```

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/docs/plugin-hooks-research.md
git commit -m "research: document CC plugin hooks declaration mechanism

Resolves the Risk flagged in design spec §4 about which manifest file
CC reads for hook event registration. Decision and rationale recorded
in cc-tuned/docs/plugin-hooks-research.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Create cc-tuned directory tree + polyglot run-hook.cmd

**Files:**
- Create: `cc-tuned/hooks/run-hook.cmd`
- Create: `cc-tuned/hooks/lib/.gitkeep`
- Create: `cc-tuned/tests/hooks/.gitkeep`
- Create: `cc-tuned/docs/.gitkeep`

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p cc-tuned/hooks/lib
mkdir -p cc-tuned/tests/hooks
mkdir -p cc-tuned/skills
touch cc-tuned/hooks/lib/.gitkeep
touch cc-tuned/tests/hooks/.gitkeep
touch cc-tuned/skills/.gitkeep
touch cc-tuned/docs/.gitkeep
```

- [ ] **Step 2: Write the polyglot run-hook.cmd**

Create `cc-tuned/hooks/run-hook.cmd` (mirrors `hooks/run-hook.cmd` exactly, but resolved against cc-tuned/hooks/):

```bash
: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for cc-tuned hook scripts.
REM Same pattern as superpowers' hooks/run-hook.cmd — see that file for
REM the full explanation. This copy exists because Claude Code's hook
REM dispatcher resolves scripts relative to the .cmd file's directory.

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

set "HOOK_DIR=%~dp0"

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

exit /b 0
CMDBLOCK

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

- [ ] **Step 3: Verify directory tree exists**

Run:
```bash
ls -la cc-tuned/hooks cc-tuned/tests cc-tuned/skills cc-tuned/docs
```
Expected: each shows the `.gitkeep` files plus (for `cc-tuned/hooks/`) `run-hook.cmd`. `lib/` shows its own `.gitkeep`.

- [ ] **Step 4: Verify polyglot dispatch works**

Create a temp test script:
```bash
cat > cc-tuned/hooks/_smoketest <<'EOF'
#!/usr/bin/env bash
echo "smoketest-ok"
EOF
```

Run via the dispatcher:
```bash
bash cc-tuned/hooks/run-hook.cmd _smoketest
```

Expected output: `smoketest-ok`

Clean up:
```bash
rm cc-tuned/hooks/_smoketest
```

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/
git commit -m "infra: cc-tuned directory scaffold and polyglot hook dispatcher

Creates the cc-tuned/ layer's directory tree (hooks/, hooks/lib/,
tests/hooks/, skills/, docs/) plus a copy of the polyglot run-hook.cmd
dispatcher rooted at cc-tuned/hooks/.

Empty .gitkeep files preserve the tree structure under git.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Implement platform-detect.sh (TDD)

**Files:**
- Create: `cc-tuned/hooks/lib/platform-detect.sh`
- Test: `cc-tuned/tests/hooks/test-platform-detect.sh`

- [ ] **Step 1: Write the failing test**

Create `cc-tuned/tests/hooks/test-platform-detect.sh`:

```bash
#!/usr/bin/env bash
# Tier 1 unit test for platform-detect.sh
#
# platform-detect.sh emits the string "cc" on stdout when running on
# Claude Code, "non-cc" otherwise. Exit code is always 0 (fail-open
# semantics — detection failure must never block hook execution).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/platform-detect.sh"

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

echo "test-platform-detect.sh"

# Case 1: CC environment (CLAUDE_PLUGIN_ROOT set, COPILOT_CLI unset)
actual=$(env -i CLAUDE_PLUGIN_ROOT=/some/path bash "$LIB")
assert_eq "cc detected" "cc" "$actual"

# Case 2: Copilot CLI (both vars set)
actual=$(env -i CLAUDE_PLUGIN_ROOT=/some/path COPILOT_CLI=1 bash "$LIB")
assert_eq "copilot cli detected as non-cc" "non-cc" "$actual"

# Case 3: Cursor (CURSOR_PLUGIN_ROOT set)
actual=$(env -i CURSOR_PLUGIN_ROOT=/some/path bash "$LIB")
assert_eq "cursor detected as non-cc" "non-cc" "$actual"

# Case 4: Nothing set (e.g. invoked outside a harness)
actual=$(env -i bash "$LIB")
assert_eq "no harness detected as non-cc" "non-cc" "$actual"

# Case 5: Exit code is 0 in all cases (fail-open)
set +e
env -i bash "$LIB" >/dev/null 2>&1
rc=$?
set -e
assert_eq "exit code is 0" "0" "$rc"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable:
```bash
chmod +x cc-tuned/tests/hooks/test-platform-detect.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash cc-tuned/tests/hooks/test-platform-detect.sh
```

Expected: fails because `cc-tuned/hooks/lib/platform-detect.sh` doesn't exist yet. Error: `bash: ...: No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `cc-tuned/hooks/lib/platform-detect.sh`:

```bash
#!/usr/bin/env bash
# platform-detect.sh
#
# Single source of truth for "are we running on Claude Code?" check.
# Emits "cc" on stdout if CC, "non-cc" otherwise. Always exits 0
# (fail-open). Sourced or invoked by every cc-tuned hook before any
# CC-specific work.
#
# Detection rules:
#   - CC sets CLAUDE_PLUGIN_ROOT (and does NOT set COPILOT_CLI)
#   - Cursor sets CURSOR_PLUGIN_ROOT
#   - Copilot CLI sets COPILOT_CLI=1
#   - Codex / others: none of the above set
# Source: existing hooks/session-start script's platform detection logic.

set -u

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ] && [ -z "${CURSOR_PLUGIN_ROOT:-}" ]; then
    echo "cc"
else
    echo "non-cc"
fi

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-platform-detect.sh
```

Expected output:
```
test-platform-detect.sh
  pass: cc detected
  pass: copilot cli detected as non-cc
  pass: cursor detected as non-cc
  pass: no harness detected as non-cc
  pass: exit code is 0

  5 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/hooks/lib/platform-detect.sh cc-tuned/tests/hooks/test-platform-detect.sh
git commit -m "feat(cc-tuned): platform-detect.sh + unit test

Single source of truth for CC harness detection. Emits 'cc' or 'non-cc'
on stdout. Always exit 0 (fail-open) so detection failures never block
hook execution.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Implement mcp-introspect.sh (TDD)

**Files:**
- Create: `cc-tuned/hooks/lib/mcp-introspect.sh`
- Test: `cc-tuned/tests/hooks/test-mcp-introspect.sh`

**Note:** mcp-introspect.sh reads MCP server configuration from `~/.claude/settings.json` and `./.claude/settings.json`. It emits one MCP name per line on stdout. On any error (file missing, malformed JSON), it emits nothing and exits 0.

- [ ] **Step 1: Write the failing test**

Create `cc-tuned/tests/hooks/test-mcp-introspect.sh`:

```bash
#!/usr/bin/env bash
# Tier 1 unit test for mcp-introspect.sh
#
# mcp-introspect.sh accepts two args: paths to user-level and
# project-level settings.json files. It reads the `mcpServers` object
# from each, deduplicates, and emits sorted MCP names one per line.
# On any error, emits nothing and exits 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../../hooks/lib/mcp-introspect.sh"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

fail=0
pass=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  pass: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        fail=$((fail + 1))
    fi
}

echo "test-mcp-introspect.sh"

# Case 1: User settings has MCPs, project settings empty
cat > "$TMPDIR/user.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "x"}, "cognee-memory": {"command": "y"}}}
EOF
echo '{}' > "$TMPDIR/project.json"
actual=$(bash "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory"
assert_eq "user-only MCPs detected, sorted" "$expected" "$actual"

# Case 2: Project settings adds a third MCP
cat > "$TMPDIR/project.json" <<'EOF'
{"mcpServers": {"obsidian": {"command": "z"}}}
EOF
actual=$(bash "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory
obsidian"
assert_eq "merged + sorted across both files" "$expected" "$actual"

# Case 3: Duplicate name across files — deduplicated
cat > "$TMPDIR/project.json" <<'EOF'
{"mcpServers": {"episodic-memory": {"command": "different"}}}
EOF
actual=$(bash "$LIB" "$TMPDIR/user.json" "$TMPDIR/project.json")
expected="cognee-memory
episodic-memory"
assert_eq "duplicate names deduplicated" "$expected" "$actual"

# Case 4: Missing files — emit nothing, exit 0
set +e
actual=$(bash "$LIB" "$TMPDIR/does-not-exist.json" "$TMPDIR/also-missing.json" 2>/dev/null)
rc=$?
set -e
assert_eq "missing files produce no output" "" "$actual"
assert_eq "missing files exit 0" "0" "$rc"

# Case 5: Malformed JSON — emit nothing, exit 0 (fail-open)
echo 'not valid json {{' > "$TMPDIR/bad.json"
set +e
actual=$(bash "$LIB" "$TMPDIR/bad.json" "$TMPDIR/bad.json" 2>/dev/null)
rc=$?
set -e
assert_eq "malformed JSON produces no output" "" "$actual"
assert_eq "malformed JSON exits 0" "0" "$rc"

# Case 6: settings.json without mcpServers key
echo '{"other": "stuff"}' > "$TMPDIR/no-mcp.json"
actual=$(bash "$LIB" "$TMPDIR/no-mcp.json" "$TMPDIR/no-mcp.json")
assert_eq "settings without mcpServers emits nothing" "" "$actual"

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable:
```bash
chmod +x cc-tuned/tests/hooks/test-mcp-introspect.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash cc-tuned/tests/hooks/test-mcp-introspect.sh
```

Expected: fails because `cc-tuned/hooks/lib/mcp-introspect.sh` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `cc-tuned/hooks/lib/mcp-introspect.sh`:

```bash
#!/usr/bin/env bash
# mcp-introspect.sh USER_SETTINGS PROJECT_SETTINGS
#
# Reads the `mcpServers` object keys from each settings.json file,
# deduplicates, and emits sorted MCP names one per line on stdout.
# On any error (file missing, malformed JSON, jq absent), emits
# nothing and exits 0. Fail-open: detection failure must never block
# hook execution.
#
# Defaults if args omitted:
#   USER_SETTINGS    = $HOME/.claude/settings.json
#   PROJECT_SETTINGS = ./.claude/settings.json

set -u

USER_SETTINGS="${1:-$HOME/.claude/settings.json}"
PROJECT_SETTINGS="${2:-.claude/settings.json}"

extract_keys() {
    local file="$1"
    [ -f "$file" ] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r '.mcpServers // {} | keys[]?' "$file" 2>/dev/null || true
    else
        # jq-less fallback: grep mcpServers block and extract top-level keys
        # Conservative parse — only matches `"name": {` shape inside mcpServers
        python3 - "$file" 2>/dev/null <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as fh:
        d = json.load(fh)
    for k in (d.get("mcpServers") or {}):
        print(k)
except Exception:
    pass
PYEOF
    fi
}

{
    extract_keys "$USER_SETTINGS"
    extract_keys "$PROJECT_SETTINGS"
} | sort -u

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-mcp-introspect.sh
```

Expected: all 8 assertions pass.

If jq is not installed on the test machine, the python3 fallback should handle it identically. If neither jq nor python3 is available, the script emits nothing — and the test cases assert "empty stdout on error" so they still pass. That's correct fail-open behavior.

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/hooks/lib/mcp-introspect.sh cc-tuned/tests/hooks/test-mcp-introspect.sh
git commit -m "feat(cc-tuned): mcp-introspect.sh + unit test

Reads MCP server names from user-level and project-level settings.json,
deduplicates, emits sorted list one per line. Fails open (empty
stdout, exit 0) on missing files, malformed JSON, or absent jq/python3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Create stub hook scripts

**Files:**
- Create: `cc-tuned/hooks/cc-session-start`
- Create: `cc-tuned/hooks/cc-user-prompt-submit`
- Create: `cc-tuned/hooks/cc-pre-compact`
- Test: `cc-tuned/tests/hooks/test-stubs.sh`

**Note:** Stubs in M1 only platform-detect and exit 0 silently. Real logic comes in M2. The stubs exist so Task 6's JSON edits can reference real files and CC's `/plugin list` shows the hooks as registered. Naming the files extensionless (no `.sh`) follows the upstream pattern from `hooks/session-start`.

- [ ] **Step 1: Write the failing test**

Create `cc-tuned/tests/hooks/test-stubs.sh`:

```bash
#!/usr/bin/env bash
# Tier 1 unit test for the three M1 stub hooks.
#
# Each stub must:
#   - exit 0 always (fail-open)
#   - emit nothing to stdout on non-CC platforms (so CC sees an empty
#     additionalContext, equivalent to "do nothing")
#   - tolerate being invoked with no stdin (some hook events get stdin,
#     others don't — stubs must not block waiting for it)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="${SCRIPT_DIR}/../../hooks"

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

echo "test-stubs.sh"

for stub in cc-session-start cc-user-prompt-submit cc-pre-compact; do
    # Non-CC: no output, exit 0
    set +e
    actual=$(env -i bash "$HOOKS/$stub" </dev/null 2>&1)
    rc=$?
    set -e
    assert_eq "$stub: non-CC produces no stdout" "" "$actual"
    assert_eq "$stub: non-CC exits 0" "0" "$rc"

    # CC: stub exits 0 (M1 stubs don't emit context yet; M2 will)
    set +e
    actual=$(env -i CLAUDE_PLUGIN_ROOT=/fake bash "$HOOKS/$stub" </dev/null 2>&1)
    rc=$?
    set -e
    assert_eq "$stub: CC stub exits 0" "0" "$rc"
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable:
```bash
chmod +x cc-tuned/tests/hooks/test-stubs.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash cc-tuned/tests/hooks/test-stubs.sh
```

Expected: fails because the three stub scripts don't exist yet.

- [ ] **Step 3: Write the three stub scripts**

Create `cc-tuned/hooks/cc-session-start`:

```bash
#!/usr/bin/env bash
# cc-session-start (M1 stub)
#
# M1: platform-detect → exit 0 silently. Real MCP-introspection logic
# arrives in M2 per docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md §2.1.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

if [ "$PLATFORM" != "cc" ]; then
    exit 0
fi

# M1 stub: register-but-no-op. Drain stdin in case CC sent any (avoids blocking).
cat >/dev/null 2>&1 || true

exit 0
```

Create `cc-tuned/hooks/cc-user-prompt-submit`:

```bash
#!/usr/bin/env bash
# cc-user-prompt-submit (M1 stub)
#
# M1: platform-detect → drain stdin → exit 0 silently. Real keyword-matching
# logic arrives in M2 per design spec §2.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

if [ "$PLATFORM" != "cc" ]; then
    # Still drain stdin so CC doesn't block waiting for us to consume it
    cat >/dev/null 2>&1 || true
    exit 0
fi

# M1 stub: drain the prompt payload, no-op
cat >/dev/null 2>&1 || true

exit 0
```

Create `cc-tuned/hooks/cc-pre-compact`:

```bash
#!/usr/bin/env bash
# cc-pre-compact (M1 stub)
#
# M1: platform-detect → exit 0 silently. Real bootstrap-preservation logic
# arrives in M2 per design spec §2.3.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=$(bash "${SCRIPT_DIR}/lib/platform-detect.sh")

if [ "$PLATFORM" != "cc" ]; then
    exit 0
fi

# M1 stub: register-but-no-op
exit 0
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash cc-tuned/tests/hooks/test-stubs.sh
```

Expected: all 9 assertions pass (3 hooks × 3 assertions each).

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/hooks/cc-session-start cc-tuned/hooks/cc-user-prompt-submit cc-tuned/hooks/cc-pre-compact cc-tuned/tests/hooks/test-stubs.sh
git commit -m "feat(cc-tuned): M1 stub hook scripts (no-op, register-only)

Three stub hooks (cc-session-start, cc-user-prompt-submit, cc-pre-compact)
that platform-detect and exit 0 silently. Real logic arrives in M2.
Their existence in M1 lets Task 6 wire them via plugin manifest so CC
shows them registered in /plugin list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Wire hooks via JSON manifest edits

**Files (one OR both, per Task 1 decision):**
- Modify: `.claude-plugin/plugin.json`
- Modify: `hooks/hooks.json`

**Important:** Before this task, re-read `cc-tuned/docs/plugin-hooks-research.md` from Task 1. The decision recorded there determines which file(s) to edit. The example below shows the **hooks.json path** because it matches the existing upstream pattern; adapt to plugin.json if Task 1 chose that instead.

- [ ] **Step 1: Re-read Task 1 decision**

```bash
cat cc-tuned/docs/plugin-hooks-research.md
```

Confirm which manifest file to edit. Proceed only if the decision is clear.

- [ ] **Step 2 (hooks.json variant): Add three entries**

Open `hooks/hooks.json`. Current content has one SessionStart entry. Append three new entries. The complete file after editing should look like:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      },
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/cc-tuned/hooks/run-hook.cmd\" cc-session-start",
            "async": false
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/cc-tuned/hooks/run-hook.cmd\" cc-user-prompt-submit",
            "async": false
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/cc-tuned/hooks/run-hook.cmd\" cc-pre-compact",
            "async": false
          }
        ]
      }
    ]
  }
}
```

(If Task 1 instead chose `plugin.json`, write the equivalent `hooks` block per the CC plugin spec format documented there.)

- [ ] **Step 3: Validate JSON syntax**

```bash
python3 -m json.tool hooks/hooks.json >/dev/null && echo "hooks.json OK"
python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"
```

Both should print `OK`. Any parse error means a syntax mistake in the edit.

- [ ] **Step 4: Verify CC sees the new hooks (manual)**

Open Claude Code with this plugin loaded. Run:

```
/plugin list
```

Confirm output includes the four hooks:
- `superpowers` (the upstream SessionStart)
- `cc-session-start`
- `cc-user-prompt-submit`
- `cc-pre-compact`

If `/plugin list` doesn't surface individual hooks, run `/mcp` or check `~/.claude/logs/` for plugin-load logs that confirm hook registration. As a fallback, trigger a hook manually: open a fresh CC session and check that the cc-session-start stub runs (it's silent on success, but `bash -x` instrumentation can be added temporarily for verification).

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json .claude-plugin/plugin.json
git commit -m "feat(cc-tuned): register cc-tuned hooks in plugin manifest

Adds entries for cc-session-start (additional SessionStart matcher),
cc-user-prompt-submit (UserPromptSubmit), and cc-pre-compact (PreCompact)
pointing at cc-tuned/hooks/. Stub scripts exit silently in M1; real
logic lands in M2.

This is one of two known additive edits to upstream files in the
soft-strip architecture. Upstream merges should resolve trivially:
keep both blocks. Per design spec §5 conflict-resolution playbook.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Create test harness runner

**Files:**
- Create: `cc-tuned/tests/run-all.sh`

- [ ] **Step 1: Write the test runner**

Create `cc-tuned/tests/run-all.sh`:

```bash
#!/usr/bin/env bash
# Run all cc-tuned Tier 1 + Tier 2 tests.
#
# Discovers all test-*.sh files under cc-tuned/tests/ and runs them.
# Each test must exit 0 on pass, non-zero on fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
shopt -s globstar nullglob

total=0
passed=0
failed_tests=()

for test in "$SCRIPT_DIR"/**/test-*.sh; do
    total=$((total + 1))
    echo "----- $(basename "$test") -----"
    if bash "$test"; then
        passed=$((passed + 1))
    else
        failed_tests+=("$test")
    fi
    echo
done

echo "========================================="
echo "  $passed / $total test files passed"
if [ ${#failed_tests[@]} -gt 0 ]; then
    echo "  Failed:"
    for t in "${failed_tests[@]}"; do
        echo "    - $t"
    done
    exit 1
fi
echo "  All test files passed."
```

Make executable:
```bash
chmod +x cc-tuned/tests/run-all.sh
```

- [ ] **Step 2: Run the harness to verify it works**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected output: three test files run (`test-platform-detect.sh`, `test-mcp-introspect.sh`, `test-stubs.sh`), each reports pass/fail counts, harness summary says `3 / 3 test files passed`.

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/tests/run-all.sh
git commit -m "infra(cc-tuned): test harness runner

Discovers and runs all test-*.sh files under cc-tuned/tests/.
Reports per-test pass/fail and overall summary. Exit code reflects
whether all test files passed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Write cc-tuned/README.md

**Files:**
- Create: `cc-tuned/README.md`

- [ ] **Step 1: Write the README**

Create `cc-tuned/README.md`:

```markdown
# cc-tuned Layer

This directory is the **Claude Code-specific layer** of the rsx129921/superpowers fork. It adds CC-aware hooks and (in M3) memory-aware skills on top of the upstream superpowers core, without editing any upstream skill prose.

## Status

| Milestone | Status | What ships |
|-----------|--------|------------|
| M1 Foundation | active | this scaffold + stub hooks |
| M2 Hook Layer | not started | real hook logic |
| M3 Memory-Aware Skills | not started | three companion skills |
| M4 Upstream Sync v1 | not started | first post-fork merge |
| M5 Polish & Docs | not started | final README pass |

See [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md) for the full design.

## What lives here

| Path | Purpose |
|------|---------|
| `hooks/run-hook.cmd` | Polyglot bat+bash dispatcher (mirrors upstream pattern) |
| `hooks/lib/platform-detect.sh` | "Are we on CC?" check, sole source of truth |
| `hooks/lib/mcp-introspect.sh` | Read MCP server names from settings.json files |
| `hooks/cc-session-start` | M2: inject MCP availability + memory-aware directive |
| `hooks/cc-user-prompt-submit` | M2: keyword-match user prompt, re-inject discipline |
| `hooks/cc-pre-compact` | M2: preserve bootstrap across compaction |
| `skills/` | M3: three `memory-aware-*` companion skills |
| `tests/run-all.sh` | Tier 1+2 test entry point |
| `docs/plugin-hooks-research.md` | Decision record on where hook events register |

## Soft-strip guarantees

This layer is designed to coexist with upstream pulls. Properties to maintain:

1. **No upstream skill files are edited.** Ever. Memory-aware skills (M3) *wrap* upstream skills via `Skill` invocation; they do not duplicate or modify upstream content.
2. **Two upstream JSON files have small additive edits.** `.claude-plugin/plugin.json` and `hooks/hooks.json`. Both are list-append edits that conflict rarely. The design spec §5 has the conflict-resolution playbook.
3. **All hooks no-op on non-CC harnesses.** The fork remains installable on Codex, Gemini, Cursor, OpenCode, Copilot CLI — the cc-tuned layer just silently disables itself there.
4. **All hooks fail open.** Exit 0 with empty output on any error. Hooks never block a user turn or session start.

## Running tests

```bash
bash cc-tuned/tests/run-all.sh
```

Expected output ends with `All test files passed.` on a clean run.

## Manual smoke test (Tier 3)

> This procedure becomes meaningful once M2 ships. M1 stubs are silent on success.

1. Open a fresh CC session with this plugin loaded.
2. Send the user message: `let's debug a failing test`.
3. Expected behavior:
   - `cc-user-prompt-submit` matches the `failing` keyword.
   - Injection suggests `superpowers:systematic-debugging`.
   - If `cognee-memory` MCP is up, `memory-aware-debugging` should trigger and recall prior debugging context.
4. If any step doesn't happen, see `cc-tuned/docs/` for troubleshooting.

## Rip-cord

If you ever want to abandon the cc-tuned layer entirely:

```bash
# 1. Delete the layer
git rm -r cc-tuned/

# 2. Revert the two JSON additive edits (find via git log -p plugin.json hooks/hooks.json)
git checkout <upstream-SHA> -- .claude-plugin/plugin.json hooks/hooks.json

# 3. Commit
git commit -m "revert: remove cc-tuned layer"
```

That's it. Soft-strip designed for low commitment.
```

- [ ] **Step 2: Commit**

```bash
git add cc-tuned/README.md
git commit -m "docs(cc-tuned): layer README

Explains the cc-tuned layer's purpose, file layout, soft-strip
guarantees, how to run tests, the manual smoke-test procedure
(meaningful from M2), and the rip-cord steps for abandoning the
layer cleanly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: M1 acceptance verification

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test harness**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: `3 / 3 test files passed`, exit 0.

- [ ] **Step 2: Verify upstream-files invariant**

```bash
git diff upstream/main -- ':!cc-tuned' ':!docs/superpowers/specs' ':!docs/superpowers/plans' ':!.github'
```

Expected output: only two files appear in the diff — `.claude-plugin/plugin.json` and `hooks/hooks.json`. Any other path indicates accidental upstream-content drift.

- [ ] **Step 3: Verify hooks register with CC**

Open a fresh CC session with this plugin loaded. Run `/plugin list` (or equivalent inspection per Task 6 Step 4). Confirm all three cc-tuned hooks are listed alongside the upstream session-start hook.

- [ ] **Step 4: Verify no-op on non-CC**

Simulate a non-CC harness:

```bash
env -i bash cc-tuned/hooks/cc-session-start
env -i bash cc-tuned/hooks/cc-user-prompt-submit </dev/null
env -i bash cc-tuned/hooks/cc-pre-compact
echo "All three exited: $?"
```

Expected: each command prints nothing, final echo reports `All three exited: 0`.

- [ ] **Step 5: Update the M1 umbrella issue**

Open issue #1. Check all sub-task boxes. In a comment, paste:

```
M1 acceptance complete:
- [x] All three hooks register with CC (/plugin list verified)
- [x] Hooks no-op on non-CC harnesses (env -i test verified)
- [x] Upstream skills/ + hooks/ content unchanged (git diff scoped verification)
- [x] Only two expected JSON files diff from upstream

Closes #1.
```

- [ ] **Step 6: Open the M1 PR**

```bash
git push -u origin feature/m1-foundation
gh pr create --repo rsx129921/superpowers --base main --head feature/m1-foundation \
  --title "[M1] Foundation: cc-tuned scaffold, helpers, stub hooks, manifest wiring" \
  --milestone "M1: Foundation" \
  --label "cc-tuned,infra" \
  --body "$(cat <<'BODY'
## Problem

Sets up the foundational scaffolding for the cc-tuned layer. No new
runtime behavior yet — that's M2. This PR makes the layer *registerable*
with Claude Code and establishes the test harness, helpers, and docs that
later milestones build on.

## What this PR changes

- New `cc-tuned/` directory tree (hooks/, hooks/lib/, tests/hooks/, skills/, docs/)
- Polyglot `cc-tuned/hooks/run-hook.cmd` mirroring upstream pattern
- `platform-detect.sh` + unit test
- `mcp-introspect.sh` + unit test
- Three stub hook scripts (cc-session-start, cc-user-prompt-submit, cc-pre-compact)
- Test runner `cc-tuned/tests/run-all.sh`
- Additive edits to `.claude-plugin/plugin.json` and/or `hooks/hooks.json`
  to register the new hook events
- `cc-tuned/README.md` documenting the layer
- `cc-tuned/docs/plugin-hooks-research.md` decision record

## Alternatives considered

- Hard-strip multi-harness files: rejected — keeps upstream merges trivial.
- Place hooks in `hooks/cc-*` (mixed with upstream): rejected — soft-strip cleanliness benefits from a single `cc-tuned/` subtree.
- Skip stub hooks (real logic in same PR as wiring): rejected — separating wiring from logic lets M1 ship and verify registration independently of behavior changes.

## Testing

| Tier | Status | Notes |
|------|--------|-------|
| Tier 1 (hook unit tests) | pass | 16+ assertions across 3 test files via `bash cc-tuned/tests/run-all.sh` |
| Tier 2 (skill structure) | N/A | No skills in M1 |
| Tier 3 (manual session)  | partial | Hooks register; behavior is no-op (real Tier 3 in M2) |

## Existing PRs / Issues

Closes #1.
References spec doc `docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`.

## Self-checks

- [x] Touches only `cc-tuned/` and the two known additive JSON edits
- [x] Hooks no-op on non-CC harnesses (verified via `env -i` test)
- [x] Memory-aware skills degrade gracefully if MCPs absent — N/A, no skills in M1
- [x] One coherent change — M1 foundation only

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Self-Review

After completing Tasks 1-9, run this checklist before requesting review:

**Spec coverage:**
- [ ] §1 File Layout: `cc-tuned/` tree matches spec exactly. (Tasks 2-8)
- [ ] §2.1 cc-session-start: stub exists per Task 5. Real logic deferred to M2 — correctly out of scope here.
- [ ] §2.2 cc-user-prompt-submit: stub exists per Task 5. Real logic deferred to M2.
- [ ] §2.3 cc-pre-compact: stub exists per Task 5. Real logic deferred to M2.
- [ ] §4 JSON manifest edits: addressed in Task 6, gated by Task 1's research.
- [ ] §6 Tier 1 testing harness: Tasks 3, 4, 5 each add tests; Task 7 wires the runner.
- [ ] Goal #3 "No-op on non-CC": platform-detect.sh + every hook stub uses it (Task 3, 5).
- [ ] Goal #2 "Upstream merges trivial": Task 9 Step 2 verifies the upstream-files invariant.

**Placeholder scan:** None expected. Every code block is concrete and runnable.

**Type/name consistency:**
- Hook script names match spec §2: `cc-session-start`, `cc-user-prompt-submit`, `cc-pre-compact`. ✓
- Test names match `test-*.sh` glob in `run-all.sh`. ✓
- File paths consistent across tasks (no `cc-tuned/lib/` vs `cc-tuned/hooks/lib/` mismatch). ✓

**Known plan-time risk:**
- Task 1's empirical research may discover that CC reads BOTH `plugin.json` and `hooks/hooks.json`, requiring edits in both. Task 6 accommodates that — it asks the engineer to "edit one OR both" based on the recorded decision. If Task 1 hits a documentation gap that requires reaching out to Anthropic docs/community, that's a real blocker; flag it on issue #1 and pause M1.

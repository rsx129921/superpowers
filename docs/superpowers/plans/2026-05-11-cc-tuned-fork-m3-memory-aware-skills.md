# CC-Tuned Fork — M3 Memory-Aware Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three companion skills under `cc-tuned/skills/` that wrap the upstream brainstorming/systematic-debugging/writing-plans skills with a RECALL-then-invoke-then-COMMIT-offer pattern. The skills are activated when the cc-session-start hook (M2) detects available memory MCPs (episodic-memory or cognee-memory) and instructs the model to prefer these variants over the base upstream skills.

**Architecture:** Each memory-aware skill is a thin prose wrapper (≤100 lines). It does NOT duplicate the wrapped skill's content. Instead, the body says: (1) RECALL — query episodic-memory and/or cognee-memory for prior context relevant to the task; (2) invoke the upstream skill via the Skill tool and follow its workflow; (3) COMMIT-offer — at the end, propose 1-3 durable facts to cognify and ask the user before committing. Memory writes are NEVER automatic. The skills live at `cc-tuned/skills/<name>/SKILL.md` and are wired into Claude Code via `.claude-plugin/plugin.json`'s `skills` field — keeping the soft-strip isolation (no new files in upstream's `skills/`).

**Tech Stack:** Markdown + YAML frontmatter (the SKILL.md format), bash for the Tier 2 frontmatter validator, no language runtimes.

**Spec reference:** [`docs/superpowers/specs/2026-05-10-cc-tuned-fork-design.md`](../specs/2026-05-10-cc-tuned-fork-design.md) §3 (Memory-Aware Skill Family).

**Umbrella issue:** [#3](https://github.com/rsx129921/superpowers/issues/3)

**Built on top of:** M1 (foundation) + M2 (hook layer, merged 2026-05-11 at 491b14b). cc-session-start already injects MCP availability + memory-aware-variant directive on every session start.

---

## File Structure

**Created in this plan:**

| Path | Responsibility |
|------|----------------|
| `cc-tuned/skills/memory-aware-brainstorming/SKILL.md` | Wraps superpowers:brainstorming with memory-recall pre-step + cognify-offer post-step |
| `cc-tuned/skills/memory-aware-debugging/SKILL.md` | Wraps superpowers:systematic-debugging similarly (root-cause-pattern cognify-offer) |
| `cc-tuned/skills/memory-aware-planning/SKILL.md` | Wraps superpowers:writing-plans similarly (convention cognify-offer) |
| `cc-tuned/tests/skills/test-skill-frontmatter.sh` | Tier 2 validator: each SKILL.md has required frontmatter + wraps a real upstream skill |
| `cc-tuned/docs/cc-plugin-skills-declaration-research.md` | Task 1 decision record on where/how to register cc-tuned skills with CC |

**Modified in this plan:**

| Path | Change |
|------|--------|
| `.claude-plugin/plugin.json` | Possibly add `skills` declaration (gated by Task 1 research; might already auto-discover from cc-tuned/skills/) |
| `cc-tuned/tests/run-all.sh` | Update glob if needed so the new test directory is discovered (the existing glob `**/test-*.sh` should already work) |
| `cc-tuned/README.md` | Status table: M3 → complete. File map: add three skills + new test file + research doc. |

**Out of scope (deferred to M4+):**
- The cc-user-prompt-submit hook currently emits the base skill name (e.g., "superpowers:brainstorming"), not the memory-aware variant. Per design, it relies on cc-session-start's directive + model inference. Tightening this to dynamically map base→variant when MCPs are available is M5 polish, not M3.
- Tier 3 manual smoke test for each skill (controller runs in a real CC session post-merge).
- Adding more memory-aware variants (e.g., memory-aware-tdd) — only three are in scope per spec §3.

---

## Task 1: Research CC plugin skills declaration

**Files:**
- Create: `cc-tuned/docs/cc-plugin-skills-declaration-research.md`

**Why this is first:** Upstream skills live at `skills/<name>/SKILL.md` and are auto-discovered by CC. Our memory-aware skills will live at `cc-tuned/skills/<name>/SKILL.md` (non-default path) so they don't pollute the upstream `skills/` directory. The question: does CC auto-discover from non-default paths, or must we register them in `.claude-plugin/plugin.json`'s `skills` field? Same risk pattern as M1 Task 1 (hooks) and M2 Task 1 (hook JSON contracts) — resolve via empirical research before writing the SKILL.md files.

- [ ] **Step 1: Read upstream skill discovery as the reference pattern**

```bash
ls skills/ | head -10
head -5 skills/brainstorming/SKILL.md
head -5 .claude-plugin/plugin.json
```

Capture:
- Upstream skills live at the default `skills/<name>/SKILL.md` path
- `.claude-plugin/plugin.json` currently has NO `skills` field (auto-discovery handles upstream skills)

- [ ] **Step 2: Check official Claude Code plugin docs for the skills field**

```
WebSearch: "Claude Code plugin manifest skills field declaration .claude-plugin/plugin.json"
WebFetch: https://code.claude.com/docs/en/plugins-reference (re-verify the File Locations / Component path fields table)
```

Capture:
1. Does `plugin.json` support a `skills` array/string field?
2. Are skills at non-default paths discoverable via that field?
3. What's the format? (Array of paths? Array of objects? Glob pattern?)
4. Is there a duplicate-detection error like the one M1 Task 1 found for hooks?

- [ ] **Step 3: Decide where to put the skills**

Two options:
- **Option A**: Put skills at the default `skills/` path (e.g., `skills/memory-aware-brainstorming/SKILL.md`) — auto-discovered, no manifest edit. Cost: mixes our skills with upstream's; risks merge conflicts if upstream ever adds a same-named skill.
- **Option B**: Put skills at `cc-tuned/skills/` AND declare them in `.claude-plugin/plugin.json`'s `skills` field. Cost: a second additive edit to plugin.json (M2 left plugin.json untouched, so this WOULD violate the M1 soft-strip invariant on plugin.json — but it would be a small, well-bounded edit).

If Task 2's docs research shows that `plugin.json` `skills` field is well-supported and works alongside auto-discovery of upstream skills, prefer Option B. Otherwise fall back to Option A.

- [ ] **Step 4: Write the decision record**

Create `cc-tuned/docs/cc-plugin-skills-declaration-research.md`:

```markdown
# Plugin Skills Declaration: Decision Record

**Date:** 2026-05-11
**Decision:** Place cc-tuned skills at `<chosen-path>` and register via `<chosen-mechanism>`.
**Authority:** <docs URL + last-verified date>
**Empirical verification:** Deferred (subagent cannot run /plugin list)

## Findings

- Upstream skill discovery uses `skills/<name>/SKILL.md`. The current `.claude-plugin/plugin.json` has no `skills` field; upstream relies on auto-discovery.
- The plugin spec `skills` field <supports / does not support> non-default paths.
- <Format details>

## Decision and rationale

<Why we chose Option A or Option B. If Option B, note that this is a second additive edit to plugin.json beyond M1's soft-strip baseline; the cost-benefit favors isolation.>

## Implication for Tasks 3-6

Tasks 3, 4, 5 create skills at `<chosen-path>`. Task 6 either edits plugin.json to register them OR is a no-op if auto-discovery handles it.

## Post-merge verification

Run `/plugin list` in a fresh CC session after merge; confirm the three memory-aware-* skills appear.
```

- [ ] **Step 5: Commit**

```bash
git add cc-tuned/docs/cc-plugin-skills-declaration-research.md
git commit -m "$(cat <<'EOF'
research: document CC plugin skills declaration mechanism for M3

Resolves the question of where to place cc-tuned memory-aware skills
and how to register them with Claude Code without polluting the
upstream skills/ directory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Tier 2 skill frontmatter + structure validator (TDD)

**Files:**
- Create: `cc-tuned/tests/skills/test-skill-frontmatter.sh`

**Why before the skill files:** Tier 2 tests assert static properties of the SKILL.md files (frontmatter present, body wraps a real upstream skill). Building the validator first means each skill (Tasks 3-5) can be checked the moment it's written.

The validator inspects each `cc-tuned/skills/*/SKILL.md` and asserts:
1. YAML frontmatter delimited by `---` lines is present at the top.
2. `name:` field is present, matches the directory name (e.g., `cc-tuned/skills/memory-aware-brainstorming/SKILL.md` must have `name: memory-aware-brainstorming`).
3. `description:` field is present and non-empty.
4. The body (after the second `---`) references at least one upstream skill via the pattern `superpowers:<name>` where `<name>` is one of the upstream skill directories (brainstorming, systematic-debugging, writing-plans, etc.) — this enforces the "wrap, don't replace" architectural rule.

- [ ] **Step 1: Write the failing test**

Create `cc-tuned/tests/skills/test-skill-frontmatter.sh`:

```bash
#!/usr/bin/env bash
# Tier 2 unit test for cc-tuned/skills/*/SKILL.md files.
#
# Each cc-tuned skill must:
#   - Start with YAML frontmatter (--- delimiters)
#   - Have a `name:` field matching its directory name
#   - Have a non-empty `description:` field
#   - Body must reference at least one upstream skill (superpowers:<name>)
#     enforcing the "wrap, don't replace" architectural rule

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../skills"
UPSTREAM_SKILLS_DIR="${SCRIPT_DIR}/../../../skills"

fail=0
pass=0

# Collect names of upstream skills for reference-validation
upstream_skill_names=$(ls "$UPSTREAM_SKILLS_DIR" 2>/dev/null | tr '\n' '|' | sed 's/|$//')

echo "test-skill-frontmatter.sh"

if [ ! -d "$SKILLS_DIR" ] || [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null | grep -v '^\.gitkeep$' || true)" ]; then
    echo "  (no cc-tuned skills yet — test passes vacuously)"
    echo "  0 passed, 0 failed"
    exit 0
fi

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"

    if [ ! -f "$skill_file" ]; then
        echo "  FAIL: $skill_name has no SKILL.md"
        fail=$((fail + 1))
        continue
    fi

    # Read first ~30 lines to inspect frontmatter cheaply
    head_content=$(head -30 "$skill_file")

    # 1. Frontmatter delimiters
    if printf '%s' "$head_content" | grep -qE '^---$'; then
        delim_count=$(printf '%s' "$head_content" | grep -cE '^---$')
        if [ "$delim_count" -ge 2 ]; then
            echo "  pass: $skill_name: frontmatter delimited"
            pass=$((pass + 1))
        else
            echo "  FAIL: $skill_name: missing second --- delimiter"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $skill_name: no frontmatter --- delimiter"
        fail=$((fail + 1))
    fi

    # 2. name: field matches directory
    if printf '%s' "$head_content" | grep -qE "^name:\s*${skill_name}\s*$"; then
        echo "  pass: $skill_name: name field matches directory"
        pass=$((pass + 1))
    else
        echo "  FAIL: $skill_name: name field missing or mismatched"
        fail=$((fail + 1))
    fi

    # 3. description: field present and non-empty
    desc_line=$(printf '%s' "$head_content" | grep -E '^description:' | head -1 || true)
    if [ -n "$desc_line" ]; then
        # Strip "description:" prefix and any surrounding whitespace/quotes
        desc_value=$(printf '%s' "$desc_line" | sed -E 's/^description:\s*//; s/^"//; s/"$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -n "$desc_value" ]; then
            echo "  pass: $skill_name: description present and non-empty"
            pass=$((pass + 1))
        else
            echo "  FAIL: $skill_name: description present but empty"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $skill_name: description missing"
        fail=$((fail + 1))
    fi

    # 4. Body references at least one upstream skill via superpowers:<name>
    if [ -n "$upstream_skill_names" ] && grep -qE "superpowers:(${upstream_skill_names})" "$skill_file"; then
        echo "  pass: $skill_name: body references an upstream skill (wrap-don't-replace)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $skill_name: body does not reference any upstream skill (must wrap, not replace)"
        fail=$((fail + 1))
    fi
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
```

Make executable:
```bash
chmod +x cc-tuned/tests/skills/test-skill-frontmatter.sh
mkdir -p cc-tuned/skills  # ensure the dir exists (M1 created it)
touch cc-tuned/skills/.gitkeep  # M1 already created this; idempotent
```

- [ ] **Step 2: Run test to verify it passes vacuously**

```bash
bash cc-tuned/tests/skills/test-skill-frontmatter.sh
```

Expected: `(no cc-tuned skills yet — test passes vacuously) / 0 passed, 0 failed`. The validator should pass cleanly when no skills exist yet — Tasks 3-5 will add skills that increase the pass count.

This is intentional: we want the validator to exist BEFORE the skills so each subsequent task can run it for live feedback.

- [ ] **Step 3: Commit (with --chmod=+x)**

```bash
git add cc-tuned/tests/skills/test-skill-frontmatter.sh
git update-index --chmod=+x cc-tuned/tests/skills/test-skill-frontmatter.sh
git commit -m "$(cat <<'EOF'
test(cc-tuned): Tier 2 skill frontmatter + structure validator

Validates each cc-tuned/skills/*/SKILL.md file:
- Has YAML frontmatter delimited by ---
- name: field matches directory name
- description: field present and non-empty
- Body references at least one upstream skill via superpowers:<name>,
  enforcing the "wrap, don't replace" architectural rule

Vacuous pass when no skills exist yet — count rises as Tasks 3-5
add memory-aware-brainstorming / -debugging / -planning.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Verify mode:
```bash
git ls-tree HEAD cc-tuned/tests/skills/test-skill-frontmatter.sh
```
Expected: 100755.

---

## Task 3: memory-aware-brainstorming SKILL.md

**Files:**
- Create: `cc-tuned/skills/memory-aware-brainstorming/SKILL.md`

**Behavior per spec §3.1:**

1. **RECALL** — Before the first clarifying question:
   - If episodic-memory MCP is available, search for prior conversations on this topic (project name + 2-3 concepts from user message).
   - If cognee-memory MCP is available, GRAPH_COMPLETION query: *"what conventions or decisions has the user made about `<topic>` in `<project>`?"*
   - Surface findings: *"I found prior context on this. Should I build on it, or are we starting fresh?"*
   - Empty result → say so briefly and proceed.
2. **BRAINSTORM** — Invoke `superpowers:brainstorming` via the Skill tool and follow its checklist exactly.
3. **COMMIT-offer** — After design is approved AND spec written:
   - Identify 1-3 durable decisions worth future recall.
   - Offer one-sentence cognify candidates.
   - Wait for user approval. Never auto-commit.

- [ ] **Step 1: Write the SKILL.md**

Create `cc-tuned/skills/memory-aware-brainstorming/SKILL.md`:

```markdown
---
name: memory-aware-brainstorming
description: Use this BEFORE any creative work when memory MCPs (episodic-memory or cognee-memory) are available — recall prior context first, then brainstorm, then offer to commit durable decisions to memory.
---

# Memory-Aware Brainstorming

This skill is a thin wrapper around `superpowers:brainstorming`. It adds two pre/post steps that exploit available memory MCPs (episodic-memory, cognee-memory) so prior context informs the brainstorming session and durable decisions are offered for long-term memory at the end.

**Activation:** Use this skill instead of `superpowers:brainstorming` when the cc-session-start hook has injected "Available MCPs:" containing `episodic-memory` or `cognee-memory`. If neither is present, fall back to plain `superpowers:brainstorming`.

## The Process

### 1. RECALL — before the first clarifying question

Before invoking `superpowers:brainstorming`, query available memory MCPs for prior context.

**If episodic-memory MCP is available:**
- Extract 2-3 key concepts from the user's message (project name + topic terms).
- Search episodic-memory for prior conversations matching those concepts.
- If the search returns hits, read the top one or two — they may contain decisions, designs, or constraints worth surfacing.

**If cognee-memory MCP is available:**
- Run a GRAPH_COMPLETION search with a focused question, e.g.:
  > *"What conventions or design decisions has the user made about `<topic>` in `<project>`?"*

**Surface findings to the user:**
- If you found prior context, summarize it in 1-2 sentences and ask: *"I found prior context on this — should I build on it, or are we starting fresh?"*
- If you found nothing, mention that briefly: *"No prior memory matches; we're starting fresh."*

**Time-box the recall.** If an MCP doesn't respond promptly, do not block — log internally and proceed without that source. Memory recall is a help, not a blocker.

### 2. BRAINSTORM — invoke superpowers:brainstorming

Invoke `superpowers:brainstorming` via the Skill tool. Follow its checklist exactly — clarifying questions one at a time, propose 2-3 approaches with trade-offs, present the design in sections, write to `docs/superpowers/specs/`.

If the RECALL step found prior context the user wants to build on, fold that into the questions and the design proposal — but do not skip the brainstorming flow; the value of the skill is the structured discovery.

### 3. COMMIT-offer — after the design is approved AND committed

Once the spec has been written to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and the user has signed off, identify **1-3 durable decisions** from the session that would matter in future sessions on this or adjacent projects.

A durable decision is:
- A convention you can quote in one sentence ("project X uses Y for Z because W").
- A trade-off rationale that explains why an option was chosen over alternatives.
- A constraint discovered during discussion that isn't visible in the spec itself.

Surface them to the user:
> *"Three things from this session would be worth committing to long-term memory: (1) ..., (2) ..., (3) .... Want me to cognify them?"*

**Wait for the user to approve before invoking cognee-memory's cognify tool.** Never auto-commit. If the user declines, do not retry.

## What this skill is NOT

- It is not a replacement for `superpowers:brainstorming`. The wrapped skill does the actual brainstorming work; this wrapper only adds memory-recall pre-step and cognify-offer post-step.
- It is not a place to put memory-MCP-specific brainstorming logic. The brainstorming flow itself is unchanged — only the bookends change.
- It does not handle architectural decisions outside the user's project scope — its memory queries are project-scoped.
```

- [ ] **Step 2: Run the validator to confirm the skill is structurally valid**

```bash
bash cc-tuned/tests/skills/test-skill-frontmatter.sh
```

Expected: 4 assertions pass for `memory-aware-brainstorming` (frontmatter delimited, name match, description present, references superpowers:brainstorming). Total: 4 passed.

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/skills/memory-aware-brainstorming/SKILL.md
git commit -m "$(cat <<'EOF'
feat(cc-tuned): memory-aware-brainstorming skill

Wraps superpowers:brainstorming with RECALL-then-BRAINSTORM-then-
COMMIT-offer. Pre-step queries episodic-memory + cognee-memory for
prior context on the user's topic; main step invokes the upstream
brainstorming skill unchanged; post-step offers 1-3 durable decisions
for cognification (never auto-commits).

Per design spec §3.1. Activates when cc-session-start hook detects
episodic-memory or cognee-memory in the available MCPs list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: memory-aware-debugging SKILL.md

**Files:**
- Create: `cc-tuned/skills/memory-aware-debugging/SKILL.md`

**Behavior per spec §3.2:**

1. **RECALL**:
   - episodic-memory: search "<error message>" + project name. Did we hit this before?
   - cognee-memory: GRAPH_COMPLETION *"have we resolved errors of type `<category>` in `<project>`? what was the root cause?"*
   - If a prior fix is found, surface it: *"We hit this in `<session>`, root cause was `<X>`. Does that apply here?"*
2. **DEBUG** — Invoke `superpowers:systematic-debugging`.
3. **COMMIT-offer** — After root cause identified and fix verified:
   - Distill: root cause (1 sentence), signal that pointed to it (1 sentence).
   - Offer to cognify as a project-tagged fact.
   - Skip if the bug was trivial (typo, off-by-one).

- [ ] **Step 1: Write the SKILL.md**

Create `cc-tuned/skills/memory-aware-debugging/SKILL.md`:

```markdown
---
name: memory-aware-debugging
description: Use when encountering any bug, test failure, or unexpected behavior AND memory MCPs (episodic-memory or cognee-memory) are available — recall prior debugging context first, then systematic-debug, then commit root-cause patterns for future recall.
---

# Memory-Aware Debugging

A thin wrapper around `superpowers:systematic-debugging`. Adds memory-recall pre-step and root-cause-pattern cognify-offer post-step. Of the three memory-aware skills in this layer, this one has the highest recall value: debugging the same class of bug twice is the most expensive recurring waste in software work, and a memory layer that surfaces "we hit this in March, root cause was X" before debugging starts saves real time.

**Activation:** Use this skill instead of `superpowers:systematic-debugging` when the cc-session-start hook has injected "Available MCPs:" containing `episodic-memory` or `cognee-memory`. If neither is present, fall back to plain `superpowers:systematic-debugging`.

## The Process

### 1. RECALL — before forming any debugging hypothesis

Before invoking `superpowers:systematic-debugging`, query memory for prior occurrences of this bug or its class.

**If episodic-memory MCP is available:**
- Search for the literal error message (or its salient terms) plus the project name.
- If you find a hit, read the top one — it may contain the root cause and fix from a prior session.

**If cognee-memory MCP is available:**
- Run a GRAPH_COMPLETION search:
  > *"Have we resolved errors of type `<error-category>` in `<project>`? What was the root cause?"*
- Where `<error-category>` is a generalized form of the error (e.g., "permission denied on hook invocation", "JSON parse error in MCP introspection").

**Surface findings to the user:**
- If you found a prior fix, summarize it: *"We hit something like this in `<prior-session-date>`. Root cause was `<X>`. Does that apply here, or is this a different shape?"*
- If you found nothing, say so briefly and proceed.

**Time-box the recall.** Same rule as memory-aware-brainstorming — memory queries must not block.

### 2. DEBUG — invoke superpowers:systematic-debugging

Invoke `superpowers:systematic-debugging` via the Skill tool. Follow its discipline exactly.

If the RECALL step found a prior fix, treat it as a hypothesis to test (per systematic-debugging's discipline), not as a definite answer. The bug may look the same but have a different root cause — let the systematic process confirm or refute.

### 3. COMMIT-offer — after root cause identified AND fix verified

Once the root cause is identified and the fix is verified (tests pass, regression doesn't recur), distill the lesson into two sentences:

1. **Root cause** (one sentence): "Hooks fail with Permission denied on Unix because Git on Windows doesn't track the execute bit unless `git update-index --chmod=+x` is run."
2. **Signal** (one sentence): "The symptom was the cc-session-start dispatch never running on first-launch on the CI macOS runner."

Offer to cognify them:
> *"Two things worth committing to memory: root cause = `<root-cause>`; signal = `<signal>`. Want me to cognify?"*

**Skip if the bug was trivial.** Don't pollute memory with typos, off-by-ones, or obvious copy-paste errors. Memory is for patterns; trivial bugs are noise.

**Wait for user approval before invoking cognify.** Never auto-commit.

## What this skill is NOT

- It is not a replacement for `superpowers:systematic-debugging`. The wrapped skill drives the actual investigation; this wrapper only adds recall pre-step and root-cause cognify post-step.
- It does not bypass systematic-debugging's discipline. If RECALL surfaces a likely root cause, that's a hypothesis — verify it, don't assume.
```

- [ ] **Step 2: Run the validator**

```bash
bash cc-tuned/tests/skills/test-skill-frontmatter.sh
```

Expected: 8 assertions pass (4 from Task 3 + 4 from this skill).

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/skills/memory-aware-debugging/SKILL.md
git commit -m "$(cat <<'EOF'
feat(cc-tuned): memory-aware-debugging skill

Wraps superpowers:systematic-debugging with RECALL-DEBUG-COMMIT-offer.
Pre-step queries memory for prior occurrences of the bug or its class;
main step invokes upstream systematic-debugging unchanged; post-step
distills root cause + signal into two sentences and offers to cognify
(skips trivial bugs; never auto-commits).

Per design spec §3.2. Highest-recall-value of the three memory-aware
skills: debugging the same bug class twice is the most expensive
recurring waste in software work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: memory-aware-planning SKILL.md

**Files:**
- Create: `cc-tuned/skills/memory-aware-planning/SKILL.md`

**Behavior per spec §3.3:**

1. **RECALL**:
   - cognee-memory GRAPH_COMPLETION: *"What conventions does `<project>` follow for `<area>`?"* and *"What tools/libraries/patterns does `<project>` use for `<area>`?"*
   - episodic-memory: prior plans in the same area.
   - Synthesize into a "Conventions to follow" section the plan must respect.
2. **PLAN** — Invoke `superpowers:writing-plans`.
3. **COMMIT-offer** — If the plan introduces a new convention:
   - Offer to cognify: *"`<project>` uses `<pattern>` for `<area>` because `<reason>`."*
   - Wait for approval.

- [ ] **Step 1: Write the SKILL.md**

Create `cc-tuned/skills/memory-aware-planning/SKILL.md`:

```markdown
---
name: memory-aware-planning
description: Use when starting any implementation plan AND memory MCPs (episodic-memory or cognee-memory) are available — recall project conventions and prior planning patterns first, then write the plan, then commit new conventions for future recall.
---

# Memory-Aware Planning

A thin wrapper around `superpowers:writing-plans`. Adds a convention-recall pre-step (so the plan respects existing project decisions) and a new-convention cognify-offer post-step (so future planning sessions inherit today's decisions).

**Activation:** Use this skill instead of `superpowers:writing-plans` when the cc-session-start hook has injected "Available MCPs:" containing `episodic-memory` or `cognee-memory`. If neither is present, fall back to plain `superpowers:writing-plans`.

## The Process

### 1. RECALL — before writing the plan structure

Before invoking `superpowers:writing-plans`, query memory for project conventions that the new plan must respect.

**If cognee-memory MCP is available:**
- Run two GRAPH_COMPLETION searches:
  1. *"What conventions does `<project>` follow for `<area-being-planned>`?"*
  2. *"What tools, libraries, or patterns does `<project>` use for `<area-being-planned>`?"*
- `<area-being-planned>` is the high-level domain (e.g., "testing", "hook scripts", "JSON output").

**If episodic-memory MCP is available:**
- Search for prior plans in the same area (e.g., M1 plan, M2 plan if planning M3 work).
- Read the top one or two — they may contain task patterns or sequencing decisions worth preserving.

**Synthesize findings into a "Conventions to follow" list.** This becomes part of the plan's context — the implementer reading the plan should see at the top: *"Existing conventions this plan respects: ..."*. The list should be specific (e.g., *"All bash hook scripts use the polyglot run-hook.cmd dispatcher"*) rather than generic (*"follow project style"*).

**Time-box the recall.** Same rule as the other memory-aware skills.

### 2. PLAN — invoke superpowers:writing-plans

Invoke `superpowers:writing-plans` via the Skill tool. Follow its structure (bite-sized tasks, exact file paths, complete code in every step, TDD).

Fold the "Conventions to follow" list into the plan's File Structure section and reference it in each task that touches a relevant area. Do not invent new conventions if existing ones cover the case — that's the whole point of the recall step.

### 3. COMMIT-offer — after the plan is approved

If the planning session introduced a **new** convention (one that wasn't already in memory), offer to cognify it:

> *"This plan introduces a new convention: `<project>` uses `<pattern>` for `<area>` because `<reason>`. Want me to cognify?"*

A new convention is worth memory if:
- It will apply to future plans in the same project.
- It encodes a trade-off rationale that isn't obvious from the code alone.
- It's specific enough to be useful (not "use clean code", but "use shared bash lib for JSON escaping to avoid bash 5.3+ heredoc hang").

If the plan only re-applied existing conventions, do not commit anything — there's nothing new to remember.

**Wait for user approval.** Never auto-commit.

## What this skill is NOT

- It is not a replacement for `superpowers:writing-plans`. The wrapped skill structures the plan; this wrapper only adds convention recall + new-convention cognify-offer.
- It does not bypass the writing-plans bite-sized-task discipline. RECALL is informational input to the plan structure, not a substitute for the plan.
```

- [ ] **Step 2: Run the validator**

```bash
bash cc-tuned/tests/skills/test-skill-frontmatter.sh
```

Expected: 12 assertions pass (4 each × 3 skills).

- [ ] **Step 3: Commit**

```bash
git add cc-tuned/skills/memory-aware-planning/SKILL.md
git commit -m "$(cat <<'EOF'
feat(cc-tuned): memory-aware-planning skill

Wraps superpowers:writing-plans with RECALL-PLAN-COMMIT-offer.
Pre-step queries memory for project conventions + prior plans in
the same area; main step invokes upstream writing-plans unchanged;
post-step offers to cognify ONLY new conventions (skips when the
plan only re-applies existing ones).

Per design spec §3.3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Register cc-tuned skills with Claude Code (gated on Task 1)

**Files (one OR none, per Task 1 decision):**
- Possibly modify: `.claude-plugin/plugin.json`

**Re-read Task 1 decision before starting:**

```bash
cat cc-tuned/docs/cc-plugin-skills-declaration-research.md
```

### Path A: Auto-discovery handles it (Option A from Task 1)

If Task 1 determined that placing skills at the default `skills/` path works and we chose Option A: **this task is a no-op.** The skills are already in `skills/` and CC discovers them automatically. Skip to the verification step at the bottom.

### Path B: plugin.json declaration needed (Option B from Task 1)

If Task 1 determined we need to declare the skills in `.claude-plugin/plugin.json`:

- [ ] **Step 1: Add the `skills` field to plugin.json**

The exact format depends on Task 1's research. Most likely shape:

```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "version": "5.1.0",
  ...
  "skills": [
    "cc-tuned/skills/memory-aware-brainstorming/SKILL.md",
    "cc-tuned/skills/memory-aware-debugging/SKILL.md",
    "cc-tuned/skills/memory-aware-planning/SKILL.md"
  ]
}
```

OR the spec might allow a glob:

```json
  "skills": "cc-tuned/skills/*/SKILL.md"
```

Use the form Task 1 documented as valid.

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"
```

- [ ] **Step 3: Confirm hooks.json was NOT touched**

The soft-strip invariant for M3 should remain: only hooks/hooks.json AND plugin.json differ from upstream. Verify:

```bash
git diff upstream/main..HEAD -- ':!cc-tuned' ':!docs/superpowers/specs' ':!docs/superpowers/plans' ':!.github' --stat
```

Expected: two files — `.claude-plugin/plugin.json` AND `hooks/hooks.json`. (M2 left only hooks.json; M3 adds plugin.json. Both are tiny additive edits.)

- [ ] **Step 4: Commit (Path B only)**

```bash
git add .claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
feat(cc-tuned): register memory-aware skills in plugin.json

Adds a `skills` field to .claude-plugin/plugin.json pointing at the
three memory-aware-* skills under cc-tuned/skills/. Per M3 Task 1
research, CC's plugin spec supports declaring skills at non-default
paths via this field.

This is the second small additive edit to an upstream JSON file in
the soft-strip architecture (first being hooks/hooks.json in M1).
Both edits are list-append-style and resolve trivially on upstream
pulls.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Common: post-registration verification (both paths)

Whether Path A or Path B, run:

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: all test files pass (including the skill validator now reporting 12 assertions).

For empirical /plugin list verification, that's deferred to the controller post-merge (subagents can't run interactive CC commands).

---

## Task 7: Update cc-tuned/README.md for M3

**Files:**
- Modify: `cc-tuned/README.md`

- [ ] **Step 1: Update the Status table**

Find the row for M3 in the Status table. Change from:
```
| M3 Memory-Aware Skills | not started | three companion skills |
```
to:
```
| M3 Memory-Aware Skills | complete | memory-aware-brainstorming / -debugging / -planning |
```

- [ ] **Step 2: Update the "What lives here" table**

Add three new rows for the skills + the new test file + research doc. The table after editing should contain (in addition to the existing M1+M2 rows):

```
| `skills/memory-aware-brainstorming/SKILL.md` | M3: memory-recall + cognify-offer wrapper around superpowers:brainstorming |
| `skills/memory-aware-debugging/SKILL.md` | M3: same pattern wrapping superpowers:systematic-debugging |
| `skills/memory-aware-planning/SKILL.md` | M3: same pattern wrapping superpowers:writing-plans |
| `tests/skills/test-skill-frontmatter.sh` | Tier 2 validator: SKILL.md frontmatter + wrap-don't-replace structure |
| `docs/cc-plugin-skills-declaration-research.md` | Decision record on where to put skills + how to register (M3 Task 1) |
```

Remove the placeholder row that previously said:
```
| `skills/` | M3: three `memory-aware-*` companion skills |
```
(now replaced by three specific entries.)

- [ ] **Step 3: Update the Manual smoke test section**

Add a **Check 4** to the existing Tier 3 procedure for the memory-aware skills:

```markdown
### Check 4: memory-aware skill activation (M3)
Confirm at least one of `episodic-memory` or `cognee-memory` is configured. Open a fresh CC session and send:
> "let's design a small library for parsing config files"

Expected sequence:
1. cc-session-start injects MCPs including the memory-aware directive.
2. cc-user-prompt-submit fires on "let's design" pattern (well, that's not in the M2 keyword table; use "let's build" or "new feature" if Check 2's example wording doesn't trigger).
3. Claude invokes `memory-aware-brainstorming` (not bare `brainstorming`) because the SessionStart directive said to prefer the memory-aware variant when MCPs are up.
4. The first response includes a RECALL summary from episodic-memory + cognee-memory.

If Claude invokes plain `superpowers:brainstorming` instead, the SessionStart directive is being ignored — escalate to controller for diagnosis.
```

- [ ] **Step 4: Commit**

```bash
git add cc-tuned/README.md
git commit -m "$(cat <<'EOF'
docs(cc-tuned): update README for M3 completion

- Status table: M3 → complete
- File map: replace placeholder skills/ row with three concrete skill
  files + tests/skills/test-skill-frontmatter.sh + research doc
- Manual smoke test: add Check 4 for memory-aware-* skill activation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: M3 acceptance verification + PR

**Files:** none modified — verification + GH operations only.

- [ ] **Step 1: Run the full test harness**

```bash
bash cc-tuned/tests/run-all.sh
```

Expected: 6 test files now (5 from M2 + the new skill validator). All green. Total assertions ≈ 70.

- [ ] **Step 2: Verify soft-strip invariant**

```bash
git fetch upstream 2>/dev/null || true
git diff upstream/main..HEAD -- ':!cc-tuned' ':!docs/superpowers/specs' ':!docs/superpowers/plans' ':!.github' --stat
```

Expected (per Task 1's decision):
- Path A (auto-discovery): only `hooks/hooks.json` (unchanged from M2)
- Path B (plugin.json declaration): two files — `hooks/hooks.json` + `.claude-plugin/plugin.json`

Anything else is drift.

- [ ] **Step 3: Verify skill files exist + validate**

```bash
ls cc-tuned/skills/*/SKILL.md
bash cc-tuned/tests/skills/test-skill-frontmatter.sh
```

Expected: three SKILL.md files listed. Validator reports 12 passed, 0 failed.

- [ ] **Step 4: Update umbrella issue #3**

```bash
gh issue comment 3 --repo rsx129921/superpowers --body "$(cat <<'EOF'
## M3 Acceptance Verification

All M3 sub-tasks complete on `feature/m3-memory-aware-skills`:

- [x] Task 1: CC plugin skills declaration researched + decision record
- [x] Task 2: Tier 2 skill frontmatter + structure validator
- [x] Task 3: memory-aware-brainstorming SKILL.md
- [x] Task 4: memory-aware-debugging SKILL.md
- [x] Task 5: memory-aware-planning SKILL.md
- [x] Task 6: skills registered with CC (per Task 1 decision)
- [x] Task 7: cc-tuned/README.md updated

## Acceptance verification

- [x] `bash cc-tuned/tests/run-all.sh`: all test files passed
- [x] Three SKILL.md files exist with valid frontmatter + wrap-don't-replace structure
- [x] Soft-strip invariant intact (only hooks.json + possibly plugin.json differ from upstream)
- [ ] **DEFERRED to controller** — Tier 3 manual smoke test for skill activation in a real CC session

Closes this issue on PR merge.
EOF
)"
```

- [ ] **Step 5: Push and open PR**

```bash
git push -u origin feature/m3-memory-aware-skills
gh pr create --repo rsx129921/superpowers \
  --base main \
  --head feature/m3-memory-aware-skills \
  --title "[M3] Memory-Aware Skills: brainstorming, debugging, planning" \
  --body "$(cat <<'BODY'
## Problem

M1+M2 shipped the cc-tuned scaffold + hook layer. The hooks inject "Available MCPs:" and a directive to prefer memory-aware skill variants, but those variants didn't exist until now. M3 ships the three memory-aware skills.

## What this PR changes

- Adds `cc-tuned/skills/memory-aware-brainstorming/SKILL.md`
- Adds `cc-tuned/skills/memory-aware-debugging/SKILL.md`
- Adds `cc-tuned/skills/memory-aware-planning/SKILL.md`
- Adds `cc-tuned/tests/skills/test-skill-frontmatter.sh` (Tier 2 validator)
- Adds `cc-tuned/docs/cc-plugin-skills-declaration-research.md` (Task 1 decision record)
- Possibly modifies `.claude-plugin/plugin.json` (Path B: declare skills at non-default path)
- Updates `cc-tuned/README.md` (status complete, file map, Check 4 in smoke test)

Each skill is a thin wrapper (~80 lines) around its upstream counterpart. The body adds RECALL pre-step (query episodic + cognee) and COMMIT-offer post-step (propose 1-3 durable facts for cognification, user approval required). The middle phase invokes the upstream skill via the Skill tool — never duplicating its content.

## Alternatives considered

- Put skills under upstream `skills/` directory: rejected — pollutes upstream's directory; risks merge conflicts. cc-tuned/ isolation is the soft-strip discipline.
- Inline memory-recall logic in cc-session-start hook (no skill files): rejected — skills are the right abstraction for "the model should do X workflow"; hooks are for context injection.
- Add more memory-aware variants (e.g., memory-aware-tdd, memory-aware-code-review): rejected — only three skills are in scope per design spec §3.

## Testing

| Tier | Status | Notes |
|------|--------|-------|
| Tier 1 (hook unit tests) | unchanged | 58 assertions still pass from M1+M2 |
| Tier 2 (skill structure) | pass | 12 assertions across 3 skills via test-skill-frontmatter.sh |
| Tier 3 (manual session)  | deferred | Procedure documented in cc-tuned/README.md Check 4 |

## Existing PRs / Issues

Closes #3.
Builds on M1 (PR #6) and M2 (PR #8).

## Self-checks

- [x] Touches only `cc-tuned/`, possibly `.claude-plugin/plugin.json`, and `docs/superpowers/plans/`
- [x] Hooks unchanged from M2
- [x] Memory-aware skills degrade gracefully if MCPs absent (each SKILL.md explicitly says "fall back to plain upstream skill when MCPs unavailable")
- [x] No memory write is automatic — all three skills end with cognify-offer + wait-for-approval
- [x] One coherent change — M3 skill family only

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

- [ ] **Step 6: Attach milestone + labels via REST API**

```bash
PR_NUMBER=$(gh pr list --repo rsx129921/superpowers --head feature/m3-memory-aware-skills --json number -q '.[0].number')
gh api repos/rsx129921/superpowers/issues/$PR_NUMBER --method PATCH -F milestone=3 -f 'labels[]=cc-tuned' -f 'labels[]=skill' 2>&1 | head -5
```

---

## Self-Review

**Spec coverage:**
- [ ] §3.1 memory-aware-brainstorming: RECALL/BRAINSTORM/COMMIT-offer — Task 3
- [ ] §3.2 memory-aware-debugging: same pattern — Task 4
- [ ] §3.3 memory-aware-planning: same pattern — Task 5
- [ ] Cross-cutting "wrap don't replace" — validator (Task 2) enforces structurally; each SKILL.md explicitly invokes the upstream skill via Skill tool in body prose
- [ ] No automatic memory writes — every COMMIT-offer step says "wait for user approval"
- [ ] Tier 2 skill structure tests per spec §6 — Task 2 + validator runs for each new skill in Tasks 3/4/5
- [ ] Soft-strip invariant — Task 6 only edits plugin.json if Task 1 chose Path B; otherwise unchanged from M2

**Placeholder scan:** Task 6's "Path A vs Path B" gating is conditional on research, not a placeholder. Task 1's decision-record template has `<chosen-path>`, `<chosen-mechanism>` for the implementer to fill in — those are intentional template slots, not stale TODOs.

**Type/name consistency:**
- Skill names (`memory-aware-brainstorming`, `memory-aware-debugging`, `memory-aware-planning`) consistent across tasks.
- Validator script name `test-skill-frontmatter.sh` consistent.
- Directory structure `cc-tuned/skills/<name>/SKILL.md` consistent.

**Known plan-time risks:**
- The cc-session-start hook injects "prefer memory-aware-* variant" as a soft directive. The model may not always follow it. M3 ships the skills; M5 polish can refine the directive wording or add hook-level base→variant mapping if Tier 3 observation shows unreliability.
- Skill files are prose — Tier 2 tests check structure but not behavior. Whether the model actually queries MCPs in the RECALL step is verifiable only in Tier 3 manual smoke tests.
- Task 1's research may discover that CC's `skills` field in plugin.json behaves unexpectedly (similar to M1 Task 1's hooks-field discovery). Task 6 accommodates both Path A (auto-discovery) and Path B (manifest declaration). Worst case: M3 ships with Path A and a follow-up cleanup if Path A turns out to have a footgun.

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

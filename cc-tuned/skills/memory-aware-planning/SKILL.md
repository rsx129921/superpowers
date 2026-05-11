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

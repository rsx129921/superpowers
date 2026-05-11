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

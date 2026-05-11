---
name: MCP Integration Proposal (fork-specific)
about: Propose a new MCP server as recall-aware in the memory-aware skill family
labels: skill, cc-tuned, enhancement
---

<!--
For the rsx129921/superpowers fork. Use when you've added a new MCP server
to your stack and want the memory-aware-* skills (brainstorming, debugging,
planning) to reach for it during their RECALL step.
-->

## Which MCP server?
<!-- Server name as it appears in ~/.claude/settings.json mcpServers config -->

## What does it expose?
<!-- Tools, prompts, resources. What's the value proposition for recall? -->

## Which memory-aware skill(s) should use it?

- [ ] memory-aware-brainstorming (recall prior context before brainstorming)
- [ ] memory-aware-debugging (recall prior bug patterns + root causes)
- [ ] memory-aware-planning (recall conventions + prior planning patterns)

## How should the RECALL step query it?
<!-- Example query/tool call shape. e.g. "search for project name + 2-3
     concepts" or "GRAPH_COMPLETION 'what conventions does <project>
     follow for <area>?'" -->

## How should the COMMIT step write to it?
<!-- Or "N/A — read-only" if recall-only. -->

## Graceful degradation
<!-- Confirm: if this MCP is not available, the skill must continue
     working using just episodic-memory + cognee-memory. -->

- [ ] Skill degrades gracefully if this MCP is absent

---
name: Upstream Sync (fork-specific)
about: Track a merge from obra/superpowers into rsx129921/superpowers
labels: upstream-sync, infra
---

<!--
For the rsx129921/superpowers fork. File one of these per upstream
merge (typically once per upstream release tag). Records what came in
and how conflicts resolved.
-->

## Upstream source
<!-- Upstream tag or SHA, and the commit message of the upstream tag -->

- Upstream tag/SHA:
- Upstream release notes URL:

## Files changed by upstream

<!-- Output of: git diff --stat <last-merge-base>..upstream/main -->

```
paste git diff --stat output
```

## Conflicts encountered

Per the fork's design spec, only two files should conflict by design:

- [ ] `.claude-plugin/plugin.json` — kept both: upstream changes + our hooks block
- [ ] `hooks/hooks.json` — kept both: upstream entries + our cc-* entries
- [ ] No conflicts
- [ ] **Unexpected conflict somewhere else** — investigate before resolving:

<!-- If a conflict appears outside the two expected files, that's drift.
     Document what conflicted, what you did, and whether the design
     needs to change. -->

## Post-merge verification

- [ ] `bash cc-tuned/tests/run-all.sh` passes
- [ ] Tier 3 smoke test still produces expected behavior
- [ ] CC `/plugin list` still shows the cc-tuned hooks registered

## Merge commit SHA
<!-- After committing the merge, paste the SHA here for future reference -->

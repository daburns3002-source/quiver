## What this changes

<!-- One paragraph. What the player can now do that they could not before. -->

## Phase

<!-- e.g. Phase 1 — core feel. See docs/ROADMAP.md -->

## Reviewer focus

<!-- Point Codex at the risky part. Delete the lines that don't apply. -->

- [ ] New remote or client-supplied value — check server-side validation
- [ ] Touches the projectile modifier pipeline
- [ ] Touches run state or anything that could become singleton
- [ ] Runs per-frame or scales with enemy / projectile count
- [ ] Creates instances or connections during a run

## Testing done

<!-- What was actually played, on what device tier, and what happened. -->

## Checklist

- [ ] `--!strict` on every new file
- [ ] `selene src` clean
- [ ] `stylua --check src` clean
- [ ] `rojo build` succeeds
- [ ] Balance values live in `src/shared/Config`, not inline

# intertrace Philosophy

## Purpose

intertrace automates integration gap discovery — a pattern validated during iv-5muhg where cross-module data flow edges were traced manually to find unverified consumers. It is a thin interverse plugin (1 skill, 1 agent, 3 shell lib tracers) that accepts a bead ID and produces a ranked report of consumer edges that lack verification evidence, surfacing invisible gaps before they become production incidents.

## North Star

Every cross-module data flow edge is either verified or surfaced as a gap.

## Working Priorities

1. **Accuracy** — no false positives at P1; only flag declared edges with zero evidence.
2. **Coverage** — trace all declared consumer edges (event subscriptions, contracts, companion graph).
3. **Actionability** — every gap in the report maps to a concrete follow-up bead or a dismissal reason.

## Brainstorming Doctrine

1. Ground every proposal in the North Star — does this move closer to "all edges verified or surfaced"?
2. Prefer fewer, higher-fidelity evidence sources over broad but noisy scanning.
3. Surface constraints early — intermap availability, event schema conventions, bead access.
4. Bias toward the simplest design that handles the real-world case (bead + changed files).

## Planning Doctrine

1. Scope to one tracer at a time — each shell lib is independently testable.
2. Prefer incremental shipping — scaffold first, add evidence sources one task at a time.
3. Document assumptions about evidence sources in the plan before implementing.
4. Each task ends with structural tests passing; never leave the plugin in a broken state.

## Decision Filters

- Does this change risk false positives at P1 (high confidence gaps)?
- Is this tracer source reliable enough to surface to the user, or should it be P3-only?
- Does this add a new intermap dependency, and is that tool available in target sessions?
- Could a simpler shell pattern replace a proposed Python/MCP approach?

## Evidence Base

- Validated pattern: iv-5muhg (manual integration gap trace that revealed 3 unverified consumer edges)
- Architecture shaped by: `docs/plans/2026-02-28-intertrace.md`
- Prior learnings applied: critical-patterns.md (hooks.json format), hybrid-cli-plugin-architecture (no standalone CLI), set-e patterns (shell lib safety)

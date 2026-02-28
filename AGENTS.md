# intertrace — Development Guide

## Canonical References
1. [`PHILOSOPHY.md`](./PHILOSOPHY.md) — direction for ideation and planning decisions.
2. `CLAUDE.md` — implementation details, architecture, testing, and release workflow.

## Philosophy Alignment Protocol
Review [`PHILOSOPHY.md`](./PHILOSOPHY.md) during:
- Intake/scoping
- Brainstorming
- Planning
- Execution kickoff
- Review/gates
- Handoff/retrospective

For brainstorming/planning outputs, add two short lines:
- **Alignment:** one sentence on how the proposal supports the module's purpose within Demarch's philosophy.
- **Conflict/Risk:** one sentence on any tension with philosophy (or 'none').

If a high-value change conflicts with philosophy, either:
- adjust the plan to align, or
- create follow-up work to update `PHILOSOPHY.md` explicitly.


## Quick Reference

| Field | Value |
|-------|-------|
| Repo | `github.com/mistakeknot/intertrace` |
| Namespace | `intertrace:` |
| Manifest | `.claude-plugin/plugin.json` |
| Skills | 1 (`/intertrace`) |
| Agents | 1 (`fd-integration`) |
| Hooks | 0 (manual-only) |
| MCP Servers | 0 |
| License | MIT |

## Release Workflow

```bash
scripts/bump-version.sh <version>    # bump + push + cache sync
```

## Overview

**Problem:** After a feature ships (bead closed), downstream consumers may not have been updated or verified. These gaps are invisible — no tooling surfaces them unless someone manually traces the data flow.

**Solution:** intertrace accepts a bead ID, resolves its commits, identifies changed files, and traces data flows through three evidence sources (event bus, contracts, companion graph). It reports unverified consumer edges ranked by evidence strength (P1/P2/P3) and offers to create follow-up beads for gaps.

**Plugin type:** Thin interverse plugin (no MCP server). Calls intermap MCP tools for structural data; gap detection logic lives in shell libs and the skill layer.

**Current version:** 0.1.0 (scaffold)

## Architecture

```
intertrace/
├── .claude-plugin/
│   └── plugin.json             # Manifest: skills, agents, hooks
├── skills/
│   └── intertrace/
│       └── SKILL.md            # /intertrace orchestrator (Task 3)
├── agents/
│   └── review/
│       └── fd-integration.md   # interflux review agent (Task 4)
├── lib/
│   ├── trace-events.sh         # Event bus tracer (Task 5)
│   ├── trace-contracts.sh      # Contract tracer (Task 5)
│   └── trace-companion.sh      # Companion graph tracer (Task 5)
├── hooks/
│   └── hooks.json              # Empty (manual-only plugin)
├── scripts/
│   └── bump-version.sh         # Version management
├── tests/
│   └── structural/             # pytest structural tests (Task 6)
│       ├── conftest.py
│       ├── helpers.py
│       ├── test_structure.py
│       └── test_skills.py
├── docs/                       # Brainstorms, specs, plans
├── CLAUDE.md
├── AGENTS.md
├── PHILOSOPHY.md
├── README.md
├── LICENSE
└── .gitignore
```

## How It Works

### Tracer Pipeline

```
bead ID
  → bd show <id>           (resolve commits + changed files)
  → intermap:impact_analysis  (producer modules for changed files)
  → lib/trace-events.sh    (which consumers declared subscriptions?)
  → lib/trace-contracts.sh (which contracts reference these types?)
  → lib/trace-companion.sh (which companion plugins graph edges?)
  → skill layer            (merge, dedup, rank by evidence strength)
  → ranked report          (P1 / P2 / P3 gaps)
  → optional bead creation (on user confirm)
```

### Evidence Strength Ranking

| Priority | Meaning |
|----------|---------|
| P1 | Declared consumer edge + zero evidence of verification (high confidence gap) |
| P2 | Partial evidence — consumer exists but verification incomplete |
| P3 | Docs-only reference — mentioned but no declared edge or verification |

### Report → Beads Flow

intertrace never auto-creates beads. It presents the ranked gap report and asks for confirmation before creating follow-up work. This prevents noise when gaps are already tracked elsewhere.

## Component Conventions

### Skills

- One skill directory: `skills/intertrace/`
- SKILL.md has YAML frontmatter with `name` and `description`
- Orchestrates the full tracer pipeline: input resolution, lib calls, report formatting

### Agents

- One agent: `agents/review/fd-integration.md`
- interflux review agent — assesses whether a feature's integration surface is complete
- Called from the skill after gap report, with the ranked list as context

### Libs

- `lib/trace-events.sh` — queries intercore event schema for subscriber declarations
- `lib/trace-contracts.sh` — scans contract definitions for type references
- `lib/trace-companion.sh` — queries intermap companion graph for declared edges
- All libs are sourced (not executed) from the skill
- Follow `set -euo pipefail` and `|| true` patterns for fallback paths (see prior learnings)

## Integration Points

| Plugin/Tool | Relationship |
|-------------|-------------|
| intermap | Provides `impact_analysis`, `code_structure`, `project_registry` MCP tools |
| intercore | Event schema queries via `ic events` CLI |
| interflux | `fd-integration` agent submits findings as interflux review events |
| beads | Input source (bead ID) and output sink (gap beads on confirm) |
| Clavain | Companion context — intertrace reads companion graph edges |

## Testing

```bash
cd interverse/intertrace/tests
uv run pytest -q                 # All tests
uv run pytest structural/ -v     # Structure only
```

## Validation Checklist

```bash
ls skills/*/SKILL.md | wc -l          # 1
ls agents/review/*.md | wc -l         # 1
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"
bash -n lib/trace-events.sh
bash -n lib/trace-contracts.sh
bash -n lib/trace-companion.sh
```

## Known Constraints

- Requires intermap MCP tools to be installed and available in the session
- Event bus tracing depends on intercore event schema conventions — schema drift may cause false negatives
- Companion graph tracing is best-effort; undeclared edges are invisible by design
- P1 gaps require declared consumer edges; if declarations are missing, gaps appear as P3

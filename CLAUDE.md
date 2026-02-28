# intertrace

> See `AGENTS.md` for full development guide.

## Overview

Cross-module integration gap tracer — 1 skill, 0 commands, 1 agent (fd-integration), 0 hooks, 0 MCP servers. Companion plugin for Clavain. Given a bead ID, traces data flows from changed files through the module graph. Reports unverified consumer edges ranked by evidence strength (P1/P2/P3) with optional bead creation.

## Quick Commands

```bash
# Test locally
cd tests && uv run pytest -q

# Validate structure
ls skills/*/SKILL.md | wc -l          # Should be 1
ls agents/review/*.md | wc -l         # Should be 1
bash -n lib/trace-events.sh           # Syntax check
bash -n lib/trace-contracts.sh        # Syntax check
bash -n lib/trace-companion.sh        # Syntax check
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"
```

## Design Decisions (Do Not Re-Ask)

- Thin plugin over intermap — no MCP server (stateless analyzer)
- Three data sources (phase 1): event bus, contracts, companion graph
- Evidence-strength ranking: P1 (declared + zero evidence), P2 (partial), P3 (docs-only)
- Report first, beads on confirm — no auto-creation
- Input model: bead ID -> commits -> changed files
- Shell libs for tracers, skill for orchestration

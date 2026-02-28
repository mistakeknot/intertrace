# intertrace

Cross-module integration gap tracer for Demarch — given a bead ID, surfaces unverified consumer edges before they become production incidents.

## What this does

When a feature ships (bead closed), the modules that consume its data may not have been updated or verified. These gaps are invisible — no existing tooling surfaces them unless someone manually traces the data flow across the module graph.

intertrace automates that trace. You provide a bead ID; it resolves the associated commits, identifies changed files, and queries three evidence sources: the intercore event bus (which modules subscribed?), contract definitions (which contracts reference these types?), and the companion graph (which plugin edges are declared?). It then merges and ranks the results by evidence strength.

Gaps are reported in three priority tiers. P1 gaps are declared consumer edges with zero verification evidence — high-confidence integration holes. P2 gaps have partial evidence (consumer exists but verification is incomplete). P3 gaps are docs-only references with no declared edge or test coverage.

intertrace never creates beads automatically. It presents the ranked report and asks for confirmation before opening follow-up work. This keeps the bead backlog clean and ensures gaps are only tracked when they represent real unverified risk.

## Installation

Add the Interagency marketplace, then install:

```bash
/marketplace add https://github.com/mistakeknot/marketplace.git
/install intertrace
```

## Usage

```
/intertrace iv-<bead-id>
```

Trace all integration edges for the bead and produce a ranked gap report:

```
/intertrace iv-5muhg
```

The skill resolves commits from the bead, identifies changed files, runs all three tracers, and presents the gap report. Optionally create follow-up beads for P1/P2 gaps on confirm.

## Architecture

```
intertrace/
├── .claude-plugin/
│   └── plugin.json             # Manifest
├── skills/
│   └── intertrace/
│       └── SKILL.md            # /intertrace orchestrator
├── agents/
│   └── review/
│       └── fd-integration.md   # interflux review agent
├── lib/
│   ├── trace-events.sh         # Event bus tracer
│   ├── trace-contracts.sh      # Contract tracer
│   └── trace-companion.sh      # Companion graph tracer
├── hooks/
│   └── hooks.json              # Empty (manual-only)
└── scripts/
    └── bump-version.sh
```

## Design decisions

- No MCP server — stateless analysis over intermap tools is sufficient; adding a server would increase operational overhead with no benefit.
- Three tracers, not one — each evidence source (events, contracts, companion graph) has different reliability and coverage; separating them lets the ranking logic weight each source independently.
- Evidence-strength ranking (P1/P2/P3) — binary pass/fail produces too many false positives; a ranked tier report lets engineers triage rather than dismiss all findings.
- Report first, beads on confirm — auto-creating beads for every gap floods the backlog with noise; user confirmation gates bead creation.
- Shell libs, not Python — the tracers are short data-pipeline scripts with jq; bash + jq avoids a Python dependency and keeps the plugin startup latency near zero.

## License

MIT

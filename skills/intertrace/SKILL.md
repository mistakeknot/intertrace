---
name: intertrace
description: "Cross-module integration gap tracer. Given a bead ID, traces data flows from changed files to find unverified consumer edges. Use after shipping a feature to discover integration gaps."
user_invocable: true
argument-hint: "<bead-id>"
---

# /intertrace — Cross-Module Integration Gap Tracer

Given a shipped feature (bead ID), trace its data flows through the module graph and report unverified consumer edges.

## Input

<intertrace_input> # </intertrace_input>

If no bead ID provided, ask: "Which bead should I trace? Provide a bead ID (e.g., iv-5muhg)."

## Step 1: Resolve Bead to Changed Files

```bash
# Get bead metadata
bd show "<bead_id>"

# Find commits that reference this bead
commits=$(git log --all --oneline --grep="<bead_id>" --format="%H")

# Get changed files from those commits
changed_files=""
for commit in $commits; do
    files=$(git diff-tree --no-commit-id --name-only -r "$commit")
    changed_files="$changed_files\n$files"
done

# Deduplicate
changed_files=$(echo -e "$changed_files" | sort -u | grep -v '^$')
```

If no commits found for the bead ID, tell the user and offer to trace from a git diff range instead.

Display: `Found N files changed across M commits for <bead_id>`

## Step 2: Run Tracers

Source the three tracer libraries and run them. The tracer libraries are at:
- `interverse/intertrace/lib/trace-events.sh`
- `interverse/intertrace/lib/trace-contracts.sh`
- `interverse/intertrace/lib/trace-companion.sh`

### 2a: Event Bus Tracer

Find the intertrace plugin directory (check `~/.claude/plugins/cache/interagency-marketplace/intertrace/` or the development path), source `lib/trace-events.sh`, and call:

```bash
source "$INTERTRACE_ROOT/lib/trace-events.sh"
event_findings=$(_trace_events_scan "$MONOREPO_ROOT" "$changed_files")
```

### 2b: Contract Verifier

```bash
source "$INTERTRACE_ROOT/lib/trace-contracts.sh"
contract_findings=$(_trace_contracts_scan "$MONOREPO_ROOT" "$changed_files")
```

### 2c: Companion Graph Verifier

```bash
source "$INTERTRACE_ROOT/lib/trace-companion.sh"
companion_findings=$(_trace_companion_scan "$MONOREPO_ROOT")
```

## Step 3: Merge and Rank Findings

Combine all findings into a single ranked list using evidence-strength scoring:

**P1 (high confidence gap):**
- Contract declares consumer + zero code evidence (from trace-contracts unverified_consumers)
- Event type emitted + zero cursor registrations (from trace-events with no verified consumers)
- Companion-graph edge + zero import/call evidence (from trace-companion with verified=false)

**P2 (medium confidence):**
- Event type exists + consumer module exists but allowlist missing (trace-events hook_id_allowlist_missing)
- Contract consumer partially verified (some evidence but incomplete)

**P3 (low confidence / docs only):**
- Undeclared edges found in code but not in companion-graph.json (bonus findings)
- Weak grep matches only

## Step 4: Present Report

Display the ranked findings in a clear format:

```
Integration Trace for <bead_id>: <bead_title>

Files traced: N (across M commits)
Tracers run: event-bus, contracts, companion-graph

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GAPS FOUND: X

P1: <description>
    Source: <which tracer found this>
    Evidence: <what was checked and found missing>
    Impact: <why this matters>

P2: ...

P3: ...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then use **AskUserQuestion** with options:
1. "Create beads for P1 gaps" — create feature beads for high-confidence gaps only
2. "Create beads for all gaps" — create beads for every finding
3. "Save report only" — write to docs/traces/ without creating beads

## Step 5: Create Beads (if chosen)

For each gap that should become a bead:

```bash
bd create --title="Integration gap: <description>" --type=bug --priority=<1|2|3> --description="Found by intertrace tracing <bead_id>. <evidence details>"
```

## Step 6: Save Report

Write findings to `docs/traces/YYYY-MM-DD-<bead_id>-trace.md` with the full report including all findings, evidence, and any beads created.

#!/usr/bin/env bash
# Intertrace companion graph verifier.
#
# Usage:
#   source lib/trace-companion.sh
#   _trace_companion_scan "/path/to/monorepo"
#
# Provides:
#   _trace_companion_scan — verify companion-graph.json edges against code evidence
#   _trace_companion_verify_edge — check a single edge for code evidence

[[ -n "${_LIB_TRACE_COMPANION_LOADED:-}" ]] && return 0
_LIB_TRACE_COMPANION_LOADED=1

# Resolve a plugin name to its directory path(s).
# Args: $1=monorepo_root, $2=plugin_name
# Output: space-separated list of existing directory paths
_trace_companion_resolve_path() {
    local root="$1"
    local name="$2"
    local paths=()

    # Check common locations
    [[ -d "$root/interverse/$name" ]] && paths+=("$root/interverse/$name")
    [[ -d "$root/os/$name" ]] && paths+=("$root/os/$name")
    [[ -d "$root/apps/$name" ]] && paths+=("$root/apps/$name")
    [[ -d "$root/core/$name" ]] && paths+=("$root/core/$name")
    [[ -d "$root/sdk/$name" ]] && paths+=("$root/sdk/$name")

    echo "${paths[*]}"
}

# Verify a single companion-graph edge has code evidence.
# Args: $1=monorepo_root, $2=from_plugin, $3=to_plugin, $4=relationship
# Output: JSON {verified, evidence, evidence_type}
_trace_companion_verify_edge() {
    local root="$1"
    local from_plugin="$2"
    local to_plugin="$3"
    local relationship="$4"

    local from_paths to_paths
    from_paths=$(_trace_companion_resolve_path "$root" "$from_plugin")
    to_paths=$(_trace_companion_resolve_path "$root" "$to_plugin")

    [[ -z "$from_paths" ]] && {
        jq -n --arg ev "Plugin directory not found: $from_plugin" '{verified: false, evidence: $ev, evidence_type: "missing_plugin"}'
        return
    }

    # Search from_plugin's code for references to to_plugin
    for from_dir in $from_paths; do
        # Strategy 1: Direct name reference (import, source, require)
        local name_refs
        name_refs=$(grep -rl "$to_plugin\|lib-${to_plugin}" "$from_dir" --include='*.sh' --include='*.go' --include='*.py' --include='*.md' --include='*.json' 2>/dev/null | grep -v 'node_modules\|\.git\|__pycache__' | head -5) || true

        if [[ -n "$name_refs" ]]; then
            local first_file
            first_file=$(echo "$name_refs" | head -1 | sed "s|$root/||")
            local ref_count
            ref_count=$(echo "$name_refs" | wc -l | tr -d ' ')
            jq -n \
                --arg ev "Found $ref_count references to $to_plugin in $from_plugin (e.g., $first_file)" \
                '{verified: true, evidence: $ev, evidence_type: "code_reference"}'
            return
        fi

        # Strategy 2: Shell lib sourcing (find ... -path "*/lib-<to>*")
        local source_refs
        source_refs=$(grep -rl "lib-${to_plugin}\|plugins/cache.*${to_plugin}" "$from_dir" --include='*.sh' 2>/dev/null | head -3) || true

        if [[ -n "$source_refs" ]]; then
            local first_file
            first_file=$(echo "$source_refs" | head -1 | sed "s|$root/||")
            jq -n \
                --arg ev "Shell lib sourcing of $to_plugin found in $first_file" \
                '{verified: true, evidence: $ev, evidence_type: "shell_source"}'
            return
        fi
    done

    jq -n --arg ev "No code evidence for $from_plugin → $to_plugin ($relationship)" '{verified: false, evidence: $ev, evidence_type: "no_evidence"}'
}

# Main scan entrypoint.
# Args: $1=monorepo_root
# Output: JSON array of edge verification results
_trace_companion_scan() {
    local root="$1"
    local graph_file="$root/docs/companion-graph.json"

    [[ -f "$graph_file" ]] || { echo "[]"; return; }

    local edges
    edges=$(jq -c '.edges[]' "$graph_file" 2>/dev/null) || { echo "[]"; return; }

    local results="[]"

    while IFS= read -r edge; do
        [[ -z "$edge" ]] && continue
        local from_p to_p rel benefit
        from_p=$(echo "$edge" | jq -r '.from')
        to_p=$(echo "$edge" | jq -r '.to')
        rel=$(echo "$edge" | jq -r '.relationship')
        benefit=$(echo "$edge" | jq -r '.benefit')

        local verification
        verification=$(_trace_companion_verify_edge "$root" "$from_p" "$to_p" "$rel")
        local is_verified
        is_verified=$(echo "$verification" | jq -r '.verified')
        local evidence
        evidence=$(echo "$verification" | jq -r '.evidence')
        local evidence_type
        evidence_type=$(echo "$verification" | jq -r '.evidence_type')

        results=$(echo "$results" | jq \
            --arg from "$from_p" \
            --arg to "$to_p" \
            --arg rel "$rel" \
            --arg benefit "$benefit" \
            --argjson verified "$is_verified" \
            --arg ev "$evidence" \
            --arg et "$evidence_type" \
            '. + [{from: $from, to: $to, relationship: $rel, benefit: $benefit, verified: $verified, evidence: $ev, evidence_type: $et}]')
    done <<< "$edges"

    echo "$results"
}

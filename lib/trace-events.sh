#!/usr/bin/env bash
# Intertrace event bus tracer.
#
# Usage:
#   source lib/trace-events.sh
#   _trace_events_scan "/path/to/monorepo" "file1.sh\nfile2.go"
#
# Provides:
#   _trace_events_scan — scan changed files for event producers, verify consumers
#   _trace_events_find_producers — find ic events emit calls in files
#   _trace_events_verify_consumers — check consumer registrations for an event type

[[ -n "${_LIB_TRACE_EVENTS_LOADED:-}" ]] && return 0
_LIB_TRACE_EVENTS_LOADED=1

# Find all event types emitted in the given files.
# Args: $1=monorepo_root, $2=newline-separated file list
# Output: JSON array of {event_type, file, line}
_trace_events_find_producers() {
    local root="$1"
    local files="$2"
    local results="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local abs_path="$root/$file"
        [[ -f "$abs_path" ]] || continue

        # Match: ic events emit <type> (shell/Go invocations)
        local matches
        matches=$(grep -n 'ic events emit\|ic\.Events\.Emit\|events\.Emit' "$abs_path" 2>/dev/null) || continue

        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            local line_num="${match%%:*}"
            local line_text="${match#*:}"

            # Extract event type — patterns:
            # ic events emit <type> ...
            # ic events emit "<type>" ...
            local event_type=""
            event_type=$(echo "$line_text" | sed -n 's/.*ic events emit[[:space:]]*"\?\([a-zA-Z0-9_.]*\)"\?.*/\1/p')
            [[ -z "$event_type" ]] && event_type=$(echo "$line_text" | sed -n 's/.*Emit("\([^"]*\)".*/\1/p')
            [[ -z "$event_type" ]] && continue

            results=$(echo "$results" | jq \
                --arg et "$event_type" \
                --arg f "$file" \
                --argjson ln "$line_num" \
                '. + [{event_type: $et, file: $f, line: $ln}]')
        done <<< "$matches"
    done <<< "$files"

    echo "$results"
}

# Verify consumers for a given event type.
# Args: $1=monorepo_root, $2=event_type
# Output: JSON array of {module, verified, evidence, evidence_type}
_trace_events_verify_consumers() {
    local root="$1"
    local event_type="$2"
    local results="[]"

    # Strategy 1: Find cursor registrations that consume this event source
    local source_name="${event_type%%.*}"
    local cursor_files
    cursor_files=$(grep -rl "events tail.*--consumer\|events cursor register\|events list-review\|_consume.*events" "$root/interverse" "$root/os" 2>/dev/null) || true

    while IFS= read -r cfile; do
        [[ -z "$cfile" ]] && continue
        local module
        module=$(echo "$cfile" | sed "s|$root/||" | cut -d/ -f1-2)

        # Check if this file references our event type or its source
        if grep -q "$event_type\|$source_name" "$cfile" 2>/dev/null; then
            results=$(echo "$results" | jq \
                --arg mod "$module" \
                --arg ev "cursor/consumer referencing $event_type" \
                '. + [{module: $mod, verified: true, evidence: $ev, evidence_type: "cursor_registration"}]')
        fi
    done <<< "$cursor_files"

    # Strategy 2: Check hook_id allowlists (case statements in _validate_hook_id)
    local validate_files
    validate_files=$(grep -rl "_validate_hook_id\|validate_hook_id" "$root/interverse" 2>/dev/null) || true

    while IFS= read -r vfile; do
        [[ -z "$vfile" ]] && continue
        local module
        module=$(echo "$vfile" | sed "s|$root/||" | cut -d/ -f1-2)

        # Check if the allowlist includes this event type or a related hook_id
        if grep -q "$event_type\|${event_type//./-}" "$vfile" 2>/dev/null; then
            results=$(echo "$results" | jq \
                --arg mod "$module" \
                --arg ev "hook_id allowlist includes $event_type" \
                '. + [{module: $mod, verified: true, evidence: $ev, evidence_type: "hook_id_allowlist"}]')
        else
            # Found a validate function but it doesn't include our event type
            results=$(echo "$results" | jq \
                --arg mod "$module" \
                --arg ev "hook_id allowlist exists but does NOT include $event_type" \
                '. + [{module: $mod, verified: false, evidence: $ev, evidence_type: "hook_id_allowlist_missing"}]')
        fi
    done <<< "$validate_files"

    # Strategy 3: Check contract-ownership.md for declared consumers
    local contract_file="$root/docs/contract-ownership.md"
    if [[ -f "$contract_file" ]]; then
        local consumer_line
        consumer_line=$(grep -i "$event_type\|$source_name" "$contract_file" 2>/dev/null) || true
        if [[ -n "$consumer_line" ]]; then
            # Extract consumer names from the table row
            local consumers
            consumers=$(echo "$consumer_line" | awk -F'|' '{print $5}' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            while IFS= read -r consumer; do
                [[ -z "$consumer" ]] && continue
                results=$(echo "$results" | jq \
                    --arg mod "$consumer" \
                    --arg ev "declared in contract-ownership.md" \
                    '. + [{module: $mod, verified: false, evidence: $ev, evidence_type: "contract_declared"}]')
            done <<< "$consumers"
        fi
    fi

    echo "$results"
}

# Main scan entrypoint.
# Args: $1=monorepo_root, $2=newline-separated changed file list
# Output: JSON object with producers and consumer_verification arrays
_trace_events_scan() {
    local root="$1"
    local files="$2"

    local producers
    producers=$(_trace_events_find_producers "$root" "$files")

    local all_findings="[]"

    # Deduplicate event types
    local event_types
    event_types=$(echo "$producers" | jq -r '.[].event_type' | sort -u)

    while IFS= read -r et; do
        [[ -z "$et" ]] && continue
        local consumers
        consumers=$(_trace_events_verify_consumers "$root" "$et")

        local producer_file
        producer_file=$(echo "$producers" | jq -r --arg et "$et" '[.[] | select(.event_type == $et)][0].file')

        all_findings=$(echo "$all_findings" | jq \
            --arg et "$et" \
            --arg pf "$producer_file" \
            --argjson consumers "$consumers" \
            '. + [{event_type: $et, producer: $pf, consumers: $consumers}]')
    done <<< "$event_types"

    echo "$all_findings"
}

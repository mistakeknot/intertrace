#!/usr/bin/env bash
# Intertrace contract verifier.
#
# Usage:
#   source lib/trace-contracts.sh
#   _trace_contracts_scan "/path/to/monorepo" "file1.sh\nfile2.go"
#
# Provides:
#   _trace_contracts_scan — verify contract consumers against code evidence
#   _trace_contracts_parse — parse contract-ownership.md tables

[[ -n "${_LIB_TRACE_CONTRACTS_LOADED:-}" ]] && return 0
_LIB_TRACE_CONTRACTS_LOADED=1

# Parse a markdown table section from contract-ownership.md.
# Args: $1=file_path, $2=section_header_pattern
# Output: JSON array of {command, schema, owner, consumers} rows
_trace_contracts_parse_table() {
    local file="$1"
    local section_pattern="$2"
    local results="[]"
    local in_section=0
    local in_table=0
    local header_skipped=0

    while IFS= read -r line; do
        # Detect section start
        if echo "$line" | grep -q "$section_pattern"; then
            in_section=1
            in_table=0
            header_skipped=0
            continue
        fi

        # Detect next section (stop)
        if [[ $in_section -eq 1 ]] && echo "$line" | grep -q '^## '; then
            break
        fi

        [[ $in_section -eq 0 ]] && continue

        # Skip non-table lines
        echo "$line" | grep -q '^|' || continue

        # Skip separator row (|---|---|...)
        if echo "$line" | grep -q '^|-'; then
            header_skipped=1
            continue
        fi

        # Skip header row
        if [[ $header_skipped -eq 0 ]]; then
            header_skipped=1
            continue
        fi

        # Parse table row: | Command | Schema | Owner | Consumers | Stability |
        local cmd schema owner consumers
        cmd=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
        schema=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
        owner=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')
        consumers=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5); print $5}')

        # Strip markdown formatting (backticks)
        cmd=$(echo "$cmd" | tr -d '`')

        [[ -z "$cmd" ]] && continue

        results=$(echo "$results" | jq \
            --arg cmd "$cmd" \
            --arg schema "$schema" \
            --arg owner "$owner" \
            --arg consumers "$consumers" \
            '. + [{command: $cmd, schema: $schema, owner: $owner, consumers: $consumers}]')
    done < "$file"

    echo "$results"
}

# Verify that a declared consumer actually uses the contract.
# Args: $1=monorepo_root, $2=consumer_name, $3=command_or_event, $4=schema_name
# Output: JSON {verified, evidence}
_trace_contracts_verify_consumer() {
    local root="$1"
    local consumer="$2"
    local command="$3"
    local schema="$4"

    # Normalize consumer name to search paths
    # "Clavain bash" → os/clavain, "Interspect" → interverse/interspect, etc.
    local search_paths=()
    local consumer_lower
    consumer_lower=$(echo "$consumer" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//')

    case "$consumer_lower" in
        *clavain*) search_paths+=("$root/os/clavain") ;;
        *autarch*) search_paths+=("$root/apps/autarch") ;;
        *interlock*) search_paths+=("$root/interverse/interlock") ;;
        *interspect*) search_paths+=("$root/interverse/interspect") ;;
        *interflux*) search_paths+=("$root/interverse/interflux") ;;
        *interwatch*) search_paths+=("$root/interverse/interwatch") ;;
        *intermap*) search_paths+=("$root/interverse/intermap") ;;
        *) search_paths+=("$root/interverse/$consumer_lower" "$root/os/$consumer_lower" "$root/apps/$consumer_lower") ;;
    esac

    # Extract the actual command name for searching (e.g., "run create" → "run create", "events tail" → "events tail")
    local search_term="$command"

    for sp in "${search_paths[@]}"; do
        [[ -d "$sp" ]] || continue

        # Search for the command string or schema name in consumer code
        local evidence
        evidence=$(grep -rl "$search_term\|$schema" "$sp" 2>/dev/null | head -3) || true

        if [[ -n "$evidence" ]]; then
            local first_file
            first_file=$(echo "$evidence" | head -1 | sed "s|$root/||")
            jq -n --arg ev "Found '$search_term' reference in $first_file" '{verified: true, evidence: $ev}'
            return
        fi
    done

    jq -n --arg ev "No code evidence for '$search_term' consumption in $consumer" '{verified: false, evidence: $ev}'
}

# Main scan entrypoint.
# Args: $1=monorepo_root, $2=newline-separated changed file list (used to scope which contracts to check)
# Output: JSON array of contract verification findings
_trace_contracts_scan() {
    local root="$1"
    local files="$2"
    local contract_file="$root/docs/contract-ownership.md"

    [[ -f "$contract_file" ]] || { echo "[]"; return; }

    local results="[]"

    # Parse CLI output contracts
    local cli_contracts
    cli_contracts=$(_trace_contracts_parse_table "$contract_file" "CLI Output Contracts")

    # Parse event payload contracts
    local event_contracts
    event_contracts=$(_trace_contracts_parse_table "$contract_file" "Event Payload Contracts")

    # Merge both
    local all_contracts
    all_contracts=$(echo "$cli_contracts" | jq --argjson ec "$event_contracts" '. + $ec')

    # For each contract, check if any changed file is in the owner module
    local count
    count=$(echo "$all_contracts" | jq 'length')
    local i=0
    while [[ $i -lt $count ]]; do
        local cmd consumers_str
        cmd=$(echo "$all_contracts" | jq -r ".[$i].command")
        local schema
        schema=$(echo "$all_contracts" | jq -r ".[$i].schema")
        consumers_str=$(echo "$all_contracts" | jq -r ".[$i].consumers")

        # Split consumers by comma
        local verified_list="[]"
        local unverified_list="[]"

        while IFS=',' read -ra consumer_arr; do
            for consumer in "${consumer_arr[@]}"; do
                consumer=$(echo "$consumer" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                [[ -z "$consumer" ]] && continue

                local verification
                verification=$(_trace_contracts_verify_consumer "$root" "$consumer" "$cmd" "$schema")
                local is_verified
                is_verified=$(echo "$verification" | jq -r '.verified')
                local evidence
                evidence=$(echo "$verification" | jq -r '.evidence')

                if [[ "$is_verified" == "true" ]]; then
                    verified_list=$(echo "$verified_list" | jq --arg c "$consumer" --arg e "$evidence" '. + [{consumer: $c, evidence: $e}]')
                else
                    unverified_list=$(echo "$unverified_list" | jq --arg c "$consumer" --arg e "$evidence" '. + [{consumer: $c, evidence: $e}]')
                fi
            done
        done <<< "$consumers_str"

        results=$(echo "$results" | jq \
            --arg cmd "$cmd" \
            --arg schema "$schema" \
            --argjson verified "$verified_list" \
            --argjson unverified "$unverified_list" \
            '. + [{contract: $cmd, schema: $schema, verified_consumers: $verified, unverified_consumers: $unverified}]')

        i=$((i + 1))
    done

    echo "$results"
}

#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.0"
TCP=0
UDP=0
PORT=""
PROCESSES=0

usage() {
    cat <<'EOF'
Usage: port-listener-audit.sh [--tcp] [--udp] [--port PORT] [--processes] [--no-color]
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 3
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --tcp)
            TCP=1
            shift
            ;;
        --udp)
            UDP=1
            shift
            ;;
        --port)
            [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ && "$2" -ge 1 && "$2" -le 65535 ]] || die "--port requires 1-65535"
            PORT="$2"
            shift 2
            ;;
        --processes)
            PROCESSES=1
            shift
            ;;
        --no-color)
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        --version)
            printf '%s\n' "$VERSION"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
        esac
    done
    if [[ "$TCP" -eq 0 && "$UDP" -eq 0 ]]; then
        TCP=1
        UDP=1
    fi
}

classify() {
    local address="$1"
    case "$address" in
    127.* | ::1 | "[::1]") printf 'LOOPBACK' ;;
    0.0.0.0 | "*") printf 'ALL_INTERFACES' ;;
    "::" | "[::]") printf 'IPV6_ALL_INTERFACES' ;;
    *) printf 'SPECIFIC_INTERFACE' ;;
    esac
}

split_local() {
    local local_addr="$1"
    AUDIT_ADDRESS="${local_addr%:*}"
    AUDIT_PORT="${local_addr##*:}"
    AUDIT_ADDRESS="${AUDIT_ADDRESS#[}"
    AUDIT_ADDRESS="${AUDIT_ADDRESS%]}"
}

process_name() {
    local text="$1"
    if [[ "$text" =~ \"([^\"]+)\" ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '-'
    fi
}

process_pid() {
    local text="$1"
    if [[ "$text" =~ pid=([0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '-'
    fi
}

run_ss() {
    local args=(-H -l -n)
    [[ "$TCP" -eq 1 ]] && args+=(-t)
    [[ "$UDP" -eq 1 ]] && args+=(-u)
    [[ "$PROCESSES" -eq 1 ]] && args+=(-p)
    ss "${args[@]}"
}

run_netstat() {
    local args=(-l -n)
    [[ "$TCP" -eq 1 ]] && args+=(-t)
    [[ "$UDP" -eq 1 ]] && args+=(-u)
    [[ "$PROCESSES" -eq 1 ]] && args+=(-p)
    netstat "${args[@]}"
}

run_check() {
    local proto discard1 discard2 discard3 local_addr rest process pid binding source
    if command -v ss >/dev/null 2>&1; then
        source="ss"
        printf 'NOTE: all-interface bindings are not proof of internet reachability.\n' >&2
        [[ "$PROCESSES" -eq 1 ]] && printf 'NOTE: process details may require elevated permissions.\n' >&2
        printf '%-10s %-18s %-7s %-8s %-14s %s\n' "PROTOCOL" "ADDRESS" "PORT" "PID" "PROCESS" "BINDING"
        # shellcheck disable=SC2034 # ss state/queue columns are intentionally skipped.
        while read -r proto discard1 discard2 discard3 local_addr rest; do
            [[ -z "$proto" ]] && continue
            split_local "$local_addr"
            [[ -n "$PORT" && "$AUDIT_PORT" != "$PORT" ]] && continue
            process="$(process_name "$rest")"
            pid="$(process_pid "$rest")"
            binding="$(classify "$AUDIT_ADDRESS")"
            printf '%-10s %-18s %-7s %-8s %-14s %s\n' "$proto" "$AUDIT_ADDRESS" "$AUDIT_PORT" "$pid" "$process" "$binding"
        done < <(run_ss)
    elif command -v netstat >/dev/null 2>&1; then
        source="netstat"
        printf 'NOTE: ss unavailable; using netstat fallback.\n' >&2
        printf 'NOTE: all-interface bindings are not proof of internet reachability.\n' >&2
        printf '%-10s %-18s %-7s %-8s %-14s %s\n' "PROTOCOL" "ADDRESS" "PORT" "PID" "PROCESS" "BINDING"
        # shellcheck disable=SC2034 # netstat queue columns are intentionally skipped.
        while read -r proto discard1 discard2 local_addr rest; do
            [[ "$proto" == Proto || -z "$proto" ]] && continue
            split_local "$local_addr"
            [[ -n "$PORT" && "$AUDIT_PORT" != "$PORT" ]] && continue
            process="-"
            pid="-"
            if [[ "$rest" =~ ([0-9]+)/([^[:space:]]+) ]]; then
                pid="${BASH_REMATCH[1]}"
                process="${BASH_REMATCH[2]}"
            fi
            binding="$(classify "$AUDIT_ADDRESS")"
            printf '%-10s %-18s %-7s %-8s %-14s %s\n' "$proto" "$AUDIT_ADDRESS" "$AUDIT_PORT" "$pid" "$process" "$binding"
        done < <(run_netstat)
    else
        die "missing required command: ss or netstat"
    fi
    [[ -n "$source" ]]
}

parse_args "$@"
run_check

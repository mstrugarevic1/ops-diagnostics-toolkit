#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.3.4"
NO_COLOR_FLAG=0
WARNING_LOAD=1.5
CRITICAL_LOAD=3.0
WARNING_MEM=85
CRITICAL_MEM=95
WARNING_SWAP=50
CRITICAL_SWAP=80
CHECK_OOM=0
PROC_ROOT="${OPS_DIAG_PROC_ROOT:-/proc}"

usage() {
    cat <<'EOF'
Usage: system-pressure-report.sh [--warning-load RATIO] [--critical-load RATIO] [--warning-memory PERCENT] [--critical-memory PERCENT] [--warning-swap PERCENT] [--critical-swap PERCENT] [--check-oom] [--no-color]
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 3
}

color() {
    local code="$1" text="$2"
    if [[ "$NO_COLOR_FLAG" -eq 0 && -t 1 && -z "${NO_COLOR+x}" ]]; then
        printf '\033[%sm%s\033[0m' "$code" "$text"
    else
        printf '%s' "$text"
    fi
}

print_status() {
    local status="$1"
    case "$status" in
    OK) color 32 "$status" ;;
    WARNING) color 33 "$status" ;;
    CRITICAL) color 31 "$status" ;;
    UNKNOWN) color 33 "$status" ;;
    esac
}

status_code() {
    case "$1" in
    OK | UNKNOWN) printf 0 ;;
    WARNING) printf 1 ;;
    CRITICAL) printf 2 ;;
    esac
}

valid_percent() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -le 100 ]]
}

valid_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

ge_number() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --warning-load)
            [[ "$#" -ge 2 ]] || die "--warning-load requires a number"
            valid_number "$2" || die "--warning-load requires a number"
            WARNING_LOAD="$2"
            shift 2
            ;;
        --critical-load)
            [[ "$#" -ge 2 ]] || die "--critical-load requires a number"
            valid_number "$2" || die "--critical-load requires a number"
            CRITICAL_LOAD="$2"
            shift 2
            ;;
        --warning-memory)
            [[ "$#" -ge 2 ]] || die "--warning-memory requires a percent"
            valid_percent "$2" || die "--warning-memory must be 0-100"
            WARNING_MEM="$2"
            shift 2
            ;;
        --critical-memory)
            [[ "$#" -ge 2 ]] || die "--critical-memory requires a percent"
            valid_percent "$2" || die "--critical-memory must be 0-100"
            CRITICAL_MEM="$2"
            shift 2
            ;;
        --warning-swap)
            [[ "$#" -ge 2 ]] || die "--warning-swap requires a percent"
            valid_percent "$2" || die "--warning-swap must be 0-100"
            WARNING_SWAP="$2"
            shift 2
            ;;
        --critical-swap)
            [[ "$#" -ge 2 ]] || die "--critical-swap requires a percent"
            valid_percent "$2" || die "--critical-swap must be 0-100"
            CRITICAL_SWAP="$2"
            shift 2
            ;;
        --check-oom)
            CHECK_OOM=1
            shift
            ;;
        --no-color)
            NO_COLOR_FLAG=1
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
        *)
            die "unknown argument: $1"
            ;;
        esac
    done
    ge_number "$CRITICAL_LOAD" "$WARNING_LOAD" || die "--critical-load must be greater than or equal to --warning-load"
    [[ "$WARNING_MEM" -le "$CRITICAL_MEM" ]] || die "--warning-memory must be lower than or equal to --critical-memory"
    [[ "$WARNING_SWAP" -le "$CRITICAL_SWAP" ]] || die "--warning-swap must be lower than or equal to --critical-swap"
}

emit_row() {
    local status="$1" resource="$2" value="$3" details="$4"
    local code
    code="$(status_code "$status")"
    if ((code > EXIT_CODE)); then
        EXIT_CODE="$code"
    fi
    printf '%-10s %-18s %-12s %s\n' "$(print_status "$status")" "$resource" "$value" "$details"
}

cpu_count() {
    local count
    count="$(grep -c '^processor[[:space:]]*:' "$PROC_ROOT/cpuinfo" 2>/dev/null || printf 0)"
    [[ "$count" -gt 0 ]] || count=1
    printf '%s' "$count"
}

check_load() {
    local load cpus ratio status
    [[ -r "$PROC_ROOT/loadavg" ]] || {
        emit_row UNKNOWN load "n/a" "$PROC_ROOT/loadavg unavailable"
        return
    }
    read -r load _ <"$PROC_ROOT/loadavg"
    cpus="$(cpu_count)"
    ratio="$(awk -v load="$load" -v cpus="$cpus" 'BEGIN { printf "%.2f", load / cpus }')"
    if ge_number "$ratio" "$CRITICAL_LOAD"; then
        status="CRITICAL"
    elif ge_number "$ratio" "$WARNING_LOAD"; then
        status="WARNING"
    else
        status="OK"
    fi
    emit_row "$status" load "$ratio" "${load} load1 across ${cpus} CPU(s)"
}

meminfo_value() {
    local key="$1"
    [[ -r "$PROC_ROOT/meminfo" ]] || return 0
    awk -v key="$key" '$1 == key ":" {print $2}' "$PROC_ROOT/meminfo" 2>/dev/null
}

percent_used() {
    awk -v total="$1" -v available="$2" 'BEGIN { if (total <= 0) print 0; else printf "%.0f", ((total - available) / total) * 100 }'
}

check_memory() {
    local total available used status
    total="$(meminfo_value MemTotal)"
    available="$(meminfo_value MemAvailable)"
    if [[ -z "$total" || -z "$available" ]]; then
        emit_row UNKNOWN memory "n/a" "$PROC_ROOT/meminfo missing MemTotal or MemAvailable"
        return
    fi
    used="$(percent_used "$total" "$available")"
    if [[ "$used" -ge "$CRITICAL_MEM" ]]; then
        status="CRITICAL"
    elif [[ "$used" -ge "$WARNING_MEM" ]]; then
        status="WARNING"
    else
        status="OK"
    fi
    emit_row "$status" memory "${used}%" "$((available / 1024)) MiB available"
}

check_swap() {
    local total free used status
    total="$(meminfo_value SwapTotal)"
    free="$(meminfo_value SwapFree)"
    if [[ -z "$total" || -z "$free" || "$total" -eq 0 ]]; then
        emit_row OK swap "0%" "no swap configured"
        return
    fi
    used="$(percent_used "$total" "$free")"
    if [[ "$used" -ge "$CRITICAL_SWAP" ]]; then
        status="CRITICAL"
    elif [[ "$used" -ge "$WARNING_SWAP" ]]; then
        status="WARNING"
    else
        status="OK"
    fi
    emit_row "$status" swap "${used}%" "$(((total - free) / 1024)) MiB used"
}

psi_avg10() {
    local file="$1"
    awk '/^some / {for (i=1; i<=NF; i++) if ($i ~ /^avg10=/) {sub("avg10=", "", $i); print $i}}' "$file" 2>/dev/null
}

check_psi_one() {
    local name="$1" file="$PROC_ROOT/pressure/$1" avg
    if [[ ! -r "$file" ]]; then
        emit_row UNKNOWN "${name}_pressure" "n/a" "PSI unavailable"
        return
    fi
    avg="$(psi_avg10 "$file")"
    [[ -n "$avg" ]] || avg="0.00"
    emit_row OK "${name}_pressure" "${avg}%" "avg10 some pressure"
}

check_oom() {
    local logs=""
    [[ "$CHECK_OOM" -eq 1 ]] || return 0
    if command -v dmesg >/dev/null 2>&1; then
        logs="$(dmesg 2>/dev/null || true)"
    fi
    if [[ -z "$logs" ]] && command -v journalctl >/dev/null 2>&1; then
        logs="$(journalctl -k -n 200 --no-pager 2>/dev/null || true)"
    fi
    if [[ -z "$logs" ]]; then
        emit_row UNKNOWN oom_kills "n/a" "kernel logs unavailable"
    elif grep -Eiq 'out of memory|oom-kill|killed process' <<<"$logs"; then
        emit_row CRITICAL oom_kills "seen" "OOM pattern found in kernel logs"
    else
        emit_row OK oom_kills "none" "no recent OOM pattern found"
    fi
}

run_report() {
    EXIT_CODE=0
    printf '%-10s %-18s %-12s %s\n' "STATUS" "RESOURCE" "VALUE" "DETAILS"
    check_load
    check_memory
    check_swap
    check_psi_one cpu
    check_psi_one memory
    check_psi_one io
    check_oom
    return "$EXIT_CODE"
}

parse_args "$@"
run_report

#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.3.1"
NO_COLOR_FLAG=0
FAILED_ONLY=0
LOGS=0
SERVICE_FILE=""
SERVICES=()

usage() {
    cat <<'EOF'
Usage: service-health-report.sh [--file FILE] [--failed-only] [--logs NUMBER] [--no-color] [SERVICE...]
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 3
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
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
    FAILED | NOT_FOUND) color 31 "$status" ;;
    INACTIVE | UNKNOWN) color 33 "$status" ;;
    esac
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --file)
            [[ "$#" -ge 2 ]] || die "--file requires a file"
            SERVICE_FILE="$2"
            shift 2
            ;;
        --failed-only)
            FAILED_ONLY=1
            shift
            ;;
        --logs)
            [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--logs requires a number"
            LOGS="$2"
            shift 2
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
        --*)
            die "unknown argument: $1"
            ;;
        *)
            SERVICES+=("$1")
            shift
            ;;
        esac
    done
}

read_services_file() {
    local line
    [[ -r "$SERVICE_FILE" ]] || die "cannot read service file: $SERVICE_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && SERVICES+=("$line")
    done <"$SERVICE_FILE"
}

status_for() {
    local load="$1" active="$2"
    if [[ "$load" == "not-found" ]]; then
        printf 'NOT_FOUND'
    elif [[ "$active" == "active" ]]; then
        printf 'OK'
    elif [[ "$active" == "failed" ]]; then
        printf 'FAILED'
    elif [[ "$active" == "inactive" ]]; then
        printf 'INACTIVE'
    else
        printf 'UNKNOWN'
    fi
}

show_logs() {
    local service="$1"
    [[ "$LOGS" -eq 0 ]] && return 0
    if ! command -v journalctl >/dev/null 2>&1; then
        printf 'LOGS      %s journalctl unavailable\n' "$service" >&2
        return 0
    fi
    if ! journalctl -u "$service" -n "$LOGS" --no-pager; then
        printf 'LOGS      %s unavailable; journal access may require elevated permissions\n' "$service" >&2
    fi
}

report_service() {
    local service="$1" output load active sub pid restart status code=0
    if ! output="$(systemctl show "$service" -p LoadState -p ActiveState -p SubState -p MainPID -p NRestarts 2>&1)"; then
        load="not-found"
        active="unknown"
        sub="-"
        pid="-"
        restart="-"
    else
        load="$(awk -F= '$1=="LoadState"{print $2}' <<<"$output")"
        active="$(awk -F= '$1=="ActiveState"{print $2}' <<<"$output")"
        sub="$(awk -F= '$1=="SubState"{print $2}' <<<"$output")"
        pid="$(awk -F= '$1=="MainPID"{print $2}' <<<"$output")"
        restart="$(awk -F= '$1=="NRestarts"{print $2}' <<<"$output")"
    fi
    status="$(status_for "${load:-unknown}" "${active:-unknown}")"
    [[ "$status" == "FAILED" || "$status" == "NOT_FOUND" ]] && code=2
    printf '%-10s %-24s %-12s %-12s %-12s %-8s %s\n' "$(print_status "$status")" "$service" "${load:-unknown}" "${active:-unknown}" "${sub:-unknown}" "${pid:-0}" "${restart:-0}"
    show_logs "$service"
    return "$code"
}

run_failed_only() {
    local output unit exit_code=0
    if ! output="$(systemctl --failed --type=service --no-legend --plain 2>&1)"; then
        printf 'ERROR: systemd is unavailable or systemctl failed: %s\n' "$output" >&2
        return 3
    fi
    printf '%-10s %s\n' "STATUS" "SERVICE"
    while IFS= read -r unit; do
        [[ -z "$unit" ]] && continue
        printf '%-10s %s\n' "$(print_status FAILED)" "$unit"
        exit_code=2
    done < <(awk '{print $1}' <<<"$output")
    return "$exit_code"
}

run_report() {
    local service exit_code=0 code
    printf '%-10s %-24s %-12s %-12s %-12s %-8s %s\n' "STATUS" "SERVICE" "LOAD" "ACTIVE" "SUB" "PID" "RESTARTS"
    for service in "${SERVICES[@]}"; do
        report_service "$service" || code="$?"
        code="${code:-0}"
        ((code > exit_code)) && exit_code="$code"
        code=0
    done
    return "$exit_code"
}

parse_args "$@"
need systemctl
if [[ -n "$SERVICE_FILE" ]]; then
    read_services_file
fi
if [[ "$FAILED_ONLY" -eq 1 ]]; then
    run_failed_only
else
    [[ "${#SERVICES[@]}" -gt 0 ]] || die "provide services, --file, or --failed-only"
    run_report
fi

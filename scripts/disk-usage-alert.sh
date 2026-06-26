#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.0"
NO_COLOR_FLAG=0
WARNING=80
CRITICAL=90
FILESYSTEM=""
EXCLUDE_TYPES=("tmpfs" "devtmpfs" "squashfs" "proc" "sysfs" "devfs" "overlay")

usage() {
    cat <<'EOF'
Usage: disk-usage-alert.sh [--warning PERCENT] [--critical PERCENT] [--filesystem PATH] [--exclude-type TYPE] [--no-color]
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

status_code() {
    case "$1" in
    OK) printf 0 ;;
    WARNING) printf 1 ;;
    CRITICAL) printf 2 ;;
    esac
}

valid_percent() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -le 100 ]]
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --warning)
            [[ "$#" -ge 2 ]] || die "--warning requires a percent"
            WARNING="$2"
            shift 2
            ;;
        --critical)
            [[ "$#" -ge 2 ]] || die "--critical requires a percent"
            CRITICAL="$2"
            shift 2
            ;;
        --filesystem)
            [[ "$#" -ge 2 ]] || die "--filesystem requires a path"
            FILESYSTEM="$2"
            shift 2
            ;;
        --exclude-type)
            [[ "$#" -ge 2 ]] || die "--exclude-type requires a type"
            EXCLUDE_TYPES+=("$2")
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
        *)
            die "unknown argument: $1"
            ;;
        esac
    done
    valid_percent "$WARNING" || die "--warning must be an integer from 0 to 100"
    valid_percent "$CRITICAL" || die "--critical must be an integer from 0 to 100"
    [[ "$WARNING" -lt "$CRITICAL" ]] || die "--warning must be lower than --critical"
}

is_excluded() {
    local type="$1" excluded
    for excluded in "${EXCLUDE_TYPES[@]}"; do
        [[ "$type" == "$excluded" ]] && return 0
    done
    return 1
}

print_status() {
    local status="$1"
    case "$status" in
    OK) color 32 "$status" ;;
    WARNING) color 33 "$status" ;;
    CRITICAL) color 31 "$status" ;;
    esac
}

run_check() {
    local df_args=(-P -T)
    local exit_code=0 df_output line parsed fs type avail pct mount used_pct status code
    [[ -n "$FILESYSTEM" ]] && df_args+=("$FILESYSTEM")
    if ! df_output="$(df "${df_args[@]}" 2>&1)"; then
        die "df failed: $df_output"
    fi
    printf '%-10s %-22s %-18s %-8s %s\n' "STATUS" "FILESYSTEM" "MOUNT" "USED" "AVAILABLE"
    while IFS= read -r line; do
        [[ "$line" == Filesystem* ]] && continue
        parsed="$(awk '{mount=$7; for (i=8; i<=NF; i++) mount=mount " " $i; print $1 "\t" $2 "\t" $5 "\t" $6 "\t" mount}' <<<"$line")"
        IFS=$'\t' read -r fs type avail pct mount <<<"$parsed"
        is_excluded "$type" && continue
        used_pct="${pct%%%}"
        if [[ "$used_pct" -ge "$CRITICAL" ]]; then
            status="CRITICAL"
        elif [[ "$used_pct" -ge "$WARNING" ]]; then
            status="WARNING"
        else
            status="OK"
        fi
        code="$(status_code "$status")"
        ((code > exit_code)) && exit_code="$code"
        printf '%-10s %-22s %-18s %-8s %s\n' "$(print_status "$status")" "$fs" "$mount" "$pct" "$avail"
    done <<<"$df_output"
    return "$exit_code"
}

parse_args "$@"
need df
run_check

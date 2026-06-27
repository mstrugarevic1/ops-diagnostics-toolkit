#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.3.7"
TYPE=""
RESOLVER=""
COMPARE=0
TIMEOUT=5
HOSTNAME=""
DEFAULT_TYPES=(A AAAA CNAME NS)
SUPPORTED_TYPES=" A AAAA CNAME NS MX TXT SOA "

usage() {
    cat <<'EOF'
Usage: dns-debug.sh HOSTNAME [--type TYPE] [--resolver ADDRESS] [--compare-resolvers] [--timeout SECONDS] [--no-color]
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 3
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

valid_hostname() {
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$ ]]
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --type)
            [[ "$#" -ge 2 ]] || die "--type requires a record type"
            TYPE="$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')"
            shift 2
            ;;
        --resolver)
            [[ "$#" -ge 2 ]] || die "--resolver requires an address"
            RESOLVER="$2"
            shift 2
            ;;
        --compare-resolvers)
            COMPARE=1
            shift
            ;;
        --timeout)
            [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || die "--timeout requires a positive integer"
            TIMEOUT="$2"
            shift 2
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
        --*)
            die "unknown argument: $1"
            ;;
        *)
            [[ -z "$HOSTNAME" ]] || die "only one hostname is supported"
            HOSTNAME="$1"
            shift
            ;;
        esac
    done
    [[ -n "$HOSTNAME" ]] || die "hostname is required"
    valid_hostname "$HOSTNAME" || die "invalid hostname: $HOSTNAME"
    [[ -z "$TYPE" || "$SUPPORTED_TYPES" == *" $TYPE "* ]] || die "unsupported record type: $TYPE"
}

query_one() {
    local resolver="$1" record_type="$2" output status time answers ns
    local dig_args=("+time=$TIMEOUT" "+tries=1" "$HOSTNAME" "$record_type")
    [[ -n "$resolver" ]] && dig_args=("@$resolver" "${dig_args[@]}")
    if ! output="$(dig "${dig_args[@]}" 2>&1)"; then
        if grep -qi 'timed out' <<<"$output"; then
            status="TIMEOUT"
        else
            status="FAILED"
        fi
        printf '%-10s %-8s %-16s %s\n' "$status" "$record_type" "${resolver:-system}" "$output"
        return 2
    fi
    status="$(awk '/HEADER/ {for (i=1; i<=NF; i++) if ($i=="status:") {gsub(",", "", $(i+1)); print $(i+1)}}' <<<"$output")"
    time="$(awk -F': ' '/Query time:/ {print $2}' <<<"$output")"
    answers="$(awk '/^;; ANSWER SECTION:/{show=1; next} /^;;/{show=0} show && NF{print}' <<<"$output")"
    ns="$(awk '/^;; AUTHORITY SECTION:/{show=1; next} /^;;/{show=0} show && NF{print}' <<<"$output")"
    [[ -z "$answers" && "$status" == "NOERROR" ]] && status="EMPTY"
    printf '%-10s %-8s %-16s %s\n' "${status:-UNKNOWN}" "$record_type" "${resolver:-system}" "${time:-n/a}"
    [[ -n "$answers" ]] && printf '%s\n' "$answers"
    [[ -n "$ns" ]] && printf 'AUTHORITY\n%s\n' "$ns"
    [[ "$status" == "NXDOMAIN" || "$status" == "SERVFAIL" ]] && return 2
    return 0
}

run_check() {
    local resolvers types resolver record_type exit_code=0 code
    if [[ "$COMPARE" -eq 1 ]]; then
        resolvers=("" "1.1.1.1" "8.8.8.8")
        printf 'NOTE: CDN, geo-aware, round-robin, and cached DNS answers may differ.\n' >&2
    else
        resolvers=("$RESOLVER")
    fi
    if [[ -n "$TYPE" ]]; then
        types=("$TYPE")
    else
        types=("${DEFAULT_TYPES[@]}")
    fi
    printf '%-10s %-8s %-16s %s\n' "STATUS" "TYPE" "RESOLVER" "QUERY_TIME"
    for resolver in "${resolvers[@]}"; do
        for record_type in "${types[@]}"; do
            query_one "$resolver" "$record_type" || code="$?"
            code="${code:-0}"
            ((code > exit_code)) && exit_code="$code"
            code=0
        done
    done
    return "$exit_code"
}

parse_args "$@"
need dig
run_check

#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.3.3"
TARGET_FILE=""
PORT=443
WARNING_DAYS=30
CRITICAL_DAYS=7
TIMEOUT=10
TARGETS=()

usage() {
    cat <<'EOF'
Usage: tls-expiry-check.sh [--file FILE] [--port PORT] [--warning-days DAYS] [--critical-days DAYS] [--timeout SECONDS] [--no-color] [HOST[:PORT]...]
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 3
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

valid_host() {
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

valid_port() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --file)
            [[ "$#" -ge 2 ]] || die "--file requires a file"
            TARGET_FILE="$2"
            shift 2
            ;;
        --port)
            [[ "$#" -ge 2 ]] || die "--port requires a port"
            valid_port "$2" || die "--port requires 1-65535"
            PORT="$2"
            shift 2
            ;;
        --warning-days)
            [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--warning-days requires a number"
            WARNING_DAYS="$2"
            shift 2
            ;;
        --critical-days)
            [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--critical-days requires a number"
            CRITICAL_DAYS="$2"
            shift 2
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
            TARGETS+=("$1")
            shift
            ;;
        esac
    done
    [[ "$CRITICAL_DAYS" -lt "$WARNING_DAYS" ]] || die "--critical-days must be lower than --warning-days"
}

read_targets_file() {
    local line
    [[ -r "$TARGET_FILE" ]] || die "cannot read target file: $TARGET_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && TARGETS+=("$line")
    done <"$TARGET_FILE"
}

split_target() {
    local target="$1"
    [[ "$target" == *::* ]] && die "malformed target: $target"
    TLS_HOST="${target%%:*}"
    TLS_PORT="$PORT"
    if [[ "$target" == *:* ]]; then
        TLS_PORT="${target##*:}"
    fi
    valid_host "$TLS_HOST" || die "malformed target: $target"
    valid_port "$TLS_PORT" || die "malformed target: $target"
}

supports_verify_hostname() {
    openssl s_client -help 2>&1 | grep -q -- '-verify_hostname'
}

date_epoch() {
    date -u -d "$1" +%s
}

check_one() {
    local target="$1" cert info not_after not_before subject issuer expires_epoch now_epoch days status verify_opt=()
    split_target "$target"
    if supports_verify_hostname; then
        verify_opt=(-verify_hostname "$TLS_HOST")
    fi
    if ! cert="$(timeout "$TIMEOUT" openssl s_client -connect "$TLS_HOST:$TLS_PORT" -servername "$TLS_HOST" "${verify_opt[@]}" </dev/null 2>&1)"; then
        printf '%-10s %-22s %-6s %-10s %s\n' "CRITICAL" "$TLS_HOST" "$TLS_PORT" "n/a" "TLS handshake failed"
        return 2
    fi
    if ! info="$(openssl x509 -noout -subject -issuer -startdate -enddate <<<"$cert" 2>&1)"; then
        printf '%-10s %-22s %-6s %-10s %s\n' "CRITICAL" "$TLS_HOST" "$TLS_PORT" "n/a" "missing certificate"
        return 2
    fi
    subject="$(awk -F= '/^subject=/{sub(/^subject=/,""); print}' <<<"$info")"
    issuer="$(awk -F= '/^issuer=/{sub(/^issuer=/,""); print}' <<<"$info")"
    not_before="$(awk -F= '/^notBefore=/{sub(/^notBefore=/,""); print}' <<<"$info")"
    not_after="$(awk -F= '/^notAfter=/{sub(/^notAfter=/,""); print}' <<<"$info")"
    expires_epoch="$(date_epoch "$not_after")"
    now_epoch="$(date -u +%s)"
    days="$(((expires_epoch - now_epoch) / 86400))"
    if [[ "$days" -lt 0 ]]; then
        status="CRITICAL"
    elif [[ "$days" -le "$CRITICAL_DAYS" ]]; then
        status="CRITICAL"
    elif [[ "$days" -le "$WARNING_DAYS" ]]; then
        status="WARNING"
    else
        status="OK"
    fi
    if grep -qi 'verify error.*hostname mismatch\|hostname mismatch' <<<"$cert"; then
        status="CRITICAL"
    fi
    printf '%-10s %-22s %-6s %-10s %s\n' "$status" "$TLS_HOST" "$TLS_PORT" "$days" "$not_after"
    printf 'SUBJECT   %s\nISSUER    %s\nVALIDFROM %s\nVERIFY    %s\n' "${subject:-unknown}" "${issuer:-unknown}" "${not_before:-unknown}" "$(grep -m1 'Verify return code:' <<<"$cert" || printf 'not reported')"
    [[ "$status" == "WARNING" ]] && return 1
    [[ "$status" == "CRITICAL" ]] && return 2
    return 0
}

run_check() {
    local target exit_code=0 code
    printf '%-10s %-22s %-6s %-10s %s\n' "STATUS" "HOST" "PORT" "DAYS LEFT" "EXPIRES"
    for target in "${TARGETS[@]}"; do
        check_one "$target" || code="$?"
        code="${code:-0}"
        ((code > exit_code)) && exit_code="$code"
        code=0
    done
    return "$exit_code"
}

parse_args "$@"
need openssl
need timeout
if [[ -n "$TARGET_FILE" ]]; then
    read_targets_file
fi
[[ "${#TARGETS[@]}" -gt 0 ]] || die "provide a target or --file"
run_check

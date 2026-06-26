#!/usr/bin/env bats

load helpers/test_helper

@test "valid certificate exits 0" {
    TLS_MODE=valid run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"*"example.com"* ]]
}

@test "warning expiry exits 1" {
    TLS_MODE=warning run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARNING"* ]]
}

@test "critical expiry exits 2" {
    TLS_MODE=critical run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"* ]]
}

@test "expired certificate exits 2" {
    TLS_MODE=expired run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"* ]]
}

@test "connection failure exits 2" {
    TLS_MODE=fail run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"TLS handshake failed"* ]]
}

@test "hostname mismatch exits 2" {
    TLS_MODE=mismatch run_script tls-expiry-check.sh example.com --no-color
    [ "$status" -eq 2 ]
}

@test "malformed target exits 3" {
    run_script tls-expiry-check.sh "bad::443" --no-color
    [ "$status" -eq 3 ]
}

@test "missing openssl exits 3" {
    path_with_only_bash
    run_script_with_path tls-expiry-check.sh "$MISSING_PATH" example.com --no-color
    [ "$status" -eq 3 ]
}

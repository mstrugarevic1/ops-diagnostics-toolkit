#!/usr/bin/env bats

load helpers/test_helper

@test "loopback listener is classified" {
    run_script port-listener-audit.sh --processes
    [ "$status" -eq 0 ]
    [[ "$output" == *"127.0.0.1"*"LOOPBACK"* ]]
}

@test "all interface listener is classified" {
    run_script port-listener-audit.sh --processes
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.0.0.0"*"ALL_INTERFACES"* ]]
}

@test "tcp-only filtering omits udp" {
    run_script port-listener-audit.sh --tcp
    [ "$status" -eq 0 ]
    [[ "$output" != *"udp"* ]]
}

@test "udp-only filtering omits tcp" {
    run_script port-listener-audit.sh --udp
    [ "$status" -eq 0 ]
    [[ "$output" != *"tcp"* ]]
}

@test "missing process visibility prints dash" {
    run_script port-listener-audit.sh --udp --processes
    [ "$status" -eq 0 ]
    [[ "$output" == *" - "* || "$output" == *"0.0.0.0"*"ALL_INTERFACES"* ]]
}

@test "netstat fallback works" {
    path_with_only_bash
    ln -sf "$BATS_TEST_DIRNAME/fixtures/bin/netstat" "$BATS_TEST_TMPDIR/bin/netstat"
    ln -sf /bin/cat "$BATS_TEST_TMPDIR/bin/cat"
    run_script_with_path port-listener-audit.sh "$MISSING_PATH" --tcp --processes
    [ "$status" -eq 0 ]
    [[ "$output" == *"netstat fallback"* ]]
    [[ "$output" == *"nginx"* ]]
}

@test "summary counts binding classes" {
    run_script port-listener-audit.sh --processes
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUMMARY"*"LOOPBACK=1"*"ALL_INTERFACES=2"* ]]
}

@test "all-interfaces-only hides loopback listeners" {
    run_script port-listener-audit.sh --all-interfaces-only
    [ "$status" -eq 0 ]
    [[ "$output" != *"127.0.0.1"* ]]
    [[ "$output" == *"0.0.0.0"*"ALL_INTERFACES"* ]]
}

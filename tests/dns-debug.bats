#!/usr/bin/env bats

load helpers/test_helper

@test "successful answer" {
    DIG_MODE=ok run_script dns-debug.sh example.com --type A
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOERROR"* ]]
}

@test "nxdomain exits 2" {
    DIG_MODE=nxdomain run_script dns-debug.sh missing.example --type A
    [ "$status" -eq 2 ]
    [[ "$output" == *"NXDOMAIN"* ]]
}

@test "servfail exits 2" {
    DIG_MODE=servfail run_script dns-debug.sh example.com --type A
    [ "$status" -eq 2 ]
    [[ "$output" == *"SERVFAIL"* ]]
}

@test "timeout exits 2" {
    DIG_MODE=timeout run_script dns-debug.sh example.com --type A
    [ "$status" -eq 2 ]
    [[ "$output" == *"TIMEOUT"* ]]
}

@test "differing resolver comparison is allowed" {
    DIG_MODE=diff run_script dns-debug.sh example.com --type A --compare-resolvers
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.1.1"* ]]
}

@test "invalid hostname exits 3" {
    run_script dns-debug.sh "-bad.example"
    [ "$status" -eq 3 ]
}

@test "missing dig exits 3" {
    path_with_only_bash
    run_script_with_path dns-debug.sh "$MISSING_PATH" example.com
    [ "$status" -eq 3 ]
}

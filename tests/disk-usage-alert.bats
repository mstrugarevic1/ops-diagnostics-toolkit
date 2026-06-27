#!/usr/bin/env bats

load helpers/test_helper

@test "healthy filesystem exits 0" {
    DF_MODE=healthy run_script disk-usage-alert.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "warning threshold exits 1" {
    DF_MODE=warning run_script disk-usage-alert.sh --warning 80 --critical 90
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARNING"* ]]
}

@test "critical threshold exits 2" {
    DF_MODE=critical run_script disk-usage-alert.sh
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"* ]]
}

@test "invalid thresholds exit 3" {
    run_script disk-usage-alert.sh --warning 95 --critical 90
    [ "$status" -eq 3 ]
}

@test "missing df exits 3" {
    path_with_only_bash
    run_script_with_path disk-usage-alert.sh "$MISSING_PATH"
    [ "$status" -eq 3 ]
}

@test "inode warning is included when requested" {
    DF_MODE=healthy DF_INODE_MODE=warning run_script disk-usage-alert.sh --warning 80 --critical 90 --inodes
    [ "$status" -eq 1 ]
    [[ "$output" == *"IUSED"* ]]
    [[ "$output" == *"WARNING"* ]]
}

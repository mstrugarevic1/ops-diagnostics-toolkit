#!/usr/bin/env bats

load helpers/test_helper

@test "active service is OK" {
    run_script service-health-report.sh nginx --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"*"nginx"* ]]
}

@test "failed service exits 2" {
    run_script service-health-report.sh broken --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "missing service exits 2" {
    run_script service-health-report.sh missing --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"NOT_FOUND"* ]]
}

@test "failed journal access does not crash" {
    JOURNAL_DENIED=1 run_script service-health-report.sh nginx --logs 1 --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"journal access may require elevated permissions"* ]]
}

@test "missing systemctl exits 3" {
    path_with_only_bash
    run_script_with_path service-health-report.sh "$MISSING_PATH" nginx --no-color
    [ "$status" -eq 3 ]
}

@test "systemctl present without systemd exits 3" {
    SYSTEMCTL_NO_SYSTEMD=1 run_script service-health-report.sh --failed-only --no-color
    [ "$status" -eq 3 ]
    [[ "$output" == *"systemd is unavailable"* ]]
}

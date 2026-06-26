#!/usr/bin/env bash

setup() {
    export PATH="$BATS_TEST_DIRNAME/fixtures/bin:$PATH"
    export PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
}

path_with_only_bash() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -sf /bin/bash "$BATS_TEST_TMPDIR/bin/bash"
    export MISSING_PATH="$BATS_TEST_TMPDIR/bin"
}

run_script_with_path() {
    local script="$1" custom_path="$2"
    shift 2
    run env PATH="$custom_path" "$PROJECT_ROOT/scripts/$script" "$@"
}

run_script() {
    local script="$1"
    shift
    run "$PROJECT_ROOT/scripts/$script" "$@"
}

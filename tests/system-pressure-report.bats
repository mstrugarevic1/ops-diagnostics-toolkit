#!/usr/bin/env bats

load helpers/test_helper

make_pressure_proc() {
    export OPS_DIAG_PROC_ROOT="$BATS_TEST_TMPDIR/proc"
    mkdir -p "$OPS_DIAG_PROC_ROOT/pressure"
    cat >"$OPS_DIAG_PROC_ROOT/cpuinfo" <<'EOF'
processor	: 0
processor	: 1
EOF
    cat >"$OPS_DIAG_PROC_ROOT/loadavg" <<'EOF'
0.50 0.40 0.30 1/100 123
EOF
    cat >"$OPS_DIAG_PROC_ROOT/meminfo" <<'EOF'
MemTotal:       1000000 kB
MemAvailable:   500000 kB
SwapTotal:      200000 kB
SwapFree:       200000 kB
EOF
    for name in cpu memory io; do
        cat >"$OPS_DIAG_PROC_ROOT/pressure/$name" <<'EOF'
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF
    done
}

@test "healthy system pressure exits 0" {
    make_pressure_proc
    run_script system-pressure-report.sh --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"*"load"* ]]
    [[ "$output" == *"cpu_pressure"* ]]
}

@test "high load exits critical" {
    make_pressure_proc
    cat >"$OPS_DIAG_PROC_ROOT/loadavg" <<'EOF'
8.00 7.00 6.00 1/100 123
EOF
    run_script system-pressure-report.sh --warning-load 1.5 --critical-load 3.0 --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"*"load"* ]]
}

@test "high memory exits warning" {
    make_pressure_proc
    cat >"$OPS_DIAG_PROC_ROOT/meminfo" <<'EOF'
MemTotal:       1000000 kB
MemAvailable:   100000 kB
SwapTotal:      200000 kB
SwapFree:       200000 kB
EOF
    run_script system-pressure-report.sh --warning-memory 80 --critical-memory 95 --no-color
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARNING"*"memory"*"90%"* ]]
}

@test "high swap exits critical" {
    make_pressure_proc
    cat >"$OPS_DIAG_PROC_ROOT/meminfo" <<'EOF'
MemTotal:       1000000 kB
MemAvailable:   900000 kB
SwapTotal:      200000 kB
SwapFree:        10000 kB
EOF
    run_script system-pressure-report.sh --warning-swap 50 --critical-swap 80 --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"*"swap"*"95%"* ]]
}

@test "missing proc data reports unknown without failure" {
    export OPS_DIAG_PROC_ROOT="$BATS_TEST_TMPDIR/missing-proc"
    run_script system-pressure-report.sh --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNKNOWN"*"load"* ]]
}

@test "invalid thresholds exit 3" {
    run_script system-pressure-report.sh --warning-load bad --no-color
    [ "$status" -eq 3 ]
}

@test "oom pattern exits critical when requested" {
    make_pressure_proc
    OOM_MODE=seen run_script system-pressure-report.sh --check-oom --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"*"oom_kills"* ]]
}

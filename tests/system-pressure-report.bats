#!/usr/bin/env bats

load helpers/test_helper

make_pressure_proc() {
    local proc_root
    proc_root="$(mktemp -d)"
    mkdir -p "$proc_root/pressure"
    cat >"$proc_root/cpuinfo" <<'EOF'
processor	: 0
processor	: 1
EOF
    cat >"$proc_root/loadavg" <<'EOF'
0.50 0.40 0.30 1/100 123
EOF
    cat >"$proc_root/meminfo" <<'EOF'
MemTotal:       1000000 kB
MemAvailable:   500000 kB
SwapTotal:      200000 kB
SwapFree:       200000 kB
EOF
    for name in cpu memory io; do
        cat >"$proc_root/pressure/$name" <<'EOF'
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF
    done
    printf '%s\n' "$proc_root"
}

run_pressure() {
    run env OPS_DIAG_PROC_ROOT="$PRESSURE_PROC" "$PROJECT_ROOT/scripts/system-pressure-report.sh" "$@"
}

@test "healthy system pressure exits 0" {
    PRESSURE_PROC="$(make_pressure_proc)"
    run_pressure --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *"load"* ]]
    [[ "$output" == *"cpu_pressure"* ]]
}

@test "high load exits critical" {
    PRESSURE_PROC="$(make_pressure_proc)"
    cat >"$PRESSURE_PROC/loadavg" <<'EOF'
8.00 7.00 6.00 1/100 123
EOF
    run_pressure --warning-load 1.5 --critical-load 3.0 --no-color
    [ "$status" -eq 2 ]
    [[ "$output" == *"CRITICAL"*"load"* ]]
}

@test "high memory exits warning" {
    PRESSURE_PROC="$(make_pressure_proc)"
    cat >"$PRESSURE_PROC/meminfo" <<'EOF'
MemTotal:       1000000 kB
MemAvailable:   100000 kB
SwapTotal:      200000 kB
SwapFree:       200000 kB
EOF
    run_pressure --warning-memory 80 --critical-memory 95 --no-color
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARNING"*"memory"*"90%"* ]]
}

@test "invalid thresholds exit 3" {
    run_script system-pressure-report.sh --warning-load bad --no-color
    [ "$status" -eq 3 ]
}

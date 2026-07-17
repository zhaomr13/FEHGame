#!/usr/bin/env bash
# Run all headless tests in godot/tests/ and print a summary.
#
# A failing Godot assert() aborts the test script before it can call quit(),
# leaving the process running forever — so every test runs under a timeout
# and a timeout counts as a FAILURE. Never run these scripts without one.
#
# Usage: tools/run_tests.sh [test_name ...]   (names without .gd; default: all)
# Env:   GODOT_BIN    — Godot binary (default: macOS editor app)
#        TEST_TIMEOUT — per-test timeout in seconds (default: 120)

set -u
cd "$(dirname "$0")/../godot"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
TIMEOUT="${TEST_TIMEOUT:-120}"

if [ ! -x "$GODOT_BIN" ]; then
    echo "error: Godot binary not found at '$GODOT_BIN' (set GODOT_BIN)"
    exit 2
fi

run_with_timeout() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$secs" "$@"
    else
        # Stock macOS fallback (no coreutils needed)
        perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
    fi
}

if [ $# -gt 0 ]; then
    tests=("$@")
else
    tests=()
    for f in tests/test_*.gd; do
        tests+=("$(basename "$f" .gd)")
    done
fi

pass=0
failed=()
for t in "${tests[@]}"; do
    out=$(run_with_timeout "$TIMEOUT" "$GODOT_BIN" --headless --script "res://tests/$t.gd" 2>&1)
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "FAIL  $t (exit $rc — timeout or crash)"
        echo "$out" | tail -n 5 | sed 's/^/      /'
        failed+=("$t")
    elif echo "$out" | grep -q "SCRIPT ERROR"; then
        echo "FAIL  $t (script error)"
        echo "$out" | grep -A2 "SCRIPT ERROR" | head -n 6 | sed 's/^/      /'
        failed+=("$t")
    elif ! echo "$out" | grep -q "PASSED"; then
        echo "FAIL  $t (no PASSED marker in output)"
        echo "$out" | tail -n 5 | sed 's/^/      /'
        failed+=("$t")
    else
        echo "PASS  $t"
        pass=$((pass + 1))
    fi
done

echo
echo "passed: $pass, failed: ${#failed[@]}"
if [ ${#failed[@]} -gt 0 ]; then
    printf '  - %s\n' "${failed[@]}"
    exit 1
fi
exit 0

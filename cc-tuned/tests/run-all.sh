#!/usr/bin/env bash
# Run all cc-tuned Tier 1 + Tier 2 tests.
#
# Discovers all test-*.sh files under cc-tuned/tests/ and runs them.
# Each test must exit 0 on pass, non-zero on fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
shopt -s globstar nullglob

total=0
passed=0
failed_tests=()

for test in "$SCRIPT_DIR"/**/test-*.sh; do
    total=$((total + 1))
    echo "----- $(basename "$test") -----"
    if bash "$test"; then
        passed=$((passed + 1))
    else
        failed_tests+=("$test")
    fi
    echo
done

echo "========================================="
if [ $total -eq 0 ]; then
    echo "  ERROR: no test files found under $SCRIPT_DIR"
    exit 1
fi
echo "  $passed / $total test files passed"
if [ ${#failed_tests[@]} -gt 0 ]; then
    echo "  Failed:"
    for t in "${failed_tests[@]}"; do
        echo "    - $t"
    done
    exit 1
fi
echo "  All test files passed."

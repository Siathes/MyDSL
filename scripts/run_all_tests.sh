#!/usr/bin/env bash
# run_all_tests.sh -- single entry point for MyDSL's full regression suite.
#
# Why this exists: there was no run-all script as of 2026-08-29 -- every
# session ran each of the 48 test/*.lua files individually via luajit,
# which is exactly the kind of manual step that gets silently shortened
# ("ran a few, looked fine") under time pressure. Built specifically to
# support a clean before/after comparison across a Mudlet version upgrade
# (see docs/mudlet_upgrade_runbook.md), but it's a permanent addition --
# use it for the existing periodic "re-run the full suite independent of
# any specific fix" housekeeping item too (CLAUDE.md).
#
# What it runs, in order:
#   1. Every test/*.lua file (skips mudlet_mock.lua, the shared harness,
#      not a test itself) via luajit -- hard pass/fail on exit code.
#   2. Every test/*.py file via python3 -- hard pass/fail on exit code.
#   3. scripts/check_known_patterns.py --all -- hard pass/fail.
#   4. scripts/check_text_coverage.py and scripts/check_help_coverage.py --
#      advisory: run and shown in full, but don't fail the suite, since
#      both are heuristic drift-detectors meant to be eyeballed, not
#      strict gates (see their own docstrings).
#
# Usage: ./run_all_tests.sh          (from the repo root)
#        ./run_all_tests.sh > run1.log 2>&1   (save a baseline to diff later)
#
# Exit code: 0 if every hard-gated test passed, 1 if any failed.

set -u
cd "$(dirname "$0")/.." 2>/dev/null || cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

LUA_BIN=""
for candidate in luajit lua5.1 lua; do
  if command -v "$candidate" >/dev/null 2>&1; then
    LUA_BIN="$candidate"
    break
  fi
done

if [ -z "$LUA_BIN" ]; then
  echo "ERROR: no luajit/lua5.1/lua found on PATH -- cannot run the Lua suite." >&2
  exit 2
fi

PASS=0
FAIL=0
FAILED_NAMES=()

echo "=== Lua test suite ($LUA_BIN) ==="
for f in test/test_*.lua; do
  name=$(basename "$f")
  out=$("$LUA_BIN" "$f" 2>&1)
  code=$?
  if [ $code -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "PASS  $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL  $name (exit $code)"
    echo "$out" | sed 's/^/      /'
  fi
done

echo ""
echo "=== Python test suite ==="
for f in test/test_*.py; do
  name=$(basename "$f")
  out=$(python3 "$f" 2>&1)
  code=$?
  if [ $code -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "PASS  $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL  $name (exit $code)"
    echo "$out" | sed 's/^/      /'
  fi
done

echo ""
echo "=== Known-bad-pattern sweep (hard gate) ==="
if python3 scripts/check_known_patterns.py --all; then
  echo "PASS  check_known_patterns.py --all"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("check_known_patterns.py --all")
  echo "FAIL  check_known_patterns.py --all"
fi

echo ""
echo "=== Text/help coverage (advisory -- read, don't gate on) ==="
echo "--- check_text_coverage.py ---"
python3 scripts/check_text_coverage.py || echo "(non-zero exit -- read output above, not auto-failed)"
echo "--- check_help_coverage.py ---"
python3 scripts/check_help_coverage.py || echo "(non-zero exit -- read output above, not auto-failed)"

echo ""
echo "=== SUMMARY ==="
echo "Pass: $PASS   Fail: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failed:"
  for n in "${FAILED_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
exit 0

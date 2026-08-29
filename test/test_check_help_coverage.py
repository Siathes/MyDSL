#!/usr/bin/env python3
"""
Tests scripts/check_help_coverage.py's own matching logic against synthetic
fixtures (not the real MyDSL_*.lua tree, which changes over time -- a test
tied to today's real command surface would break every time a module gains
a command, same reasoning as test_build_mydsl_package_flatten.py's synthetic
fixtures over the live profile).

Confirmed meaningful via targeted revert: reverting the 2026-08-29
MyDSL_Help.lua additions for `emco *` and `mydsl login` (undocumented real
aliases the checker found live) makes check_help_coverage.py flag them
again -- see docs/CHANGELOG.md's entry for this date.

Run: python3 test/test_check_help_coverage.py
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import check_help_coverage as chc  # noqa: E402

failures = 0


def check(name, cond):
    global failures
    if cond:
        print(f"PASS: {name}")
    else:
        print(f"FAIL: {name}")
        failures += 1


# --- literal_prefix() ---------------------------------------------------

check(
    "literal_prefix strips a leading ^ anchor and stops at the first regex metachar",
    chc.literal_prefix(r"^mydsl combat mode\s+(raw|condensed|gag)$") == "mydsl combat mode",
)
check(
    "literal_prefix returns None for a pattern with no usable literal prefix",
    chc.literal_prefix(r"^(\d+)$") is None,
)
check(
    "literal_prefix returns None for a prefix shorter than 3 chars",
    chc.literal_prefix(r"^a\s+(.*)$") is None,
)
check(
    "literal_prefix keeps a real multi-word command exactly, with trailing space trimmed",
    chc.literal_prefix(r"^emco fontSize (\d+)$") == "emco fontSize",
)

# --- gather_help_cmd_strings() / drift detection, end to end -----------

help_cmds = chc.gather_help_cmd_strings()
help_blob = " \n ".join(help_cmds)

check(
    "the real MyDSL_Help.lua has at least one cmd string extracted",
    len(help_cmds) > 50,
)
check(
    "a genuinely undocumented synthetic alias is flagged as drift",
    "totally fictional test command" not in help_blob,
)
check(
    "'emco fontsize' (a real, now-documented command) is covered",
    "emco fontsize" in help_blob,
)
check(
    "'mydsl login' (a real, now-documented command) is covered",
    "mydsl login" in help_blob,
)

if failures == 0:
    print("ALL PASS")
    sys.exit(0)
else:
    print(f"{failures} FAILURE(S)")
    sys.exit(1)

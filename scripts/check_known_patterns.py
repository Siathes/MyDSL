#!/usr/bin/env python3
"""
check_known_patterns.py -- a project-local, grep-based checker for
mistakes this codebase has actually made before, encoded as concrete
rules rather than a generic linter's syntax-only checks.

Why this exists: on 2026-07-21, Steven asked why the same class of bug
("</cyan>" used as a cecho closing tag -- invalid; the real syntax is
"<reset>") kept turning up in files nobody had re-checked since the
mistake was first fixed elsewhere, and whether a newer AI model would
help. It wouldn't have -- the gap is that fixing a bug in ONE file never
propagated a check to every OTHER file with the same latent mistake.
This script is the propagation step: every rule here is a real, cited
historical bug from docs/CHANGELOG.md, not a hypothetical.

Runs two ways:
  1. As a Claude Code PostToolUse hook (see .claude/settings.json) --
     reads the tool-call JSON from stdin, checks only the ONE file just
     edited, and blocks with feedback if a known-bad pattern is found.
     Fast, immediate, catches new mistakes the moment they're written.
  2. As a manual full-repo sweep: `python3 scripts/check_known_patterns.py
     --all` -- checks every tracked .lua file. Catches mistakes already
     sitting in files that haven't been touched/live-tested recently
     (this is what the 2026-07-21 audit did by hand; this script is that
     same check, made repeatable).

Adding a new rule: when a NEW class of bug gets fixed in one file,
suspecting it might exist elsewhere too, add one entry to RULES below
instead of (or in addition to) manually grepping every sibling file --
that grep becomes permanent instead of a one-off.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Each rule: (name, compiled regex, message, file_glob_suffix)
# file_glob_suffix restricts a rule to certain files (most apply to all
# .lua files); None means "all .lua files".
RULES = [
    (
        "cecho-invalid-closing-tag",
        re.compile(r"</(?:cyan|red|green|yellow|white|magenta|blue|black|"
                    r"orange|purple|grey|gray)>"),
        "Invalid cecho/decho closing tag -- Mudlet's cecho doesn't use "
        "HTML-style </color> closing tags, only <reset> (or another "
        "color). Real bug found live 2026-07-21 in MyDSL_LiveView.lua "
        "and MyDSL_LocationView.lua, both fixed same day -- see "
        "docs/CHANGELOG.md 2026-07-21.",
        ".lua",
    ),
    (
        "table-load-single-arg",
        re.compile(r"table\.load\(\s*[^,()]+\s*\)"),
        "table.load(path) called with only ONE argument. Mudlet's real "
        "table.load(file, target) has NO return value -- it unpickles "
        "into the second argument (or _G if omitted). A single-arg call "
        "silently discards the loaded data every time. Confirmed a "
        "project-wide critical bug 2026-07-11 across 9 files -- see "
        "docs/CHANGELOG.md 2026-07-11. Use table.load(path, target) or "
        "pcall(table.load, path, target).",
        ".lua",
    ),
    (
        "table-unpack-bare",
        re.compile(r"(?<!\.)\btable\.unpack\("),
        "table.unpack() does not exist in Mudlet's real Lua runtime -- "
        "only the bare global unpack() does. Confirmed clean project-wide "
        "as of the 2026-07-21 audit; this rule exists to keep it that way.",
        ".lua",
    ),
    (
        "python-style-f-string",
        # Requires an actual { after the opening quote (before it closes) --
        # a bare `\bf["']` also matches incidental "...f" string endings
        # like `["%%f"] = ...` (the f is the last char of an unrelated
        # string, not an f-string prefix) -- confirmed false-positiving on
        # 6 real lines in PNP files/EMCOChat/MyDSL_DataLayer_Combat.lua
        # before this was tightened. Every real f-string bug found this
        # session had a {...} placeholder, since that's the entire point
        # of using one.
        re.compile(r"""\bf(['"])[^'"]*\{"""),
        "f\"...\"/f'...' Python-style string interpolation does not exist "
        "in Lua -- this parses as calling a function named f with a "
        "string argument, which errors at runtime ('attempt to call "
        "global \\'f\\' (a nil value)') unless f happens to be defined. "
        "Confirmed hit twice: the DSL PNP 4 community package (checked "
        "2026-08-29, not adopted because of this) and, independently, "
        "live in this project's own MyDSL_Chat.lua (8 real call sites, "
        "fixed same day -- see docs/CHANGELOG.md 2026-08-29). Use string "
        "concatenation (..) instead.",
        ".lua",
    ),
]


# Directories excluded from every rule: confirmed-dead vendored code this
# project has explicitly decided not to maintain or fix (CLAUDE.md:
# "EMCO is already fully integrated... confirmed dead vendored copy,
# nothing further to do"). Flagging real bugs here forever would make
# this sweep a permanently-red gate for something nobody's going to
# touch -- added 2026-08-29 after the python-style-f-string rule (also
# added that day) found 8 real, genuine hits in EMCOChat/emco.lua, the
# unused predecessor MyDSL_Chat.lua was ported from and fixed
# independently. If EMCOChat/ is ever revived/re-integrated, remove it
# from this list first.
EXCLUDED_DIRS = ("EMCOChat/",)


def find_lua_files():
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "*.lua"],
        capture_output=True, text=True, check=True,
    )
    return [
        REPO_ROOT / p for p in result.stdout.splitlines()
        if p.strip() and not p.startswith(EXCLUDED_DIRS)
    ]


def check_file(path: Path):
    """Returns a list of (rule_name, message, line_no, line_text) hits."""
    if not path.exists() or path.suffix != ".lua":
        return []
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return []
    lines = text.split("\n")
    hits = []
    for name, pattern, message, _suffix in RULES:
        for i, line in enumerate(lines, start=1):
            # Skip full-line comments -- this codebase documents its own
            # past mistakes in comments (e.g. "this used to call
            # table.load(path) with no second argument"), which would
            # otherwise false-positive on every rule below forever.
            if line.strip().startswith("--"):
                continue
            if pattern.search(line):
                hits.append((name, message, i, line.strip()))
    return hits


def run_full_sweep():
    total_hits = 0
    for path in find_lua_files():
        hits = check_file(path)
        for name, message, lineno, line in hits:
            total_hits += 1
            rel = path.relative_to(REPO_ROOT)
            print(f"{rel}:{lineno}: [{name}] {line}")
            print(f"    -> {message}")
    if total_hits == 0:
        print("Full sweep: no known-bad patterns found.")
        return 0
    print(f"\n{total_hits} finding(s).")
    return 1


def run_hook_mode():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # can't parse input, don't block
    tool_input = payload.get("tool_input", {}) or {}
    file_path = tool_input.get("file_path")
    if not file_path:
        return 0
    path = Path(file_path)
    hits = check_file(path)
    if not hits:
        return 0
    lines = [f"Known-bad pattern check found {len(hits)} issue(s) in {path.name}:"]
    for name, message, lineno, line in hits:
        lines.append(f"  line {lineno} [{name}]: {line}")
        lines.append(f"    -> {message}")
    print(json.dumps({"decision": "block", "reason": "\n".join(lines)}))
    return 0  # exit 0 with a "block" decision in the JSON body


if __name__ == "__main__":
    if "--all" in sys.argv:
        sys.exit(run_full_sweep())
    else:
        sys.exit(run_hook_mode())

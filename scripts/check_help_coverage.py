#!/usr/bin/env python3
"""
check_help_coverage.py -- drift check between MyDSL_Help.lua's hand-
maintained command table and the real, currently-registered tempAlias()
patterns across every MyDSL_*.lua file.

Why this instead of the originally-floated "auto-derive Help.lua at
runtime from annotated tempAlias() calls" idea (docs/TODO.md, Steven:
"this has fallen behind... auto-derive sounds good"): that approach
means touching every one of this codebase's ~189 tempAlias() call sites
to add description/example metadata at registration time -- a large,
invasive, hard-to-verify-without-live-testing rewrite across ~20 files,
for a help system whose own header already documents "hand-maintained
... keep this in sync by hand" as a known, accepted trade-off since
2026-07-15. Given MyDSL_Help.lua's own content table already has real
descriptions/examples with actual prose quality a bare pattern string
never would, replacing it wholesale isn't obviously better -- what
Steven's "fallen behind" complaint is actually pointing at is DRIFT
(a real alias existing with no matching help entry, or vice versa),
which this script catches automatically without touching a single
tempAlias() call site, the same "small script, wired into the existing
housekeeping routine" shape as check_known_patterns.py.

What this checks: for every tempAlias() call across MyDSL_*.lua whose
first argument is an inline string literal, extract the longest literal
(non-regex-metacharacter) prefix -- the closest thing to a "keyword
signature" for that command without a real Lua/PCRE parser -- and check
whether ANY of MyDSL_Help.lua's own `cmd = "..."` strings plausibly
documents it (a loose substring/keyword match, not exact -- Help.lua's
own cmd strings use human-readable placeholders like "<name>" that
don't literally appear in the real regex). Reports aliases with no
plausible matching help entry as candidates for a missing/stale doc
entry -- a real finding to investigate, not an automatic "definitely
wrong" verdict, since a loose keyword match can miss legitimate
phrasing differences.

Known blind spots, stated plainly rather than assumed away (same
class already documented in check_text_coverage.py for the identical
extraction technique):
  - Aliases built through a wrapper function (MyDSL_ChatTriggers.lua's
    route(), MyDSL_MoonWeather.lua's reg()) rather than a direct
    tempAlias(...) call are invisible to this scan -- their first
    argument to the real tempAlias() call is a variable, not a literal.
  - Aliases registered from inside a loop over a table of literals
    (none observed in this codebase's tempAlias calls as of this
    write) would also be invisible.
  - This is a KEYWORD heuristic, not a real command-line parser --
    genuine false positives (a real alias that IS documented, just
    under different wording) are expected and worth eyeballing before
    treating a report as an actionable gap.

Run: python3 scripts/check_help_coverage.py
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_text_coverage as ctc  # reuse the existing tempAlias-literal extractor


def literal_prefix(pattern):
    """The longest leading run of plain, non-regex-metacharacter text in a
    PCRE pattern -- e.g. '^mydsl combat mode\\s+(raw|condensed|gag)$' ->
    'mydsl combat mode'. Strips a leading '^' anchor first (always present
    in this codebase's real alias patterns). Returns None if nothing
    usable remains (e.g. a pattern with no literal prefix at all)."""
    p = pattern.lstrip("^")
    m = re.match(r"[A-Za-z0-9 _/'\-]+", p)
    if not m:
        return None
    prefix = m.group(0).strip()
    return prefix if len(prefix) >= 3 else None


def gather_real_aliases():
    """(prefix, full_pattern, source_file) for every tempAlias() call with
    an inline literal first argument, across every MyDSL_*.lua file."""
    out = []
    for path in ctc.find_lua_files():
        source = path.read_text(encoding="utf-8", errors="replace")
        for pattern in ctc._find_calls(source, ["tempAlias"]):
            prefix = literal_prefix(pattern)
            if prefix:
                out.append((prefix, pattern, path.name))
    return out


def gather_help_cmd_strings():
    """Every `cmd = "..."` string literal from MyDSL_Help.lua's own
    content table, lowercased for loose matching."""
    help_path = REPO_ROOT / "MyDSL_Help.lua"
    source = help_path.read_text(encoding="utf-8", errors="replace")
    cmds = re.findall(r'cmd\s*=\s*"((?:[^"\\]|\\.)*)"', source)
    return [c.lower() for c in cmds]


def main():
    real_aliases = gather_real_aliases()
    help_cmds = gather_help_cmd_strings()
    help_blob = " \n ".join(help_cmds)

    print(f"{len(real_aliases)} tempAlias() calls with an extractable literal prefix")
    print(f"{len(help_cmds)} documented commands in MyDSL_Help.lua")
    print()

    # A prefix "documents" if its own first significant word (skipping the
    # generic "mydsl" namespace word, present in most but not all real
    # aliases) appears somewhere in the help blob -- loose on purpose, see
    # the module docstring's stated heuristic limits.
    undocumented = []
    for prefix, pattern, source_file in real_aliases:
        words = [w for w in prefix.lower().split() if w != "mydsl"]
        if not words:
            continue
        signature = " ".join(words[:3])  # first few words is usually enough to be a real signature
        if signature not in help_blob and words[0] not in help_blob:
            undocumented.append((prefix, pattern, source_file))

    if not undocumented:
        print("No obvious drift found -- every real alias's keyword prefix appears somewhere in MyDSL_Help.lua.")
        return

    print(f"=== {len(undocumented)} alias(es) with no plausible matching help entry ===")
    print("(keyword heuristic -- eyeball before treating as a confirmed gap; see this script's own docstring)")
    by_file = {}
    for prefix, pattern, source_file in undocumented:
        by_file.setdefault(source_file, []).append((prefix, pattern))
    for source_file in sorted(by_file):
        print(f"\n{source_file}:")
        for prefix, pattern in by_file[source_file]:
            print(f"  {prefix!r}  (full pattern: {pattern})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
check_text_coverage.py -- computed coverage check for the MyDSL 1.0
global mandate ("take any line of text in DSL and know what to do with
it"), replacing the originally-planned hand-written known-text taxonomy
(docs/MYDSL_1.0_PHILOSOPHY.md Principle 4, Part A).

Why computed instead of hand-written: real log-parsing tools that solve
this exact problem (Grok, Fluentd, Drain) all lean toward a computed,
self-updating coverage check over a hand-maintained document, for the
same reason this project's own docs/DSL_CommandRef.md exists instead of
a prose contract -- a hand-written list drifts the moment the real code
changes and nothing re-checks it. MyDSL has a real advantage those
general-purpose tools don't: almost all of its text-classification logic
already exists as literal patterns in the source (tempRegexTrigger/
tempAlias PCRE patterns, native Trigger regexCodeList entries, and the
internal :match()/:find() Lua-pattern calls that do the real
per-line classification inside a begin/end capture block). This script
extracts those patterns directly from the real, current source -- same
extraction-not-paraphrase technique as test/test_mapper_gmcp_and_
doorverb.lua -- and checks how much of the real log/ corpus they
actually cover.

Two genuinely different pattern dialects exist in this codebase and are
tested with the ENGINE THAT ACTUALLY RUNS THEM, not a stand-in that
might silently disagree:
  - PCRE (tempRegexTrigger/tempAlias arguments, native Trigger
    regexCodeList entries) -- tested via real `perl`, not Python's re.
    This project's own test/README.md already documents that Python's
    re is only "near-identical" to PCRE, not identical, and specifically
    recommends perl as the real cross-check for exactly this reason.
  - Lua patterns (:match()/:find() literal arguments, used for internal
    line classification inside begin/end capture blocks -- :gmatch()
    deliberately excluded, see the comment at _LUA_METHODS below)
    -- tested via real `luajit`, the same interpreter Mudlet itself
    embeds. Lua patterns and PCRE are NOT the same dialect (this
    project has hit real bugs from conflating them before -- e.g. the
    door-verb `|`-alternation bug, which only works in PCRE) -- running
    a Lua pattern through Perl or Python's re would silently misreport
    coverage, exactly the "false covered reading" this tool exists to
    avoid.

What this reports: NOT a bare "% of lines matched" -- that number will
never hit 100 and shouldn't (plenty of narrative room description text
has no reason to be classified at all). What matters is which UNMATCHED
line shapes repeat often. A line shape appearing 40 times with zero
pattern coverage is a real gap; a line appearing once is probably just
narrative text and isn't flagged with the same priority. Unmatched
lines are grouped by a coarse structural "shape" (numbers and likely
proper-noun runs replaced with placeholders) and reported by descending
frequency.

Scope, stated plainly rather than silently assumed:
  - Every git-tracked MyDSL_*.lua file, plus DSL_Generic_Mapper.xml's
    embedded Lua (both its own <script> bodies and every active native
    <Trigger>'s regexCodeList -- the mapper fork has NO tempRegexTrigger
    calls of its own; all of its real line-dispatch happens through 3
    native Trigger objects, so skipping regexCodeList would make this
    tool report near-zero coverage for a 6,631-line file that's
    genuinely dispatching a large share of real game text. This is a
    best-effort structural scan of the XML, not a full XML-tree parser
    -- the trigger count found is printed so this is auditable, not a
    silent guess).
  - log/AGL/ is deliberately EXCLUDED from the corpus -- per CLAUDE.md,
    every line there carries a Coliseum broadcast prefix the regular
    combat tracker is deliberately anchored NOT to match (see
    MyDSL_DataLayer_Combat.lua's combatDamage trigger comment). Including
    it would misreport a deliberate design choice as a coverage gap.
  - test/*.lua is excluded from pattern extraction (it exercises real
    patterns, doesn't define new ones the game would ever need to match
    against).

Known blind spots, found by Claude Desktop's 2026-08-26 spot-check
(HANDOFF.md), confirmed against current source, not yet fixed:
  - _find_calls() only extracts a pattern when it's an inline literal
    at the tempRegexTrigger(/tempAlias( call site itself. A pattern
    passed in through a variable, a loop over a table of literals, or a
    wrapper function is invisible to it. Confirmed real, currently-live
    misses: all 20 of MyDSL_ChatTriggers.lua's chat-routing patterns
    (built via its own route() wrapper), the 9 spellup-outcome patterns
    in MyDSL_CharacterAssist.lua (looped from successPatterns/
    failPatterns), and the 4 buff-wearoff patterns in MyDSL_Leveling.lua
    (looped from BUFF_WEAROFF). Any corpus line these already correctly
    handle shows up in this tool's "top unmatched shapes" as a false
    gap. Fix would be walking local functions whose call shape wraps
    tempRegexTrigger/tempAlias, not attempted here.
  - The genericness filter's synthetic fillers don't combine letters and
    digits, so a :find()/:match() pattern that's actually a check on an
    already-narrowed local variable (not a whole-line classifier -- the
    same blind spot already documented above for :gmatch(), just not
    yet extended to plain :match()/:find()) can survive both extraction
    and the genericness filter and grant false "covered" credit to any
    real corpus line shape containing a digit. One confirmed instance:
    DSL_Generic_Mapper.xml:5009's featureName:find("%d").

Run: python3 scripts/check_text_coverage.py
     python3 scripts/check_text_coverage.py --top 50       (more buckets)
     python3 scripts/check_text_coverage.py --selftest      (verify only)
"""
import html
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = REPO_ROOT / "log"
MAPPER_XML = REPO_ROOT / "DSL_Generic_Mapper.xml"
SCRATCH = REPO_ROOT / ".text_coverage_scratch"


# =============================================================================
# STEP 1: extract real patterns from real source (extraction, not paraphrase)
# =============================================================================

# Matches a Lua string literal immediately after an opening paren: one of
# [[...]], [=...=[...]=...=], "..." (with \" escapes), '...' (with \' escapes).
# Used to pull the literal pattern argument out of tempRegexTrigger(<here>,...)
# / tempAlias(<here>,...) / thing:match(<here>) / thing:find(<here>) calls.
_LONG_BRACKET_OPEN = re.compile(r"\[(=*)\[")
_DQUOTE = re.compile(r'"((?:[^"\\]|\\.)*)"')
_SQUOTE = re.compile(r"'((?:[^'\\]|\\.)*)'")


def _extract_literal_at(text, pos):
    """Given text and a position right after '(', try to read one Lua
    string literal starting there (skipping leading whitespace). Returns
    (literal_or_None, end_pos_after_literal)."""
    i = pos
    while i < len(text) and text[i] in " \t\n":
        i += 1
    m = _LONG_BRACKET_OPEN.match(text, i)
    if m:
        eq = m.group(1)
        close = "]" + eq + "]"
        end = text.find(close, m.end())
        if end == -1:
            return None, i
        return text[m.end():end], end + len(close)
    m = _DQUOTE.match(text, i)
    if m:
        return m.group(1), m.end()
    m = _SQUOTE.match(text, i)
    if m:
        return m.group(1), m.end()
    return None, i


def _find_calls(source, call_names):
    """Find every `<name>(` call for name in call_names, return the first
    string-literal argument for each (skips calls whose first arg isn't a
    literal, e.g. a variable -- those aren't extractable without a real
    Lua parser, and are out of scope here, same as check_known_patterns.py
    only checking what's mechanically greppable)."""
    out = []
    for name in call_names:
        for m in re.finditer(re.escape(name) + r"\s*\(", source):
            lit, _ = _extract_literal_at(source, m.end())
            if lit is not None and "\n" not in lit:
                out.append(lit)
            # multi-line literal patterns are skipped (none observed in this
            # codebase's real tempRegexTrigger/match calls as of this write,
            # but silently mis-scanning one would be worse than skipping it)
    return out


def _rest_of_call_args(source, pos_after_pattern, call_open_pos):
    """From just after the pattern literal, find this call's closing ')'
    (naive paren-depth counter, starting at 1 for the '(' at
    call_open_pos) and return the raw text of any remaining arguments."""
    depth = 1
    i = pos_after_pattern
    while i < len(source) and depth > 0:
        c = source[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return source[pos_after_pattern:i]
        i += 1
    return source[pos_after_pattern:i]


def _find_method_calls(source, method_names, origin):
    """Real fixed version of the :match()/:find() scan -- method
    names passed WITHOUT the trailing '(' (added once here).

    Two real false-classification bugs found and fixed here, both caught
    by this tool's own self-test on real source, not hypothetical:
      1. `s:find(pattern, init, true)` -- the trailing `true` is Lua's
         real `plain` argument to string.find(), which makes the WHOLE
         call a literal substring search, not a pattern match at all
         (confirmed real case: MyDSL_TargetView.lua's `def.template:
         find("%t", 1, true)`, a template-placeholder substring check,
         not game-text classification). Skipped entirely when detected.
      2. `s:find("%f[%a]" .. w .. "%f[%A]")` -- string concatenation
         building the real pattern at runtime from a variable (`w`);
         the literal extracted here would only ever be the FIRST
         fragment, not the real pattern, which isn't statically knowable
         without executing the code. Skipped when the pattern literal is
         immediately followed by Lua's `..` operator, same principle as
         "skip a variable argument" already applied to non-literal cases.
    """
    out = []
    for name in method_names:
        token = name + "("
        for m in re.finditer(re.escape(token), source):
            lit, end = _extract_literal_at(source, m.end())
            if lit is None or "\n" in lit:
                continue
            rest = _rest_of_call_args(source, end, m.end() - 1)
            # Bug 2: concatenation immediately after the literal.
            stripped_rest = rest.lstrip()
            if stripped_rest.startswith(".."):
                continue
            # Bug 1: find()'s trailing plain=true argument.
            if name == ":find":
                args = [a.strip() for a in rest.split(",")]
                # rest starts with ", init, plain)" contents (leading
                # comma already split off as an empty first element) --
                # a real plain=true call has exactly 2 more args here.
                if len(args) >= 3 and args[2] == "true":
                    continue
            out.append((lit, origin))
    return out


# :gmatch() deliberately excluded from Category B, found and fixed via
# this tool's own self-test on real source: gmatch() returns an ITERATOR
# for repeated matches within an already-known string (`for word in
# s:gmatch("%a+") do`) -- confirmed real case: DSL_Generic_Mapper.xml's
# `for d in opened:gmatch("%a+") do`, tokenizing an ALREADY-EXTRACTED
# "Opened doors: north east" substring into individual words. That's not
# "does the whole incoming line match a known shape" the way :match()/
# :find() naturally are (first-match-or-nil, boolean-ish) -- it's a
# tokenization helper on already-narrowed text, and treating its pattern
# as a whole-line classifier produces exactly the false-broad-coverage
# reading this tool exists to catch (":%a+" alone "covering" any line
# with a single letter in it).
_LUA_METHODS = [":match", ":find"]


def extract_lua_file(path):
    source = path.read_text(encoding="utf-8", errors="replace")
    origin = str(path.relative_to(REPO_ROOT))
    pcre = [(p, origin) for p in _find_calls(source, ["tempRegexTrigger", "tempAlias"])]
    lua = _find_method_calls(source, _LUA_METHODS, origin)
    return pcre, lua


def find_lua_files():
    return sorted(p for p in REPO_ROOT.glob("MyDSL_*.lua"))


# ---- DSL_Generic_Mapper.xml: <script> bodies + native Trigger regexCodeList

def _xml_unescape(s):
    return html.unescape(s)


def extract_mapper_xml(path):
    xml = path.read_text(encoding="utf-8", errors="replace")
    origin_base = str(path.relative_to(REPO_ROOT))

    pcre_all, lua_all = [], []

    # 1. Every <script>...</script> body, scanned the same way as a .lua
    #    file, in case any tempRegexTrigger/tempAlias/:match call lives
    #    inside the embedded Lua (the map.dsl fork itself uses none as of
    #    this write -- all its dispatch is via the native Triggers below
    #    -- but scanning defensively costs nothing and stays correct if
    #    that ever changes).
    script_bodies = re.findall(r"<script>(.*?)</script>", xml, re.DOTALL)
    for body in script_bodies:
        unescaped = _xml_unescape(body)
        pcre = [(p, origin_base + " <script>") for p in _find_calls(unescaped, ["tempRegexTrigger", "tempAlias"])]
        lua = _find_method_calls(unescaped, _LUA_METHODS, origin_base + " <script>")
        pcre_all.extend(pcre)
        lua_all.extend(lua)

    # 2. Native <Trigger isActive="yes">...<name>NAME</name>...
    #    <regexCodeList>...<string>PATTERN</string>...</regexCodeList>
    #    Best-effort structural scan, not a full XML tree parser -- this
    #    file has no nested <Trigger> inside <regexCodeList> so a
    #    non-greedy block match between consecutive <Trigger tags is
    #    reliable in practice. Mudlet's regex trigger engine is PCRE
    #    (confirmed project-wide -- see CLAUDE.md), so these go in the
    #    PCRE bucket alongside tempRegexTrigger.
    trigger_blocks = re.findall(
        r'<Trigger isActive="yes"[^>]*>(.*?)</Trigger>', xml, re.DOTALL
    )
    trigger_count = 0
    pattern_count = 0
    for block in trigger_blocks:
        trigger_count += 1
        name_m = re.search(r"<name>(.*?)</name>", block, re.DOTALL)
        name = _xml_unescape(name_m.group(1)).strip() if name_m else "(unnamed)"
        rcl_m = re.search(r"<regexCodeList>(.*?)</regexCodeList>", block, re.DOTALL)
        if not rcl_m:
            continue
        for s_m in re.finditer(r"<string>(.*?)</string>", rcl_m.group(1), re.DOTALL):
            pat = _xml_unescape(s_m.group(1))
            if pat and "\n" not in pat:
                pcre_all.append((pat, origin_base + f" <Trigger:{name}>"))
                pattern_count += 1

    print(f"  [mapper] scanned {len(script_bodies)} <script> block(s), "
          f"{trigger_count} active native Trigger(s) with "
          f"{pattern_count} regexCodeList pattern(s)")
    return pcre_all, lua_all


# =============================================================================
# STEP 2: extract real corpus lines from log/ (excluding log/AGL/)
# =============================================================================

_TAG = re.compile(r"<[^>]+>")
_BR_OR_P_CLOSE = re.compile(r"<br\s*/?>|</p>", re.IGNORECASE)


def _collapse_internal_newlines(s):
    # Real bug found on this tool's first real corpus run: some of these
    # HTML log files have a literal physical newline in the raw file
    # BETWEEN <span> tags that both belong to the same logical line
    # (same <br>-to-<br> unit) -- splitting only on the <br>/</p> marker
    # then leaves that raw \n or \r sitting inside one "line" string.
    # That silently desynced this script's own line-count alignment
    # between the Python line list and the perl/luajit matcher output
    # (one Python "line" became 2+ lines once written to a file and read
    # back by <$lf>), causing an IndexError, not a wrong-but-silent
    # answer -- caught immediately, not shipped. Collapsing to a single
    # space keeps the logical line intact as one row everywhere
    # downstream, matching what a real Mudlet trigger actually saw (one
    # server-sent line), not an artifact of how this file was written.
    return re.sub(r"[\r\n]+", " ", s)


def extract_html_lines(text):
    # Mudlet's HTML log format wraps runs of differently-colored text in
    # consecutive <span style="...">...</span> tags, with a line boundary
    # marked by <br> or a </p> close -- NOT one <span> per visual line.
    # Reconstructing the real line requires joining every span between
    # boundaries, not naively splitting on <span> itself.
    body_m = re.search(r"<body[^>]*>(.*)</body>", text, re.DOTALL | re.IGNORECASE)
    body = body_m.group(1) if body_m else text
    # Normalize both boundary forms to a single marker, then strip all tags.
    body = _BR_OR_P_CLOSE.sub("\x01", body)
    body = _TAG.sub("", body)
    lines = [_collapse_internal_newlines(html.unescape(l)) for l in body.split("\x01")]
    return [l.strip() for l in lines if l.strip()]


def extract_txt_lines(text):
    return [_collapse_internal_newlines(l).strip() for l in text.split("\n") if l.strip()]


def gather_corpus_lines():
    lines = []
    files_used = 0
    for path in sorted(LOG_DIR.rglob("*")):
        if not path.is_file():
            continue
        if LOG_DIR / "AGL" in path.parents:
            continue
        if path.suffix.lower() == ".html":
            text = path.read_text(encoding="utf-8", errors="replace")
            lines.extend(extract_html_lines(text))
            files_used += 1
        elif path.suffix.lower() == ".txt":
            text = path.read_text(encoding="utf-8", errors="replace")
            lines.extend(extract_txt_lines(text))
            files_used += 1
    return lines, files_used


# =============================================================================
# STEP 3: real-engine matching (perl for PCRE, luajit for Lua patterns)
# =============================================================================

_PERL_MATCHER = r"""
use strict; use warnings;
my $pat_file = shift @ARGV;
my $line_file = shift @ARGV;
open(my $pf, "<:encoding(UTF-8)", $pat_file) or die $!;
my @patterns;
while (my $p = <$pf>) {
  chomp $p;
  next if $p eq "";
  my $re = eval { qr/$p/ };
  push @patterns, $re if defined $re;
}
close $pf;
open(my $lf, "<:encoding(UTF-8)", $line_file) or die $!;
while (my $line = <$lf>) {
  chomp $line;
  my $covered = 0;
  for my $re (@patterns) {
    if (eval { $line =~ $re }) { $covered = 1; last; }
  }
  print $covered ? "1\n" : "0\n";
}
"""

_LUA_MATCHER = r"""
local patFile, lineFile = arg[1], arg[2]
local patterns = {}
for p in io.lines(patFile) do
  if p ~= "" then patterns[#patterns+1] = p end
end
for line in io.lines(lineFile) do
  local covered = false
  for _, p in ipairs(patterns) do
    local ok, result = pcall(string.match, line, p)
    if ok and result then covered = true; break end
  end
  io.write(covered and "1\n" or "0\n")
end
"""


def _check_alignment(hits, lines, engine_name):
    # Defensive, not decorative: this exact mismatch happened for real on
    # this tool's first corpus run (embedded raw newlines desynced the
    # line count -- see _collapse_internal_newlines()) and surfaced only
    # as a confusing IndexError several lines later in the caller. Fail
    # immediately and clearly here instead, so any FUTURE desync (a
    # different encoding edge case, a corpus file this fix doesn't cover)
    # is obvious at the source, not a stack trace pointing somewhere else.
    if len(hits) != len(lines):
        raise RuntimeError(
            f"{engine_name} returned {len(hits)} result rows for {len(lines)} input lines -- "
            f"a real line-count desync, not a downstream bug. Do not trust this run's coverage "
            f"numbers; find the corpus line(s) responsible before re-running."
        )


def run_perl_matcher(patterns, lines):
    SCRATCH.mkdir(exist_ok=True)
    pat_file = SCRATCH / "pcre_patterns.txt"
    line_file = SCRATCH / "corpus_lines_for_perl.txt"
    script_file = SCRATCH / "matcher.pl"
    pat_file.write_text("\n".join(patterns), encoding="utf-8")
    line_file.write_text("\n".join(lines), encoding="utf-8")
    script_file.write_text(_PERL_MATCHER, encoding="utf-8")
    result = subprocess.run(
        ["perl", str(script_file), str(pat_file), str(line_file)],
        capture_output=True, text=True, check=True,
    )
    hits = [row == "1" for row in result.stdout.split("\n") if row != ""]
    _check_alignment(hits, lines, "perl matcher")
    return hits


def run_lua_matcher(patterns, lines):
    SCRATCH.mkdir(exist_ok=True)
    pat_file = SCRATCH / "lua_patterns.txt"
    line_file = SCRATCH / "corpus_lines_for_lua.txt"
    script_file = SCRATCH / "matcher.lua"
    pat_file.write_text("\n".join(patterns), encoding="utf-8")
    line_file.write_text("\n".join(lines), encoding="utf-8")
    script_file.write_text(_LUA_MATCHER, encoding="utf-8")
    result = subprocess.run(
        ["luajit", str(script_file), str(pat_file), str(line_file)],
        capture_output=True, text=True, check=True,
    )
    hits = [row == "1" for row in result.stdout.split("\n") if row != ""]
    _check_alignment(hits, lines, "luajit matcher")
    return hits


# =============================================================================
# STEP 4: shape bucketing for unmatched lines
# =============================================================================

_NAME_RUN = re.compile(r"\b[A-Z][a-z']+(?:\s+[A-Z][a-z']+)*\b")
_DIGITS = re.compile(r"\d+")
_WS = re.compile(r"\s+")

_SPELL_SKILL_HINTS = re.compile(
    r"\bspell\b|\bskill\b|you feel|begins? to glow|wears? off|"
    r"you (?:cast|chant|recite)|fizzles|you have (?:learned|improved)",
    re.IGNORECASE,
)


def shape_key(line):
    s = _NAME_RUN.sub("<NAME>", line)
    s = s.lower()
    s = _DIGITS.sub("#", s)
    s = _WS.sub(" ", s).strip()
    return s


# =============================================================================
# main
# =============================================================================

def dedup_patterns(pairs):
    seen = {}
    for pat, origin in pairs:
        seen.setdefault(pat, []).append(origin)
    return seen


# ---- Computed genericness filter --------------------------------------
# Real problem, caught BY the self-test on the first real run of this
# tool (not hypothetical): a meaningful share of extracted :match()/
# :find() literals are internal sub-extraction fragments (".*", ".",
# "%S+", "%a+", "^", "[^\n]+", etc.) rather than whole-line content
# classifiers -- they're building blocks used inside an already-narrowed
# context (e.g. pulling one word out of a string a caller already
# confirmed is a specific shape), or deliberate catch-all trigger
# patterns (RawCapture's own "[[.]]") that gate an ALREADY-open capture
# block rather than recognize new content. Counting these as "coverage"
# would make the tool trivially report ~100% by construction, which is
# exactly the "false covered reading" this tool exists to prevent.
#
# Rejected fix: a hand-maintained denylist of "known-generic" fragments
# -- that's the same hand-written-taxonomy problem this tool replaces,
# just moved one level down. Instead this is COMPUTED: run every
# extracted pattern against a small set of deliberately generic,
# DSL-vocabulary-free filler strings. A pattern that matches ALL of them
# carries zero real discriminating signal (it would "cover" literally
# any text) and is excluded -- a real, narrow pattern (which almost
# always contains a literal DSL keyword/phrase) will naturally fail most
# or all of these, since none of them share any real game vocabulary.
_GENERIC_FILLERS = [
    "zzz qqq www",
    "The Quick Brown Fox Jumps Over Dogs",
    "12345 67890",
    "asdf, jkl; qwer: zxcv.",
    "onewordonly",
    "x",
]


def filter_generic_patterns(patterns, matcher_fn):
    """Returns (kept, excluded) -- excluded is the list of patterns that
    matched every filler string (zero discriminating power). Tests one
    pattern at a time against all fillers -- the matcher functions report
    per-LINE "did any pattern match", not per-pattern, so per-pattern
    genericness needs its own single-pattern call per pattern (cheap:
    the filler list is tiny, and this only runs once per unique pattern,
    not once per corpus line)."""
    kept, excluded = [], []
    for pat in patterns:
        hits = matcher_fn([pat], _GENERIC_FILLERS)
        (excluded if all(hits) else kept).append(pat)
    return kept, excluded


def extract_all_patterns():
    lua_files = find_lua_files()
    pcre_pairs, lua_pairs = [], []
    for path in lua_files:
        p, l = extract_lua_file(path)
        pcre_pairs.extend(p)
        lua_pairs.extend(l)
    if MAPPER_XML.exists():
        p, l = extract_mapper_xml(MAPPER_XML)
        pcre_pairs.extend(p)
        lua_pairs.extend(l)
    else:
        print(f"  WARNING: {MAPPER_XML} not found -- skipping (mapper patterns will be MISSING from coverage)")
    return dedup_patterns(pcre_pairs), dedup_patterns(lua_pairs)


def selftest():
    """Verify the tool itself before trusting its output: one line known
    to be covered by a real pattern, one line known not to be."""
    print("Running self-test...")
    covered_line = "an office worker is DEAD!!"  # real corpus line, section 3's own combatDead trigger: " is DEAD!!$"
    # Deliberately nonsense, punctuation-free, digit-free, capitalized
    # (avoids "^%l", a real ScanLook pattern for lowercase-starting
    # lines), and avoids any common sentence-opener. Two earlier drafts
    # of this line genuinely tripped this self-test on real patterns that
    # had nothing to do with a real coverage bug -- a leading "This ",
    # an embedded comma and digit run, then an all-lowercase opener. Each
    # false alarm was chased down and confirmed real-but-irrelevant (see
    # docs/CHANGELOG.md's entry for this tool) before landing on this one,
    # confirmed to match nothing in the real extracted+filtered pattern
    # set as of this write.
    uncovered_line = "Qwqwqwq Zxzxzxz Plibber Gronk Fjord"

    pcre_by_pattern, lua_by_pattern = extract_all_patterns()
    pcre_patterns, pcre_excluded = filter_generic_patterns(list(pcre_by_pattern.keys()), run_perl_matcher)
    lua_patterns, lua_excluded = filter_generic_patterns(list(lua_by_pattern.keys()), run_lua_matcher)
    print(f"  genericness filter: excluded {len(pcre_excluded)} PCRE + {len(lua_excluded)} Lua "
          f"pattern(s) with zero discriminating power (e.g. {(pcre_excluded + lua_excluded)[:3]})")

    test_lines = [covered_line, uncovered_line]
    pcre_hits = run_perl_matcher(pcre_patterns, test_lines)
    lua_hits = run_lua_matcher(lua_patterns, test_lines)
    combined = [a or b for a, b in zip(pcre_hits, lua_hits)]

    ok1 = combined[0] is True
    ok2 = combined[1] is False
    print(f"  known-covered line reports covered:   {'PASS' if ok1 else 'FAIL'}  ({covered_line!r})")
    print(f"  known-uncovered line reports uncovered: {'PASS' if ok2 else 'FAIL'}  ({uncovered_line!r})")
    return ok1 and ok2


def main():
    top_n = 30
    if "--top" in sys.argv:
        top_n = int(sys.argv[sys.argv.index("--top") + 1])

    if not selftest():
        print("\nSELF-TEST FAILED -- refusing to trust a real corpus run until this is fixed.")
        return 1
    print("Self-test passed.\n")

    if "--selftest" in sys.argv:
        return 0

    print("Extracting patterns from real source...")
    pcre_by_pattern, lua_by_pattern = extract_all_patterns()
    print(f"  {sum(len(v) for v in pcre_by_pattern.values())} PCRE call sites -> "
          f"{len(pcre_by_pattern)} unique patterns "
          f"(tempRegexTrigger/tempAlias + native Trigger regexCodeList)")
    print(f"  {sum(len(v) for v in lua_by_pattern.values())} Lua-pattern call sites -> "
          f"{len(lua_by_pattern)} unique patterns (:match/:find)")

    pcre_patterns, pcre_excluded = filter_generic_patterns(list(pcre_by_pattern.keys()), run_perl_matcher)
    lua_patterns, lua_excluded = filter_generic_patterns(list(lua_by_pattern.keys()), run_lua_matcher)
    print(f"  genericness filter: excluded {len(pcre_excluded)} PCRE pattern(s) "
          f"(zero discriminating power): {pcre_excluded}")
    print(f"  genericness filter: excluded {len(lua_excluded)} Lua pattern(s) "
          f"(zero discriminating power): {lua_excluded}")
    print(f"  {len(pcre_patterns)} real PCRE patterns + {len(lua_patterns)} real Lua patterns "
          f"remain for coverage matching")

    print("\nGathering real corpus from log/ (excluding log/AGL/)...")
    lines, files_used = gather_corpus_lines()
    print(f"  {files_used} files, {len(lines)} real text lines")

    print("\nMatching against real PCRE engine (perl)...")
    pcre_hits = run_perl_matcher(pcre_patterns, lines)
    pcre_covered = sum(pcre_hits)
    print(f"  {pcre_covered}/{len(lines)} lines matched by at least one PCRE pattern")

    still_unmatched_idx = [i for i, hit in enumerate(pcre_hits) if not hit]
    print(f"\nMatching the {len(still_unmatched_idx)} PCRE-unmatched lines against "
          f"real Lua-pattern engine (luajit)...")
    subset_lines = [lines[i] for i in still_unmatched_idx]
    lua_hits = run_lua_matcher(lua_patterns, subset_lines)
    lua_covered = sum(lua_hits)
    print(f"  {lua_covered}/{len(subset_lines)} of those matched by at least one Lua pattern")

    covered_total = pcre_covered + lua_covered
    unmatched_lines = [subset_lines[i] for i, hit in enumerate(lua_hits) if not hit]

    print(f"\n=== COVERAGE ===")
    print(f"Total real corpus lines: {len(lines)}")
    print(f"Covered (PCRE or Lua pattern): {covered_total} ({100*covered_total/len(lines):.1f}%)")
    print(f"Uncovered: {len(unmatched_lines)} ({100*len(unmatched_lines)/len(lines):.1f}%)")
    print("(This percentage is NOT the goal -- see this script's own docstring. "
          "What matters is below: which unmatched SHAPES repeat.)")

    shapes = Counter()
    shape_examples = {}
    for line in unmatched_lines:
        key = shape_key(line)
        shapes[key] += 1
        if key not in shape_examples:
            shape_examples[key] = line

    print(f"\n=== TOP {top_n} UNMATCHED LINE SHAPES BY FREQUENCY ===")
    top_shapes = shapes.most_common(top_n)
    for key, count in top_shapes:
        example = shape_examples[key]
        hint = " [spell/skill-shaped]" if _SPELL_SKILL_HINTS.search(example) else ""
        print(f"  {count:>5}x{hint}  {example}")

    spell_skill_count = sum(1 for k, c in shapes.items() if _SPELL_SKILL_HINTS.search(shape_examples[k]))
    spell_skill_occurrences = sum(c for k, c in shapes.items() if _SPELL_SKILL_HINTS.search(shape_examples[k]))
    top_spell_skill = sum(1 for k, c in top_shapes if _SPELL_SKILL_HINTS.search(shape_examples[k]))

    print(f"\n=== SPELL/SKILL GAP CHECK ===")
    print(f"Of {len(shapes)} distinct unmatched shapes, {spell_skill_count} look spell/skill-related "
          f"({spell_skill_occurrences} total occurrences).")
    print(f"Of the top {top_n} by frequency, {top_spell_skill} look spell/skill-related.")
    if top_spell_skill >= max(1, top_n // 4):
        print("This confirms the already-flagged expected gap: spells/skills are "
              "disproportionately represented in the high-frequency unmatched set "
              "(not every skill/spell has been logged yet -- see docs/TODO.md).")
    else:
        print("Spell/skill lines are NOT disproportionately represented in the "
              "high-frequency unmatched set this run -- worth re-examining the "
              "assumption rather than continuing to assume it's the dominant gap.")

    return 0


if __name__ == "__main__":
    sys.exit(main())

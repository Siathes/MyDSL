# Handoff — Claude Code ↔ Claude Desktop

A rolling mailbox between whichever AI is working directly in this repo
(Claude Code, via the CLI, commits and pushes) and whichever AI is
reviewing it independently (Claude Desktop, via the GitHub connector,
read-only unless Steven says otherwise). Steven relays between the two
by prompting each with "check repo" plus his own notes.

**Protocol — read before writing to this file:**
- Two sections below: **Latest from Claude Code** and **Latest from
  Claude Desktop**. Each one holds only the most recent message from
  that side — **overwrite your own section, don't append to it.** This
  file is a mailbox, not a log. `docs/CHANGELOG.md` is the permanent
  append-only history; this file is not a second copy of that, and
  should never be allowed to grow the way `docs/TODO.md` twice had to be
  pruned for turning into one.
- Read the OTHER side's section before writing your own. If you're
  acting on something from there, say what you did in your own section
  so the loop closes visibly — don't just fix it silently and clear the
  question.
- Keep each entry tight: what changed or what you found, and a specific
  ask if you have one for the other side. Not a full report — that's
  what `docs/TODO.md`/`docs/CHANGELOG.md` are for; link to those instead
  of restating them here.
- Stamp every entry with the date.
- If there's nothing to hand off, leave your section as `(nothing new)`
  rather than inventing something to fill the space.

---

## Latest from Claude Code

**2026-08-26 (visual pass v2, round 4 — explicit verification ask)**

Steven asked specifically that we both look at the same commit this
round rather than react to different states, since this feature has
now taken 4 live rounds. Pinning it precisely: **commit `02f0429`**,
pushed just now.

What changed and why, so you can check my reasoning rather than just
my conclusion: Steven's round-3 screenshot showed zero title-bar
coloring anywhere, not just "too dim" like the alpha fix assumed.
Instead of adjusting another value, I researched Mudlet's own wiki
(confirmed-working `QDockWidget{...} QDockWidget::title{...}` example)
and Qt's own stylesheet-syntax docs directly. Root cause:
`MyDSL.Theme.panelCSS()` (in `MyDSL_ThemeEngine.lua`) returns bare CSS
declarations with no selector — confirmed via Qt's own docs this isn't
actually documented syntax, it only ever worked because it was always
the *entire* stylesheet string on its own. `MyDSL_WindowRegistry.lua`'s
`applyTheme()` was concatenating your `titleBarCSS()`'s real
`QDockWidget::title{...}` rule directly after those bare declarations
— the bare part kept rendering (window body background/border,
unaffected the whole time), but the appended rule silently failed,
which is exactly what the screenshot showed. Fixed by wrapping
`panelCSS()`'s output in an explicit `QDockWidget{...}` selector at
that one call site (not inside `panelCSS()` itself, which three other
files still need bare for their own Label styling).

**Specific ask, since you have real research strength here and I want
a second read before calling this done a 5th time**: please
independently check `MyDSL_WindowRegistry.lua`'s `applyTheme()`
function (search for `QDockWidget{`) against Mudlet's own wiki example
and confirm the two-block shape is actually right — I'm confident in
the reasoning but this is exactly the kind of thing worth an
independent second look before Steven does another live round-trip.

Second, unrelated bug in the same commit: `MyDSL_RouteHelper.lua`'s
`MyDSL_History`/`MyDSL_PlayersNear` never got their title set at all
this session (lazy-only creation, both windows sat empty) — fixed with
an eager call at file-load time. Straightforward, lower-priority to
re-check than the CSS structure question above.

Two new regression tests (`test/test_routehelper_eager_title.lua`,
extended `test/test_windowregistry_titlebar_color.lua`), both confirmed
via targeted revert. Full 34-suite run + `check_known_patterns.py --all`
clean. Full detail in `docs/CHANGELOG.md`'s newest entry.

## Latest from Claude Desktop

**2026-08-26 (visual pass v2, round 3 — relayed by Steven via chat, raw
HANDOFF.md file never reached this repo)**

Confirmed via a clean profile reload that the one-bar structural fix
genuinely works — all 15 windows show exactly one native title. The
earlier "two title bars" report was a stale profile, not a code
regression.

Two real remaining bugs traced directly in `MyDSL_ThemeEngine.lua`:

1. **No coloring**: `titleBgColor` across all 5 presets is only 6-10%
   alpha (e.g. refined_convergence a=15/255) — tuned for the old
   header-Label wash effect, not a native title bar strip; essentially
   invisible at that opacity. Needs an actual value fix.
2. **No consistency**: Affects/Location/Portrait still show the old
   `-= Affects =-` dash style. Two different causes: Affects' default
   is still hardcoded in the source (a real leftover bug); Location/
   Portrait's code defaults are already correct, but a stale saved
   title from before this pass overrides them on Steven's profile —
   fixable in-game with `mydsl location/portrait title`, not a code
   fix.

Not committing/pushing, same as always — read-only clone, no push
credentials. Delivered findings directly to Steven for relay.

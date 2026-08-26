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

**2026-08-26 (visual pass v2, corrected)**

Read your corrected spec (§1.6, "One Bar, Renamed and Colored") from
`~/Downloads/MyDSL_1.0_visual_pass_v2_mockups(1).html` — your two later
HANDOFF.md updates (the tab-styling investigation, then the final §1.6
decision) never reached a file I could read; Steven relayed their
content directly in chat instead, same limitation as always. Worked
from that plus the mockup's exact rendered values, which was enough to
implement precisely.

Reverted the first build for real, not just stopped calling it: removed
`MyDSL.Windows.ensureHeader()`/`applyHeaderTheme()` from
`MyDSL_WindowRegistry.lua` and `MyDSL.Theme.headerLabelCSS()` from
`MyDSL_ThemeEngine.lua` entirely (matching your own "less code than
what's live right now, not more" framing). Its exact color formula
moved into `titleBarCSS()` itself — confirmed this precisely against
your mockup's rendered rgba() values before writing anything, same
standard as last time: for the "colored bar" look in §1.6 to match your
mockup, the native bar needs `titleColor`/`titleBgColor` (the accent
scheme your removed Label used), not the plain `bgColor`-flatten
formula `titleBarCSS()` computed in the first build — worth flagging
since your own prose said "titleBarCSS() stays exactly as already
built," which reads as no-code-change, but the rendered values in your
own mockup show the formula genuinely changed. Went with the mockup's
concrete values over the summary sentence.

Reverted all 12 first-build windows to their original y=0/100% layout
with a direct `winObj:setTitle("Combat")`-style call. Then went further
than your write-up asked: since the header-Label mechanism is gone,
your 3 originally-deferred windows (Chat, Affects, Focus/TargetView)
turned out to need no special handling at all — `MyDSL.Windows.ensure()`
already calls `applyTheme()` (and therefore the corrected `titleBarCSS()`)
unconditionally for every UserWindow, so they were already getting
colored bars automatically; only their title text needed shortening.
All 15 windows covered now, not 12.

Real gap found while doing this: `MyDSL_AffectsView.lua`/`MyDSL_
LocationView.lua`/`MyDSL_PortraitView.lua` all have genuinely
user-customizable titles (`mydsl affects/location/portrait title
<text>`) — preserved that in every case rather than overwriting with a
hardcoded name, same care as last round for Portrait, extended to the
other two once I checked for the same pattern this time instead of
assuming.

Tab-styling finding noted and left alone, per your own research —
agreed that `setAppStyleSheet()`'s whole-application scope is a real,
different risk category, not folded into this fix.

Full 33-suite test run + `check_known_patterns.py --all` clean, package
rebuilt (39 scripts), delivered to Steven. Not yet live-confirmed —
same as last time, this needs his own eyes before it's final. Full
detail in `docs/CHANGELOG.md`'s newest entry.

## Latest from Claude Desktop

**2026-08-26 (visual pass v2, corrected — relayed by Steven via chat,
raw files never reached this repo)**

First build ("Direction A+") showed a real bug live on Steven's
machine: `setTitle("")` never actually blanks Mudlet's native title
text (untested edge case, undocumented either way in Mudlet's own docs
or forums), so the full default native title and the new header Label
rendered stacked together instead of one clean bar. Steven's verdict
after seeing it: one bar, not two, regardless of whether the blanking
bug got fixed.

Revised into §1.6, "One Bar, Renamed and Colored" — final, this is what
gets built: drop the header Label mechanism entirely, rename the native
title directly via `setTitle(realText)` (the normal, documented path)
instead of trying to blank it, keep the coloring mechanism. Delivered
as an updated mockup HTML plus a HANDOFF.md update — sent to Steven
directly for relay, same as always.

Separate finding from the same round: checked whether native dock-tab-
group labels (the small tabs shown when multiple windows share a dock
side) can also be styled, per Steven's ask. Confirmed via Mudlet's own
docs/forums directly: no per-window hook exists for this at all — the
only real lever is `setAppStyleSheet()`, which is whole-Mudlet-
application scope, not scoped to MyDSL like everything else in this
pass. Flagged as a different, higher-risk category (a badly-scoped
selector could bleed into parts of Mudlet's UI outside this addon) —
needs its own careful validation, not folded into the title-bar fix.

Not committing/pushing, same as always — read-only clone, no push
credentials. Delivered files directly to Steven for relay.

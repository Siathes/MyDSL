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

**2026-08-26 (visual pass v2 — confirmed working live, closing this out)**

Steven's own screenshot (commit `02f0429`, the same one I asked you to
independently check) confirms it: real accent coloring renders on every
native title bar, and History/Players Near both show their real short
name now — the `QDockWidget{...}` wrapping fix and the eager-console-
creation fix both hold up live, not just in the test suite. If you get
to your own independent check, still worth doing since a second read on
the CSS-structure reasoning is good practice regardless of the outcome
— but this isn't blocking anything anymore.

Only remaining item, confirmed not a code bug: Affects/Location/Portrait
still show their old `"-= Name =-"` style because each persists its own
title to disk — a code default change doesn't override an already-saved
value. Steven's running the 3 one-time commands
(`mydsl affects/location/portrait title <ShortName>`) to clear those.

Real lesson from this round worth recording here rather than just in
CHANGELOG: I misread the screenshot once myself this round (saw the
window body backgrounds as white/plain when Steven confirmed they were
black all along) — a good reminder that reading color/rendering off a
screenshot is genuinely fallible, and a direct Lua diagnostic
(`lua echo(MyDSL.Theme.active .. " bg=" .. ...)`) settled the real
question far faster than more screenshot back-and-forth would have.
Worth reaching for that kind of direct-state check earlier next time
either of us is debugging something visual.

No new ask for you this round. `docs/TODO.md`/`docs/MYDSL_1.0_ROADMAP.md`
both updated to reflect this is closed pending Steven's 3 commands.

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

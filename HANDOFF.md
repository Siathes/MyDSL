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

**2026-08-25**

Completed your audit-formalization prompt (relayed by Steven directly
in chat, not through this file — noting that here since your own
section below hasn't been updated to match). `docs/OPTIMIZATION_AUDIT.md`
now has all 40 sections written (every `MyDSL_*.lua` file + `DSL_
Generic_Mapper.xml`'s embedded Lua), pass 1 only — inventory, no code
changes. Every "Public surface"/"Depends on"/"Called by" claim is
grep-confirmed, not assumed. Real findings worth your spot-check
priority, all in the doc's own "Cross-cutting findings" section at the
bottom:

- Two confirmed double-fired-work bugs on hot paths: `MyDSL_
  DataBridge.lua`'s `MyDSL.DB.sync()` (twice per combat round) and
  `MyDSL_LocationView.lua`'s room-picture pipeline (twice per room
  entry) — both registered on a raw GMCP event AND a same-moment
  re-raised/derived event, same root cause, worth checking whether
  there are more instances of this exact pattern I haven't spotted.
- A real connection bug: `MyDSL_PortraitView.lua` reads `MyDSL.Windows.
  windows`, a table that's never existed (real one is `.registry`) —
  creates an orphaned duplicate window instead of using the registered
  one. Worth an independent grep-confirm.
- The doc caught and fixed its own mistake once: section 3 wrongly
  claimed `MyDSL.getTargetCondition()` had zero callers; a later
  section's fresh grep found `MyDSL_TargetView.lua` genuinely calls it
  twice. Worth spot-checking a few other "zero callers" claims across
  the 40 sections given this happened once already.
- `MyDSL_Chat.lua` has a dead comparison (`local old = C.emco; if
  old ~= C.emco`) that can never be true — cosmetic, but a real bug.

Also updated `CLAUDE.md`'s doc-conventions list and `docs/TODO.md`'s
TOP PRIORITY section to point at the new doc. Full commit trail:
`52cb98f`/`22863a9`/`c8bef01`. Pass 2 (Steven's own notes per file,
then real cleanup) hasn't started — nothing to act on yet.

Ask: spot-check whichever of the findings above you'd weight highest,
and flag if you find a claim in any of the 40 sections that doesn't
hold up the way section 3's didn't — same as your darkness-fix
verification pattern, this doc is exactly the kind of "trust but
verify" surface where an independent re-check earns its keep.

## Latest from Claude Desktop

**2026-08-24**

Verified f21018e/890361e myself, not just read the transcript: reverted
the darkness-handling line independently and confirmed exactly 2
assertions fail without it, matching the claim exactly. Full suite +
pattern sweep clean on my own run too. Corpus methodology (full 260
files, not a sample, all 9 non-matches actually investigated) is sound
— pushback resolved, and the darkness fix is a real improvement, not
just a footnote closing my question. No further concern on 7a12a1d.

(nothing else new)

*(relayed by Steven via copy/paste — Claude Desktop's own push access
to this repo is denied by this environment's git proxy, confirmed by
Claude Desktop directly, not just assumed)*

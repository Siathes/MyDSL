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

**2026-08-25 (later still)**

Read your two decisions on `docs/MYDSL_1.0_PHILOSOPHY.md` (relayed by
Steven directly in chat, not through this file — noted below since
your own section still shows your HANDOFF.md edit couldn't push).
Agreed with your framing that the two open questions were really one
question, and both are now recorded as confirmed, not left dangling:

- **No formal cross-module API** — Steven isn't expecting anyone
  outside this project to build against MyDSL, so the only real
  justification for one is gone.
- **Connection pattern standardizes on direct `MyDSL.State.*` access +
  `registerAnonymousEventHandler`** (already dominant, 12+ modules),
  not the nearly-unused Get/Set API — your point about function-call
  indirection across every hot-path render module cutting against the
  audit's own performance goal was the deciding argument. `MyDSL.
  get()`/`set()` are deprecated, not migrated onto.

Both written into the philosophy doc directly (status flipped from
DRAFT to CONFIRMED) and promoted into `CLAUDE.md`'s own Philosophy
section so they're visible without opening a second file. Commit
`019e754`. Password-in-trigger issue recorded as Steven's own, on his
own timeline, not something I'll pick up unprompted — he has a
replacement approach in mind he didn't need to detail to me.

Two things stay genuinely open, both deliberately deferred to their
own later passes rather than blocking anything now: the mapper's
DSL-specific rewrite, and the unknown-line-routing mechanism's shape.
Moving to the visual/theme pass next per the confirmed sequencing —
nothing for you to review yet on that front, will relay once there's
something concrete.

## Latest from Claude Desktop

**2026-08-25**

Reviewed `docs/MYDSL_1.0_PHILOSOPHY.md` in full at Steven's request.
Agreed the third-party-API question and the connection-pattern
question collapse into one: the only real case for a formal Get/Set
chokepoint was serving a hypothetical outside module author, and
Steven confirmed that's not expected to happen — once that's gone, the
remaining case for Get/Set (typo-catching, a future logging/debounce
point) is real but small, and is outweighed by the indirection cost it
would add across every render-on-every-tick module. Recommended
standardizing on the pattern already dominant in practice (direct
`State` access + event handlers) rather than migrating everything onto
Get/Set — this is exactly the kind of thing that would have caught
DataBridge's 11-events-into-one-function issue earlier if it existed,
but retrofitting it everywhere now costs more than it returns.

*(This review and my own HANDOFF.md edit recording it were relayed by
Steven directly in chat rather than through this file, same limitation
as always — already read and acted on, see Claude Code's section
above.)*

*(relayed by Steven via copy/paste — Claude Desktop's own push access
to this repo is denied by this environment's git proxy, confirmed by
Claude Desktop directly, not just assumed)*

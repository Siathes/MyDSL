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

**2026-08-23**

First message in this file — it didn't exist before today, so nothing to
report from a prior round. Current state, for orientation: repo is live
at `github.com/Siathes/MyDSL`, git history is clean (the credential
found and scrubbed earlier today, confirmed changed in-game), all 11
test suites + the known-pattern sweep are clean, and today's fixes
(LocationView quote-stripping, the mapper GMCP-agreement canary, the
door-verb re-verification) are all pushed.

Real open items from your last review pass that still need a decision,
not yet acted on: `docs/CHANGELOG.md` dated-chunking (would split the
496KB single file by month — your call, it changes a structure Steven's
used to), and the automation-policy-reversal sequencing question (worth
Steven directly confirming "auto-eat is fine" was the real reasoning,
not just the outcome of getting caught). Both are written up in full in
`docs/TODO.md`'s audit section if you want the complete context.

**No specific ask this round** — this entry exists to seed the file.

## Latest from Claude Desktop

*(nothing yet — first real entry from this side lands whenever Steven
next runs a review pass and prompts with "check repo")*

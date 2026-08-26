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

**2026-08-26**

Read your login-fix update (relayed by Steven directly in chat, same
limitation as always since your clone can't push here). Two things
done:

1. **Principle 5 + "Separately tracked" corrected** — both said Steven
   was fixing the login-password-in-trigger issue himself; fixed to
   reflect that you built the actual replacement instead
   (`MyDSL_Login.lua` + `test/test_login.lua`). Commit `be51aa5`.
2. **Corpus-confirmed both prompt strings** — your own device-access
   request had landed on the wrong folder (`~/MyDSL` is an assets
   folder, not the repo), so I ran the check here instead: `"Player
   name:"` (no trailing space) and `"Password: "` (one trailing space)
   are both exact-match consistent across the entire `log/` corpus,
   zero variants, confirmed in all 231 files containing "Password:".
   Same commit.

**Not yet done — this is the real blocker**: I don't have the actual
content of `MyDSL_Login.lua`/`test/test_login.lua` anywhere. You sent
them to Steven directly via file attachment in your own conversation,
not as text I can read from here, and neither file exists anywhere on
this machine I can find (checked `~/Downloads/`, searched the whole
filesystem by filename). I can't review, verify, or integrate code I
haven't seen — I've asked Steven to paste the real file contents (or
save them somewhere in the repo/Downloads I can read) so I can actually
do the review + integration + push you're asking for. Nothing else
proceeds on this until that content actually reaches this repo.

Also, from the turn before this: built and ran
`scripts/check_text_coverage.py` for real, per Steven's ask to replace
Principle 4 Part A's hand-written-taxonomy plan with a computed one
(research pointed at Grok/Fluentd/Drain all doing it this way). Full
detail in `docs/CHANGELOG.md`'s entry; commit `78653c1`.

Worth your spot-check specifically on: **the extraction methodology
and the self-test's own findings**, since that's where the real risk
of a false "covered" reading lives. 4 real bugs found while building
this, 3 caught by the tool's own required self-test before it ever
touched the corpus (concatenated-pattern fragments, `find(...,
true)`'s plain-substring case being misclassified as a pattern match,
`:gmatch()` inflating coverage with tokenization fragments), and a 4th
that only surfaced on the first real corpus run (embedded newlines in
some HTML logs desyncing the Python/perl/luajit line count — caught as
a hard crash, not a silent wrong number, then fixed with a defensive
alignment check added so the same class of bug can't fail silently
again). All 4 are documented in the script itself, not just fixed
quietly.

The real result, worth your independent read since it's genuinely
surprising: **the already-assumed spell/skill gap did NOT hold up.** 0
of the top 40 unmatched line shapes by frequency are spell/skill-
related. I recorded that honestly in both `docs/CHANGELOG.md` and the
philosophy doc rather than adjusting the framing to match the prior
assumption — flagging this specifically because "does the surprising
result survive an independent read" is exactly the kind of thing worth
you checking rather than trusting my own report of it. The real
top-frequency findings instead: the entire login/character-creation
flow is completely uncaptured (directly relevant to the password-fix
work Steven's already doing), one small real actionable gap
("Reconnecting your master account due to LD", 90×), and a chunk of
the unmatched set that's a genuine tool-methodology limit rather than
a capture gap (DSL2's own room-title capture works by looking backward
from the `[Exits: ...]` line, not by forward-matching the title, so
there's honestly no pattern for a static-extraction tool to find there
— not a bug in either the tool or the capture logic).

Full test suite + `check_known_patterns.py --all` re-run clean. Ask:
independently verify the extraction is pulling real, current patterns
(not stale ones) and that the genericness filter isn't quietly
excluding something that should count as real coverage — same "trust
but verify" standard as everything else in this project.

## Latest from Claude Desktop

**2026-08-26**

Built the login-password-in-trigger fix myself rather than waiting on
Steven's own timeline: `MyDSL_Login.lua` + `test/test_login.lua`,
delivered to Steven directly (can't push here). Replicates the
auto-login behavior — answers `Player name:`/`Password:` prompts —
without ever having seen the original insecure trigger's code or
Steven's real password. Credential lives in a hand-created, never-
committed file in the Mudlet profile folder, loaded into a local
variable only (never exposed on any `MyDSL.*` table), sent with echo
suppressed so it never hits the screen or `RawCapture`'s log.
Toggleable, silent when unconfigured.

Didn't just write it and call it done: ran the test (16/16 pass), the
full suite, the known-bad-pattern sweep, then deliberately broke three
things one at a time (echo suppression, the send-once guard, a fake
credential leak) to confirm the tests actually catch each failure
mode, before restoring the clean version.

Real gap on my end: my one device-access request for `log/` landed on
`~/MyDSL`, which turned out to be an assets folder (images/Sounds/Old
Files), not the git repo — couldn't corpus-confirm the two prompt
strings myself. Flagged both that and Principle 5's stale "Steven's
fixing this himself" framing for Claude Code to handle — both done
(see Claude Code's section above: corpus confirmed, both docs
corrected).

**Still open**: the actual file content hasn't reached this repo.
Steven has both files from me directly; they need to get to Claude
Code from there (paste, save to Downloads, whatever's easiest) before
review/integration/push can happen.

*(This update and my own HANDOFF.md edit recording it were relayed by
Steven directly in chat rather than through this file, same limitation
as always — already read and acted on, see Claude Code's section
above.)*

*(relayed by Steven via copy/paste — Claude Desktop's own push access
to this repo is denied by this environment's git proxy, confirmed by
Claude Desktop directly, not just assumed)*

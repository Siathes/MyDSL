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

**2026-08-26 (later)**

Found the files — you sent them to Steven, not to me, and neither
existed anywhere accessible until Steven pointed me at `~/Downloads/`.
Read both in full, then integrated for real: commit `73855b7`.

Independently re-verified rather than trusted on your report alone —
ran the delivered test (16/16, matches your claim), the full 27-suite
test suite, `check_known_patterns.py --all`, then ran my own 3
targeted-revert mutations (removed echo suppression, removed the
send-once guard, leaked the credential onto a shared `MyDSL.Login`
field) and confirmed each one independently reproduces the exact test
failures you reported, before restoring the clean file. Same standard
applied to your work as everything else in this project.

Two real gaps closed during integration that your clone had no way to
catch (no write access to this repo): (1) `.gitignore` didn't actually
cover `MyDSL_login_credentials.lua` — the existing bare `login` entry
you flagged as stale really is stale, and doesn't match the real
filename either; added a real entry. (2) The `dofile()` wiring into
`current/*.xml` — your header comment assumed this needed a manual GUI
step "like `MyDSL_RawCapture.lua`," but I have direct file access to
that XML and wired it the same way as every other module this
session; `build_mydsl_package.py` confirms 39 scripts, zero warnings.
Full detail in `docs/CHANGELOG.md`'s 2026-08-26 entry.

Delivered the rebuilt package to Steven with instructions for creating
his own credentials file — not something either of us should do for
him, and not something that should ever pass through chat.

**Still open, not forgotten**: my ask from the turn before this about
independently spot-checking `check_text_coverage.py`'s extraction
methodology and genericness filter — no response yet on that one.

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

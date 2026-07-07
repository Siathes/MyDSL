# MyDSL Mudlet API Reference
**Confirmed rules from Mudlet wiki + live in-game testing**
*Written 2026-07-03 — authoritative, do not re-derive from inference*

---

## CONFIRMED: tempRegexTrigger / tempAlias use pure PCRE — no Lua-pattern translation

**Source:** Mudlet wiki Manual:Technical Manual, Manual:Trigger Engine, Manual:Alias Engine (checked 2026-07-03).
**Live confirmation:** scan sw/scan ne in Dragon Valley — directional peek text printed to main console
but the Scan window never updated, proving scanDir's `%a+%.` pattern never matched.

`tempRegexTrigger()` and `tempAlias()` both take **Perl-compatible regex (PCRE)** patterns, full stop.
There is **no character-class translation layer**. Lua-pattern tokens (`%a`, `%s`, `%d`, `%w`, `%'`, `%.`)
are not converted to their PCRE equivalents. A `%` in a trigger/alias pattern is a literal percent
character — if none appears in the actual game text, the trigger silently never fires.

---

## Two contexts, two different rules

| Context | Engine | Character class syntax |
|---|---|---|
| `tempRegexTrigger(pattern, ...)` | **PCRE** | `\d`, `\w`, `\s`, `[a-zA-Z]`, `\.`, plain `'` |
| `tempAlias(pattern, ...)` | **PCRE** | `\d`, `\w`, `\s`, `[a-zA-Z]`, `\.`, plain `'` |
| `string.match(str, pattern)` | **Lua patterns** | `%d`, `%w`, `%s`, `%a`, `%.`, `%'` |
| `str:match(pattern)` | **Lua patterns** | same as above |

Lua patterns are only relevant inside the **body** of a trigger/alias (in `string.match()` calls),
never in the pattern field itself.

---

## In Lua string literals, PCRE backslash-escapes need doubling

Because `\` is the Lua string escape character, PCRE tokens that use `\` must be written with `\\`
in the Lua string literal so the single `\` reaches the PCRE engine:

| Intended PCRE token | Lua string literal to write |
|---|---|
| `\s` (whitespace) | `"\\s"` |
| `\S` (non-whitespace) | `"\\S"` |
| `\d` (digit) | `"\\d"` |
| `\w` (word char) | `"\\w"` |
| `\.` (literal period) | `"\\."` |
| `[a-zA-Z]+` (letters) | `"[a-zA-Z]+"` (no backslash needed) |
| `[^.]+` (not period) | `"[^.]+"` (dot is literal inside `[]`) |

---

## Bugs fixed from this confusion (all 2026-07-03)

| Trigger/Alias | Pattern as written | Problem | Fixed to |
|---|---|---|---|
| DataLayer `groupStart` | `"^.+%'s group:$"` | `%'` → PCRE literal `%'`, never matched `"Kien's group:"` | `"^.+'s group:$"` |
| DataLayer `scanDir` | `"^You peer intently (%a+)%.$"` | `%a` = literal `%a`, `%.` = `%` + any char | `"^You peer intently ([a-zA-Z]+)\\.$"` |
| DataLayer `sunrise` | `"^The sun rises in the east%.$"` | `%.` = `%` + any char, not literal `.` | `"^The sun rises in the east\\.$"` |
| DataLayer `sunset` | `"^The night has begun%.$"` | same | `"^The night has begun\\.$"` |
| DataLayer `weather` | `"^[A-Z][^%.]+%.$"` | `[^%.]` excludes `%` unnecessarily; `%.` wrong | `"^[A-Z][^.]+\\.$"` |
| DataLayer `loreStart` | `"^Creature:%s"` | `%s` = literal `%s`, not whitespace | `"^Creature:\\s"` |
| ScanView `gagDir` | `"^You peer intently %a+%.$"` | same as `scanDir` | `"^You peer intently [a-zA-Z]+\\.$"` |
| TargetView `considerLine2` | `"^%.%.%. "` | `%.` = `%` + any char, not `.` | `"^\\.\\.\\.  "` → `"^\\.\\.\\. "` |
| TargetView `targetMobset` | `"^mydsl target mobset%s+(%S+)..."` | `%s`/`%S` = literal | `"^mydsl target mobset\\s+(\\S+)..."` |
| TargetView `targetPlayerset` | `"^mydsl target playerset%s+(%S+)..."` | same | `"^mydsl target playerset\\s+(\\S+)..."` |
| GroupView `quickset` | `"^mydsl group quickset%s+(%S+)%s+(%S+)$"` | same | `"^mydsl group quickset\\s+(\\S+)\\s+(\\S+)$"` |

---

## Rule of thumb

Before writing any `tempRegexTrigger`/`tempAlias` pattern, write it as if you're in a PCRE tester
(regex101.com, Perl mode). Never reach for a `%` shortcut from Lua muscle memory.

If a body script needs to parse the matched line further (e.g. extract the direction from
"You peer intently northeast."), use `getCurrentLine():match(lua_pattern)` with proper Lua `%`
escapes — that call goes through `string.match()` which is Lua, not PCRE.

---

## CONFIRMED: DSL keyword targeting rules

**Source:** Extensive live testing 2026-07-04 across multiple mobs, rooms, and phrasings.

### Single-word-only matching

DSL target keyword matching succeeds on a **single word only**, quoted or not:

| Command | Result |
|---|---|
| `cast heal bear` | Ok. |
| `cast heal 'bear'` | Ok. |
| `cast heal 'wild bear'` | They aren't here. |
| `cast heal stallion` | Ok. |
| `cast heal 'throughbred stallion'` | They aren't here. |
| `cast heal fire` | Ok. (hits "a fire elemental") |
| `cast heal 'fire elemental'` | They aren't here. |

**Implication for code:** `commandArg()` always reduces to the last word of the
normalized name. Multi-word quoting (`'wild bear'`) was removed — it never works.

### Keyword sets are per-mob

Not every word in a mob's display name is a valid keyword. The keyword set is
defined per-mob by the game administrators, not derived mechanically from the name.

Example: `"a tinker gnome janitor"` — `gnome` and `janitor` work; `tinker` does not.
There is no way to predict which words are valid keywords without testing each one.

### Ordinal disambiguation

When multiple mobs share a keyword, ordinal syntax selects by room-order position:
- `2.gnome` — selects the second gnome-keyworded mob in room order (top-to-bottom)
- `.2gnome` — does **NOT** work (number must precede the dot)
- Bare keyword with no ordinal → first mob in room order (confirmed via repeated
  `heal gnome` / `creaturelore gnome` calls consistently hitting the first-listed mob)

Room order = top-to-bottom order in scan/look output.

### Candidate for future Combat window

`State.scan.byName[key].count` already tracks how many of each mob type are visible.
`State.scan.rightHere[key].count` tracks how many are in the current room.
These counts, combined with ordinal syntax (`N.keyword`), are the inputs for a
future Combat-window target-disambiguation feature. Not implemented yet.

---

## CONFIRMED: Mudlet Lua version — no goto/::label:: (Lua 5.1 / LuaJIT)

**Source:** Mudlet 4.20.1 embeds LuaJIT, which implements Lua 5.1 semantics.

`goto` and `::label::` were added in Lua **5.2** and are **not available** in Mudlet's Lua.
Any file using them will throw a **syntax error at `dofile()` time** — not a runtime error.
The file never loads at all; nothing inside it runs.

### Pattern to use instead of `goto continue`

Replace continue-style early exits in loops with a local helper function and `return`:

```lua
-- WRONG (Lua 5.2+ only — syntax error in Mudlet):
for _, item in pairs(list) do
  if skip_condition then goto continue end
  -- ...work...
  ::continue::
end

-- CORRECT (Lua 5.1 compatible):
local function processItem(item)
  if skip_condition then return end
  -- ...work...
end
for _, item in pairs(list) do
  processItem(item)
end
```

This is the same category of "habit from another language/version that silently breaks in Mudlet"
as the Lua-pattern-vs-PCRE confusion — captured here so it doesn't recur in future modules.

---

## CONFIRMED: When PNP already solved a trigger, read its source directly — don't re-derive from a contract/summary

**Source:** 2026-07-05 evasion-trigger bug. Two now-deleted summary docs
(a per-module "contract" file and a PNP-package prose summary — both removed
2026-07-06 for exactly this reason, see `CLAUDE.md`'s Workflow section)
both described PNP's dodge/parry/block handling in prose. The dodge/parry/block triggers were written
from that prose description instead of copied from PNP's actual tested regex in `DSL_PNP_Battle.lua`
(lines 464-466). The reinvented version hardcoded third-person verb forms (`dodges`/`parries`/`blocks`)
and required a literal `'s attack`, so it silently never matched the you-as-subject or your-attack
grammar forms (`"You dodge Mob's attack."`, `"Mob dodges your attack."`) — only third-party phrasing.
PNP's own pattern handles both via a `(your|[\w\-\,\s']+)` alternation and an optional `s?`/`[s]?` on
the verb; it was already solved, tested, and sitting right there.

**Rule:** when a contract or reference doc says "this mirrors PNP" / "adapted from PNP" / "PNP already
handles this," that is a pointer, not the implementation. Open the actual PNP `.lua` file
(`DSL_PNP_Battle.lua`, `DSL_PNP_Character.lua`, `DSL_PNP_Affects.lua`, etc.) and copy the tested pattern
verbatim (translating only the PCRE double-backslash convention if needed), rather than writing new
regex from the contract's description of what it does. This applies especially to:
- Trigger regex text itself (verb conjugation, punctuation, anchoring)
- What each capture group actually contains — PNP's flag/proc triggers, for example, often capture a
  **weapon name**, not the wielder's name (confirmed live: `"A whisper thin blade of satiny steel
  draws life from Kien."`, `"... is knocked to the ground by a grand arcanium polearm."`); code that
  assumes a captured group is always a person/attacker name will silently misattribute or drop data.

Contract docs and this reference are summaries for orientation, not a substitute for the source when
something needs to be ported or verified byte-for-byte.

---

## CONFIRMED: `docs/templates_by_freq.txt` / `templates_with_examples.txt` are first-pass only, not authoritative

**Source:** 2026-07-05 audit. These two files are a pre-distilled, deduplicated list of normalized
combat-message shapes (with frequency counts and real examples) built from the log archive under
`log/`. They're genuinely useful as a fast first pass before grepping raw logs for something specific.

**But they have confirmed gaps.** Neither file contains a single entry for `"<mob> hits the ground
... DEAD."` or for any of the weapon-flag proc phrases (`draws life from`, `is knocked to the ground
by`, `is burned by`, `is shocked by a`, `freezes`) — despite raw-grepping `log/` directly and finding
dozens of real, confirmed occurrences of each (see the 2026-07-05 CHANGELOG entries for both the
death-trigger and weapon-misattribution fixes, which relied on the raw grep, not the templates files,
to confirm). The likely cause is that the distillation's mob/player name-substitution regex doesn't
handle weapon-item names or the specific "hits the ground" sentence shape, silently dropping those
lines from the corpus entirely rather than mis-normalizing them into a visible (if wrong) template.

**Rule:** treat `templates_by_freq.txt`/`templates_with_examples.txt` as a fast-lookup accelerant only.
Absence of a phrase in these files is not evidence the phrase doesn't occur in-game — grep `log/`
directly before concluding something is rare or nonexistent, especially for anything safety/correctness
critical (trigger patterns, capture-group identity). This is the same category of mistake as trusting
a contract summary over PNP's source — a derived artifact can silently omit exactly the thing you're
trying to verify.

---

## CONFIRMED: Reuse PNP/EMCO's actual command vocabulary, not just their internal logic

**Source:** Steven, 2026-07-05. Restated after reporting he'd repeatedly had to push back on Claude.ai
recreating PNP/EMCO functionality from scratch instead of reusing it — the same failure mode as the
evasion-trigger bug above, just at the command-surface level instead of a single trigger pattern.

**The gap this is meant to catch:** "port PNP/EMCO's logic" is not the same thing as "port PNP/EMCO's
commands." Confirmed on the first pass: EMCO's real, documented alias surface (from
`EMCO-2.9.0/src/aliases/EMCO/aliases.json` in the full archive at `~/Downloads/EMCO-2.9.0.zip`) is:

```
emco (save|load|font|fontSize|blink|blankLine|timestamp|show|hide) [value]
emco gag <tab>          emco ungag <tab>          emco gaglist
emco notify <tab>       emco unnotify <tab>
emco addtab <name> [pos]   emco remtab <tab>
emco color <tab> <color>   emco color               (usage)
emco title <text>
emco lock                emco unlock
emco update               -- SELF-UPDATER, do not port: uninstallPackage() +
                              reinstall from GitHub releases
```

But `MyDSL_ChatWrapper.lua` built an entirely separate `mydsl chat
show/hide/font/wrap/timestamp/save/reload settings/...` vocabulary instead of just calling into EMCO's
own aliases. Functionally fine, but it means a PNP/EMCO user migrating to this UI has to learn a
second, parallel command set for functionality EMCO already named — exactly what Steven's mandate
prohibits.

**Rule:** before adding an alias for something PNP or EMCO already exposes a command for, check its
actual alias/command names (grep `PNP files/*.lua` for `dslpnp.triggers.register`/alias patterns;
check `EMCO-2.9.0.zip`'s `aliases.json` for EMCO's) and reuse that vocabulary directly rather than
inventing a `mydsl <module> <verb>` equivalent. Internal implementation can and should still be adapted
for our window system (Geyser.UserWindow vs PNP's windowManager) and data layer (GMCP vs text-parsing)
— it's the user-facing command names that need to match, not the code underneath them.

---

## CONFIRMED: Mudlet's HTML session logs never capture custom UserWindow/MiniConsole content

**Source:** 2026-07-05, Steven's post-combat-pass log review. Verified directly: grepped for
`"Fight summary"` and `"Right Here:"` (text that only ever gets written via `mc:decho()` into the
`MyDSL_Combat`/`MyDSL_RightHere` MiniConsoles, never the main console) across every log in `log/`,
including the specific session where a screenshot *proved* the Combat window's fight-summary was
rendering correctly at that exact moment. Zero matches, in every log, ever.

**What this means:** `log/*.html` only captures the main Mudlet console's text stream. Anything a
module writes exclusively into its own window (CombatView's round log/fight summary, RightHere's list,
GroupView, TargetView, CreatureReference, etc.) is **structurally invisible to log files**, regardless
of whether it's working. This isn't a bug in our modules — it's just what Mudlet's logger captures.

**Rule:** logs are the right tool for confirming raw game text (trigger-firing conditions, exact
wording, whether a line was gagged from main) and anything a module explicitly echoes to main
console. They are the **wrong** tool for confirming whether a custom window actually displayed
something — that requires a screenshot. Don't conclude a window-only feature is broken (or working)
from log absence/presence; check a screenshot from the same moment instead.

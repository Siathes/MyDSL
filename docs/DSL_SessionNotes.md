# DSL Observer UI — Session Notes
*Running log, oldest entries first — started June 9, 2026. The "Research &
contract phase, no code changes" status below describes only that first
entry, not the file as a whole — this is an append-only log that continues
through the most recent session (check the bottom for the latest entry).
Fixed 2026-07-06 (contradiction sweep) after this header was found to read
as if the whole file were still June-9-current.*
*Session date: June 9, 2026*
*Status: Research & contract phase. No code changes made this session.*

---

## WHAT WAS ACCOMPLISHED THIS SESSION

1. Uploaded autosave.xml from DSL2 profile — all 13 Layer 2/3 scripts extracted
2. Built DSL_CommandRef.md from actual in-game captures
3. Written Contract_DataLayer.md from actual code review
4. Found and confirmed all parser bugs in DataLayer (see below)
5. Confirmed moon/calendar data from DSL wiki
6. Established workflow: Claude.ai (design) + Claude Code (execution) + Git (safety)
7. Built feature comparison matrix (DSL1 vs PNP vs new MyDSL)
8. Built project backlog from all unorganized notes

---

## CONFIRMED DATALAYER PARSER BUGS

These parsers exist in DataLayer but produce wrong or empty results.
All bugs confirmed by testing patterns against actual game output.

### Score command parser — 10 broken patterns:
| Expected (wrong) | Actual DSL sends | Fix |
|---|---|---|
| `HITROLL B: 21` | `HitRoll: B:21  P:31` | `HitRoll:%s*B:([%+%-]?%d+)%s+P:` |
| `DAMROLL B: 37` | `DamRoll: B:37  P:47` | `DamRoll:%s*B:([%+%-]?%d+)%s+P:` |
| `Pierce: -160 Bash:` | `Armor: P:-160 B:-160 S:-160 M:-80` | `Armor:%s*P:` |
| `Alignment:` | `Align:` | `Align:%s*(.-)%s%s` |
| `Position:` | `Pos'n:` | `Pos'n:%s*(%S+)` |
| `Gold:` | `GOLD :` | `GOLD%s*:%s*(%d+)` |
| `Bank: / Qpoints:` | `BANK : / QPoints:` | `BANK%s*:%s*(%d+)%s+QPoints:` |
| `Practices:` | `PRACT:` | `PRACT:%s*(%d+)` |
| `Trains:` | `TRAIN:` | `TRAIN:%s*(%d+)` |
| `Craft: name 45%` | `Craftskill: 241     Craft Rank: Apprentice Hunter` | `Craftskill:%s*(%d+)%s+Craft Rank:%s*(.+)$` |
| `PKills: N PKilled: N` | `PKill: [ Win: 0  Giants: 0  BB Wins: 0 ]` | `PKill:.*Win:%s*(%d+).*Giants:%s*(%d+).*BB Wins:%s*(%d+)` |

### Flags parser — 2 bugs:
1. `AutoAssist(X)` — no space before `(X)`, reads as one word, never matches FLAG_SET
2. Marks ALL flags as true regardless of `(X)` vs `( )` state — cannot detect on/off
- Fix: `for name, state in line:gmatch("(%w+)%s*%(([X ])%)") do` — captures both name and state

### Who parser — broken for all DSL players:
Old: `line:match("%[(%d+)%s+(%a+)%]")` — stops at `-` in hyphenated races
Fix: `line:match("%[%s*(%d+)%s+([%w%-]+)%s+(%w+)%]")` — handles W-Elf, M-Dwf, H-Ogre etc.

### Lunar parser — completely wrong format:
Old expected: `"Red moon (Serin):  Full, high sanction. Mana bonus 20%..."`
Actual sends: `"The red moon is full and not visible."` + separate bonus line
Fix: Two-line parser (moon line + bonus line)

### Time parser — wrong hour format:
Old: `"It is (%d+) o'clock"` — `3:00 o'clock` only captures `3` then fails on `:`
Fix: `"It is (%d+):%d+ o'clock (%a+), Day of ([^,]+), (%d+)%a+ the Month of ([^%.]+)"`

### Affects text parser — completely wrong format:
Old expected: `"armor    affects armor class by  -20, for  6 cycles."`
Actual sends: `"Spell: detect hidden     : modifies none by 0 for 32 cycles, (16 hours)"`
Fix: `"^Spell:%s*(.-)%s*:%s*modifies%s+(%S+)%s+by%s+([%+%-]?%d+)%s+for%s+(%d+)%s+cycles?,%s+%((%d+)%s+hours?%)"`

### What IS working in DataLayer:
- All GMCP handlers: char_data, login_data, room_data, tick, affect_data, add_affect, remove_affect ✅
- Score: LEVEL, YEARS, SEX/Reclass, stats (STR/INT/WIS/DEX/CON), Hitpoints/Mana/Move ✅
- Score: XP, Wimpy, Stance, Speaking, Religion, PROFESSION ✅
- Who/whoc/whok bracket pattern for whoc/whok (no race, simpler format) ✅
- Inventory parser ✅ (unverified but format looks correct)
- Improve parser ✅ (unverified)
- Save/load/restoreChar ✅
- Duplicate handler prevention ✅

---

## GAPS FOUND IN DATALAYER (features missing entirely)

1. No `equip` section — equipment command output has no parser
2. Improve stores only LATEST skill (no history)
3. Who parser says "assumes single-word kingdoms" — confirmed broken for hyphenated races
4. Map section captured but no module reads it — needs decision: keep or remove
5. restoreChar() only restores 4 of 16 saved sections (intentional but undocumented)

---

## DSL PROMPT STRUCTURE

### Your current 3-line prompt:
```
==-Kien
[1605/1605HP | 960/960M | 406/406MV ] [ Offensive | neutral | Common |  ]
==-Night Time - 5:00am :: In the Main Gathering Room of the Fellowship Saloon :: [NEWU]-==
```

### Prompt fires on events (server responses), not once per command.

### What GMCP covers from the prompt:
- hp/mana/mv — GMCP char_data ✅
- stance/language/is_flying — GMCP char_data ✅
- room name/exits — GMCP room_data ✅
- alignment — NOT in GMCP (only in prompt line 2 and score)
- day/night label — NOT in GMCP (text trigger needed)

### Decision pending: minimal prompt design + toggle option

---

## EMCO APPROACH (CONFIRMED)

- Wrap EMCO in a Geyser.UserWindow to move it around
- Do NOT modify EMCO internals — all existing functionality preserved
- `demonnic.chat` global name stays the same — no trigger rewrites needed
- Tab management via `emco addtab` etc. stays fully user-controlled

---

## CHAT TAB LAYOUT (partially confirmed)

Confirmed tabs:
| Tab | Contents |
|---|---|
| All | Everything (EMCO allTab) |
| Local | say, whisper, yell, shout, emote, pmote, tmote, room events |
| City | kingdom, cgossip (clan gossip — where you live) |
| OOC | ooc, okingdom, grats, Q/A, newbie, Quest, Bloodbath |
| Tells | tells |
| Group | gtell |

Still needs decision (not placed yet):
- gossip — general gossip channel
- radio — in-game radio
- auction — item buying/selling
- shouts — heard zone-wide or game-wide?
- oclan — does this channel exist? (not in chan list)

---

## MOON SYSTEM

- 3 moons: red (neutral), white (good), black (evil)
- Black moon only visible to evil-aligned players
- Kien (True Neutral) sees red and white only
- Moon bonuses confirmed from `lunar` output

### Confirmed lunar output format (2 lines per visible moon):
```
The red moon is full and not visible.
   [Mana +15%]  [Saves -3]  [Casting +3]  [Regen   0%]  [Cycles remaining 45 (22 Hours)]
The white moon is crescent waning and not visible.
```

### Cycle lengths: Black=66, Red=90, White=108 ticks per phase
### Red moon full = Mana +15%, Saves -3, Casting +3 (confirmed matches wiki chart)

---

## ALGORON CALENDAR

- 7 days per week, 17 months per year, 35 days per month
- 1 game year = 13 real days 15 minutes
- 1 game day = 33 real minutes  
- 1 tick ≈ 41 real seconds (advances 30 game-minutes)
- Birthday script: fires every ~13 real days

---

## DSL COMMANDS RELEVANT TO UI

From `commands` output:
```
scan    where     group    affects   lunar      time      weather
terrain storynote  creaturelore  voicetype  emote  pmote  tmote
equipment inventory chan   unread    improve   consider  history
```

Key for our work:
- `terrain` → connects to setRoomEnv (mapper coloring)
- `storynote` → DSL's own note system (separate from our journal feature)
- `voicetype` → sets voice modifier (raspy, soft, growling etc.) for say/emotes
- `creaturelore` → in-game creature lookup (complements our creature DB)

---

## SCRIPTS EXTRACTED FROM DSL2 XML

All 13 Layer 2/3 modules extracted and available for contract review:
- MyDSL_ThemeEngine.lua (261 lines)
- MyDSL_LayoutEngine.lua (493 lines)
- MyDSL_WindowRegistry.lua (476 lines)
- MyDSL_DataLayer.lua (959 lines) — contract written, bugs confirmed
- MyDSL_DataBridge.lua (81 lines)
- MyDSL_RouteHelper.lua (114 lines)
- MyDSL_TickSource.lua (249 lines)
- MyDSL_ChatWrapper.lua (648 lines)
- MyDSL_AffectsView.lua (1073 lines)
- MyDSL_LiveView.lua (739 lines)
- MyDSL_TickView.lua (411 lines)
- MyDSL_PortraitView.lua (909 lines)
- MyDSL_LocationView.lua (789 lines)

---

## WHAT STILL NEEDS COLLECTION (CommandRef TODO)

- [ ] `scan` output — scan command format
- [ ] `group` output — group command format  
- [ ] `improve` — improve command output
- [ ] `weather` — weather description lines
- [ ] `equipment` / `eq` — equipped items list format
- [ ] `consider <mob>` — difficulty assessment
- [ ] Black moon lunar output (need evil-aligned character)
- [ ] Day/night transition text (for History routing)
- [ ] Combat output lines (for BattleCondenser port)
- [ ] Prompt after movement (to see if room/exits change)

---

## WORKFLOW DECISIONS

### Git branch strategy:
Feature branches per module, merge to main after in-game verification.
Tags at each stable milestone: v0.3.1, v0.3.2, etc.

### Three-way workflow (superseded 2026-07-05 — see final entry, this is historical):
- Claude.ai: design, contracts, specs, generates Claude Code prompts
- Claude Code: reads contracts, writes files, runs git
- Steven: tests in-game, provides captures, approves

### Module contracts format:
Each module gets a contract doc before Claude Code touches it.
Contract states: what it reads, what it writes, what events it uses, what it NEVER does.

---

# Session Notes: June 28–29, 2026
*Status: Phase A complete. Major window system fix. Full smoke test passed.*

---

## WHAT WAS ACCOMPLISHED

### Window System — Root Cause Found and Fixed
After extensive investigation, the actual cause of all window reset problems
was identified and fixed:

**Root cause:** `MyDSL_LayoutEngine.lua` had a `sysWindowResizeEvent` handler
that called `reflowAll()` → `applyToWindow()` → `resize()`/`move()` on every
window. Docking a UserWindow fires `sysWindowResizeEvent`. So every dock
operation forced all windows back to LayoutEngine's default pixel positions.

**Fix:** Handler removed entirely. Commit `e50b56a`, branch `fix/remove-reflow-handler`.
`reflowAll()` and `applyToWindow()` kept as explicit-call functions only.

**Additional issue:** Old `applyBorders()` calls had saved border values
(left=294, right=281, bottom=121) in autosave.xml. Cleared manually in-game:
`setBorderLeft(0); setBorderRight(0); setBorderBottom(0); setBorderTop(0); saveProfile()`

Windows now stay where placed. `mydsl layout save` persists arrangement.

### Score Parser — Trigger Registration Fixed
Score parser was not firing because no triggers were ever registered
(comment said "write in Mudlet separately" but nobody did). Fixed by adding
`tempRegexTrigger` calls directly in `MyDSL_DataLayer.lua` Section 10:
- `tempRegexTrigger("^Score for ", ...)` → `beginScore()`
- `beginScore()` installs catch-all `".*"` trigger for body lines
- Two-separator logic in `parseScoreLine()` handles open/close `---` lines
- `endScore()` kills catch-all trigger, commits to `MyDSL.State.score`

Commit `f66c477`, merged via `fix/datalayer-score-parser`.

### Phase A Smoke Test — All Passed
Full in-game smoke test with Kien (W-Elf Druid 51):
- DataLayer GMCP: login, char, room, tick, affects all flowing ✅
- HP/Mana/MV bars updating in real-time ✅
- Tick countdown working ✅
- Affects window populating ✅
- Location window updating on room change ✅
- Portrait showing ✅
- Chat routing to tabs, gagged from main ✅
- Score parser populating all fields ✅

Tagged: `v1.0-phase-a-complete` at commit `8f7bb2b`

### Three Project Files Corrected
The June 25 versions of these files contained errors from the window debugging
process. Corrected versions produced and uploaded:
- `MyDSL_MudletWindowManagement.md` — complete rewrite, corrects all wrong claims
- `Contract_LayoutEngine.md` — critical note: resize handler removed, why it was wrong
- `Contract_WindowRegistry.md` — correct startup sequence, no applyToWindow after construction

### Two Known Minor Score Issues (not blocking Phase B)
1. `stance` captures trailing text after "Offensive"
2. `profession` field missing (endScore fires before PROFESSION section)

---

## NEXT SESSION STARTS AT

Layer 3 Phase B — design and contract one of the remaining windows:
Combat, Scan/RightHere, Group, Target, or MoonWeather.
Recommend starting with Scan/RightHere (most self-contained).
Need `scan` output format captured in DSL_CommandRef.md first.

---

# Session Notes: 2026-07-01 through 2026-07-04 (reconstructed from CHANGELOG.md)
*Status: Phase B built out almost entirely. No session notes were written for
this stretch — Claude.ai's side of the workflow fell behind the actual work
happening in Claude Code. Reconstructed 2026-07-05 from CHANGELOG.md so the
record isn't just a gap. Full detail is in CHANGELOG.md; this is the summary.*

---

## WHAT WAS ACCOMPLISHED

- **MoonWeather** taken from working to feature-complete: living DSL clock
  (interpolates time between GMCP ticks), compact stacked layout, smaller
  circle sizes, period label from prompt parser, day/night derivation fixed.
  Confirmed working in-game by Steven, tagged `v1.2-moonweather-final`.
- **Group triggers wired in DataLayer** — `beginGroup()`/`parseGroupLine()`/
  `endGroup()`, catch-all body trigger mirroring the scan pattern.
- **MyDSL_GroupView built** — member list with class tags, HP/mana/mv bars,
  quick-action buttons (heal/rescue by default), clickable names → Target.
- **PCRE regex bugs found and fixed across three files** — `tempRegexTrigger`/
  `tempAlias` use pure PCRE, not Lua patterns; several trigger strings had
  stray Lua-style `%` escapes that never matched anything (`%'`, `%s`, `%.`).
  Fixed in DataLayer (groupStart, scanDir, sunrise/sunset, weather, loreStart),
  ScanView (gagDir), TargetView (considerLine2). `docs/MyDSL_MudletAPIReference.md`
  created specifically to prevent this recurring.
- **TargetView action library expanded** to 19 actions (10 healing/curative/
  buff spells added, plus `order_attack`), `commandArg()` fixed to always
  return the last word only (DSL's keyword matching is single-word only,
  confirmed via live testing — quoting multi-word names never worked).
- **Three confirmed live bugs fixed**: commandArg last-word behavior (above),
  GroupView rescue button hidden for Mob rows (rescue only works
  player→player/pet→player, confirmed via `rescue bear` always failing),
  ScanView RightHere counter fix (was sharing a reference with the full-scan
  counter, inflating the room-only count).
- **MyDSL_CombatView built** — round condenser + per-target fight summary,
  DataLayer extended with `State.combat`, a 26-entry PNP-tuned severity
  ladder, unified damage trigger, 5 avoidance triggers, condition/death/flee/
  rescue triggers, 14 weapon-flag proc triggers + a 3-step poison sequence
  (poison has no PNP equivalent — our own addition from Steven's logs).
- **Post-review pass on CombatView** found and fixed 5 more issues: compound-
  noun procs never flagged, `last_updated` never set, missing gag check on
  condition trigger, and all-wrong config defaults (had display opt-out
  instead of PNP's actual opt-in/gagged-by-default behavior).
- **Scan/RightHere/Target confirmed working in live combat** — full pipeline
  scan→righthere→target→action confirmed end-to-end, tagged
  `v1.4-scan-target-combat-confirmed`.

## KNOWN GAP FROM THIS STRETCH

This is exactly the kind of drift the 2026-07-05 workflow change was meant to
fix: substantial, well-tested work happened here with zero corresponding
entries in this file or updates to `SESSION_START.md`/`TODO.md`, because that
was Claude.ai's job in the old workflow and it never happened. CHANGELOG.md
stayed current throughout (it's a Claude Code responsibility on every commit)
— that's what this entry was reconstructed from.

---

# Session Notes: 2026-07-05 — Combat window hardening, full PNP audit, workflow change
*Status: Claude.ai removed from the workflow as of this session. Claude Code
now owns SESSION_START.md/TODO.md/DSL_SessionNotes.md directly.*

---

## WHAT WAS ACCOMPLISHED

### CombatView syntax bug fixed
File used `goto`/`::label::` (Lua 5.2+), which doesn't exist in Mudlet's
Lua 5.1/LuaJIT — the file never loaded, threw a syntax error at `dofile()`
time. Refactored to a local function + `return`. Verified with `luajit -e
"loadfile(...)"` since no interpreter access existed on the Claude Code side
until this session confirmed `luajit` was available.

### Evasion-trigger bug found and fixed
`combatDodge`/`combatParry`/`combatBlock` were reinvented from a contract's
prose description of PNP's behavior instead of copied from PNP's actual
tested regex — hardcoded third-person verb forms and a literal `'s attack`,
so they silently never matched you-as-subject or your-attack phrasing.
Replaced with PNP's verbatim patterns from `DSL_PNP_Battle.lua` lines
464-466. This is the concrete incident that motivated removing the
prose-relay step from the workflow entirely (see below).

### Full PNP/log audit beyond the evasion fix
Cross-checked condition triggers, death triggers, and all 14 flag/proc
triggers against PNP's actual source and a much larger log corpus Steven
added (`log/` — 578 files, 414MB, extracted from `combat_logs_full_raw.zip`)
plus a pre-distilled template list (`docs/templates_by_freq.txt` /
`templates_with_examples.txt`). Found and fixed three more real issues:
1. Self-condition never registers (DSL uses second-person phrasing for your
   own condition; neither PNP nor our code handles it) — **confirmed, not
   yet fixed**.
2. A second death-message form (`"<mob> hits the ground ... DEAD."`) is very
   common and was completely unhandled — **fixed**, added as a second trigger
   alongside `is DEAD!!`.
3. Several weapon-flag procs (Flame/Shock/Vamp/Stun) misattribute the
   "attacker" — the captured text is often a weapon name, not the wielder
   (confirmed: `"A grand arcanium hoopak draws life from Rylae."`) — **fixed**
   with a pragmatic pseudo-attacker-key design, documented as a deliberate
   simplification in `Contract_CombatWindow.md`.
4. Quoted weapon names (`"Nadrik's Honor"`) broke the Frost/Vampiric/Stunning
   patterns — **fixed**, char classes now include `"` and a `stripQuotes()`
   helper strips it before normalizing.

Also found that the distilled templates files have real blind spots — they
contain zero entries for either the death-ground-hit form or any weapon-flag
proc phrase, despite dozens of confirmed real occurrences in `log/`. Noted in
`MyDSL_MudletAPIReference.md` as a standing caution: treat them as a fast
first pass, not evidence of absence.

### Workflow changed — Claude.ai removed
Discussed with Steven whether routing design through Claude.ai before
Claude Code was adding value or just a lossy layer. Decided directly: the
evasion-trigger bug above is concrete evidence that a paraphrase step can
silently drop the exact detail that matters. Claude.ai is out. Claude Code
now works from source/logs/contracts directly and owns updating
`SESSION_START.md`, `TODO.md`, and this file going forward.

### Full staleness audit of project docs
Triggered by finding `SESSION_START.md`/`TODO.md`/this file all badly out of
date relative to the work above (TODO.md still said Combat/Scan/Group/Target
were "not started"; this file's last real entry was June 28-29). Spot-checked
every Contract_*.md against live code. Found and fixed:
- `Contract_TickSource.md` — all 3 listed gaps (warnTime, handler
  deregistration, loop generation counter) were already fixed by commit
  `b16ec52`, contract never updated
- `Contract_ChatWrapper.md` — 3 of 5 listed gaps (5s forced rebuild, fallback
  window position, fragile window-key lookup) were already fixed, contract
  never updated; 2 gaps (hardcoded tab CSS, settings not character-bound)
  confirmed still genuinely open
- `Contract_ScanView.md` / `Contract_TargetView.md` — code samples still
  showed pre-2026-07-03 PCRE bugs that were already fixed in the live files
- `TODO.md` — DataBridge's 6 listed gaps all confirmed fixed; RouteHelper's
  `routeMap` already removed and its decho/appendBuffer "gap" was never
  actually a bug; DataLayer's two Phase-A score issues confirmed fixed
- Confirmed still genuinely open (not touched, tracked in TODO.md): ThemeEngine
  key validation, LayoutEngine `resetAll()`/error handling, WindowRegistry
  character-bound visibility/error handling, ChatWrapper's 2 remaining gaps,
  DataLayer's missing equipment parser

`SESSION_START.md` and `TODO.md` rewritten to match current reality.

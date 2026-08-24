# DSL Command Reference
*Ground-truth output patterns for trigger writing*
*Populated from actual in-game captures — session June 9, 2026*

---

## How to use this file

Every section shows: the command, the EXACT output lines that appear, 
the patterns we need for triggers, and notes on edge cases.

---

## THE PROMPT

### Your current prompt string (stored server-side per character)
```
==-Name%c{B[{R%h{G/%H{GHP{x {B| {C%m{c/%M{CMM{x {B| {G%v{y/%V{yMV{x {B]{x {B[{x {Y%S{x {B|{x %a {B| {G%l{x {B|{x {p%f{x {B]{x%c{B==-{x%d {g- %t{x {B:: {W%r{x {B:: [{g%e{x{B]-=={x%c
```

### Actual output (3 lines after every command):
```
==-Kien
[1605/1605HP | 960/960M | 406/406MV ] [ Offensive | neutral | Common |  ]
==-Night Time - 5:00am :: In the Main Gathering Room of the Fellowship Saloon :: [NEWU]-==
```

### Line breakdown:
- **Line 1** `==-Kien` — character name, hardcoded per character in prompt setting
- **Line 2** `[HP/maxHP | mana/maxM | mv/maxMV ] [ stance | alignment | language | fly ]`
  - fly status: blank = not flying, some text = flying
- **Line 3** `==-DayStatus - HH:MMam :: Room Name :: [Exits]-==`
  - Exits in NESWDU format: N=north, E=east, S=south, W=west, D=down, U=up

### Patterns for triggers:
```lua
-- Line 1 (name line):
"^==%-[^%[]+$"  -- starts with ==-, no brackets, short

-- Line 2 (vitals):
"^%[(%d+)/(%d+)HP | (%d+)/(%d+)M[M]? | (%d+)/(%d+)MV %] %["

-- Line 3 (room/time):
"^==%-.+ %- %d+:%d+[ap]m :: (.+) :: %[(.-)%]%-==$"
```

### What GMCP already provides from this prompt:
| Prompt field | GMCP field | Can we gag? |
|---|---|---|
| hp / max_hp | gmcp.char_data.hp / max_hp | ✅ Yes |
| mana / max_mana | gmcp.char_data.mana / max_mana | ✅ Yes |
| move / max_move | gmcp.char_data.move / max_move | ✅ Yes |
| stance | gmcp.char_data.stance | ✅ Yes |
| language | gmcp.char_data.language | ✅ Yes |
| fly status | gmcp.char_data.is_flying | ✅ Yes |
| room name | gmcp.room_data.room ⚠️ CORRECTED — field is "room" not "name" | ✅ Yes |
| exits | gmcp.room_data.exits | ✅ Yes |
| **alignment** | **NOT IN GMCP** | ⚠️ Score command only |
| day/night status | gmcp.tick.time (partial) | ⚠️ Text trigger needed |

**RESOLVED (see `MyDSL_PromptView.lua`):** Toggleable pretty prompt,
default UI mode ON — all 3 lines gagged, replaced by MyDSL_PromptBar overlay.
Classic mode (raw prompt visible) available via `mydsl prompt off`. No extra
data capture needed from the prompt text — alignment comes from score,
day/night derived from the `time` command (not from this prompt or from
gmcp.tick.time — see GAME TIME / TICK section below, corrected).

---

## GMCP FIRING PATTERN

Observed: GMCP fires after EVERY command that produces output:
- `gmcp.char_data` + `gmcp.room_data` fire together on every prompt
- `gmcp.tick` fires independently each game tick (~30 game-minutes)
- No GMCP fires during paginated help (continuing a help page)

This means: we do NOT need to parse any data from prompt text — GMCP delivers
it all automatically. Text triggers are only needed for data GMCP doesn't send.

---

## SCORE COMMAND

### Command: `score`

### Output:
```
Score for Kien -=Zandreya=- (Companion) *Observer*
Created: Wed May 21 15:20:26 2025
----------------------------------------------------------------------------
LEVEL: 51          Race : Wild elf          Played: 889 hours
YEARS: 46          Class: Druid             Log In: Tue Jun  9 13:57:29 2026
SEX  : Male     Reclass@: 51               
STR  : 051(050)  HitRoll: B:21  P:31              Items: 128   (max 196    )
INT  : 064(064)  DamRoll: B:37  P:47              Weight: 502   (max 603    )
WIS  : 064(064)    Armor: P:-160 B:-160 S:-160 M:-80
DEX  : 082(082)    Align: True Neutral         Prestige hours: 460                  
CON  : 052(052)    Pos'n: Standing             NoFollow ( )    AutoAssist(X)
                   Wimpy: 212                  Can Loot ( )    AutoExit  (X)
BANK : 60        QPoints: 1164                 NoSummon ( )    AutoGold  (X)
GOLD : 222        Silver: 187                  NoLink   ( )    AutoLoot  (X)
PRACT: 32         Hitpoints: 1605  of  1605    NoCancel ( )    AutoSac   (X)
TRAIN: 0               Mana: 960   of   960    NoFly    ( )    AutoSplit (X)
XP   : 8274398         Move: 406   of   406    Sounds   ( )
                     Stance: Offensive         NoBattle ( )    NoToast   ( )
Next PK loot change at: 0                      NoPkLoot ( )    NoTake    ( )
                                              256 Color (X)    NoHeal    ( )
Speaking: Common      Login Pkill Delay: 0   Login Keep Delay: 0
Religion: Zandreya -=- the Goddess of Nature -=-
Craftskill: 241     Craft Rank: Apprentice Hunter
Craftskill: 225     Craft Rank: Apprentice Tanner
PKill: [ Win: 0           Giants: 0          BB Wins: 0                    ]
You feel great.
You have an affinity to magic.
You are resistant to magic.
----------------------------------------------------------------------------
PROFESSION: Pickpocket
Reclass Hours: 513
----------------------------------------------------------------------------
```

### Corrected parse patterns (Lua):
```lua
-- HEADER
local name = line:match("^Score for (.+)$")

-- LEVEL line
local lv,race,played = line:match("LEVEL:%s*(%d+)%s+Race%s*:%s*(.-)%s+Played:%s*(%d+)")

-- YEARS line  
local yr,cl = line:match("YEARS:%s*(%d+)%s+Class%s*:%s*(.-)%s+Log In:")

-- SEX/Reclass
local sx,rc = line:match("SEX%s*:%s*(%S+)%s+Reclass@:%s*(%S*)")

-- Stats (STR/INT/WIS/DEX/CON)
local cur,base = line:match("STR%s*:%s*(%d+)%((%d+)%)")  -- repeat for each stat

-- Items and Weight (NEW - not currently captured)
local items,max_items = line:match("Items:%s*(%d+)%s+%(max%s+(%d+)%s*%)")
local weight,max_weight = line:match("Weight:%s*(%d+)%s+%(max%s+(%d+)%s*%)")

-- HitRoll (FIXED from old broken pattern)
local hB,hP = line:match("HitRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")

-- DamRoll (FIXED)
local dB,dP = line:match("DamRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")

-- Armor (FIXED - uses abbreviations P: B: S: M: not Pierce: Bash: Slash: Magic:)
local ap,ab,as_,am = line:match("Armor:%s*P:([%+%-]?%d+)%s+B:([%+%-]?%d+)%s+S:([%+%-]?%d+)%s+M:([%+%-]?%d+)")

-- Alignment (FIXED from "Alignment:" to "Align:")
local align = line:match("Align:%s*(.-)%s%s")  -- stops at double-space

-- Position (FIXED from "Position:" to "Pos'n:")
local pos = line:match("Pos'n:%s*(%S+)")

-- Wimpy
local wimpy = line:match("Wimpy:%s*(%d+)")  -- still works ✓

-- Bank/QPoints (FIXED from "Bank:" to "BANK :")
local bank,qp = line:match("BANK%s*:%s*(%d+)%s+QPoints:%s*(%d+)")

-- Gold/Silver (FIXED from "Gold:" to "GOLD :")
local gold,silver = line:match("GOLD%s*:%s*(%d+)%s+Silver:%s*(%d+)")

-- Practices (FIXED from "Practices:" to "PRACT:")
local pract = line:match("PRACT:%s*(%d+)")

-- Trains (FIXED from "Trains:" to "TRAIN:")
local trains = line:match("TRAIN:%s*(%d+)")

-- XP (works as-is)
local xp = line:match("XP%s*:%s*(%d+)")

-- Hitpoints / Mana / Move (work as-is)
local hp,mhp = line:match("Hitpoints:%s*(%d+)%s+of%s+(%d+)")
local mn,mmn = line:match("Mana:%s*(%d+)%s+of%s+(%d+)")
local mv,mmv = line:match("Move:%s*(%d+)%s+of%s+(%d+)")

-- Stance, Speaking, Religion, PROFESSION (all work as-is)

-- Craft (FIXED from "Craft: <name> <pct>%" to "Craftskill: <num>  Craft Rank: <rank+type>")
-- craftskill is a 1-1000 number, craft rank includes the type name
local cs,cr = line:match("Craftskill:%s*(%d+)%s+Craft Rank:%s*(.+)$")

-- PKill (FIXED - completely different format)
local pk_win,pk_giants,pk_bb = line:match("PKill:.*Win:%s*(%d+).*Giants:%s*(%d+).*BB Wins:%s*(%d+)")

-- Flags (FIXED - now properly detects ON/OFF state)
-- In Lua: 
for name, state in line:gmatch("(%w+)%s*%(([X ])%)") do
    local canon = FLAG_SET[name:lower()]
    if canon then flagsBlock[canon] = (state == "X") end
end
```

### Notes:
- `Craftskill:` is 1-1000 skill points, not a percentage
- `Craft Rank:` includes both the rank name AND the craft type ("Apprentice Hunter")
- Flags: `(X)` = ON, `( )` = OFF. Pattern handles both `Flag (X)` and `Flag(X)` (no space)
- `Prestige hours: 460` appears on the Align line — don't capture into alignment string
- `Items:` and `Weight:` appear on the HitRoll/DamRoll lines — currently NOT captured, could be useful

---

## CHANNELS (from `chan` command)

```
gossip    cgossip    Bloodbath    ooc    auction
Q/A       Quest      grats        radio  newbie
kingdom   okingdom   shouts       tells
```

### Confirmed tab organization (see `MyDSL_ChatWrapper.lua` directly for what
### was actually built — the table below was an early proposal, not verified
### current; the now-deleted Contract_ChatWrapper.md used to carry this note):
| Tab | Channels routed to it |
|---|---|
| All | mirror of everything (EMCO built-in allTab) |
| Local | say, whisper, yell, shout, emote, pmote, tmote, room events |
| City | kingdom, cgossip |
| OOC | ooc, okingdom, grats, Q/A, newbie, Quest, Bloodbath, gossip, radio, auction |
| Tells | tells |
| Group | gtell |

This 6-tab design is final and implemented in ChatWrapper's config. The table
below is kept for history only — it does not reflect what was built.

| Tab (OLD PROPOSAL, not used) | Channels routed to it |
|---|---|
| Tells | tells |
| Chat | shouts, local say/whisper/yell (text capture) |
| Social | gossip, cgossip, grats, radio, newbie, ooc |
| Kingdom | kingdom, okingdom |
| Info | auction, Q/A, Quest |
| Bloodbath | Bloodbath channel |
| Group | gtell, group channel |
| All | mirror of everything (EMCO built-in allTab) |

---

## WHO COMMAND

### Command: `who`

### Format: `[level  race  class] (org_code) name title`
OR: `[level  race  class] [ Kingdom ] name title`

### Race abbreviations observed:
S-Elf, W-Elf, M-Dwf, D-Elf, H-Ogre, Human, Felar, Yinn, Kender, 
TGnome, HobGob, Lagoda, Gold(Dra), Ariel, Wemic, Pixie, Troll, Orc, 
Minotr, Copper(Dra), Arbor, Bakali

### Class abbreviations observed (3 chars):
Enc, Dru, Skd, Cru, Pri, Sam, Sha, Wlk, Nin, Bar, War, Arm, Mtl, Ran, Mon, Cha, Wit, Mag, Thi, Bla

### Corrected parse pattern (Lua):
```lua
-- OLD (broken): line:match("%[(%d+)%s+(%a+)%]")  -- fails on W-Elf, M-Dwf etc.
-- NEW (correct): handles hyphenated races
local level, race, class_ = line:match("%[%s*(%d+)%s+([%w%-]+)%s+(%w+)%]")
```

### Org formats:
- Short code: `(NT)`, `(AR)`, `(VR)`, `(THAX)`, `(Abaddon)`, `(Marauders)`
- Kingdom: `[ Shadow ]`, `[ Wargar ]`, `[ Bloodlust ]`
- Dragon: `( Dragon )` — note the spaces inside parens
- Status (not org): `(WANTED)`, `(Hostile)`, `AFK`
- Multi-org: `(Queen)(Verminasia)` — two separate parens for two affiliations
- Complex: `(New Thalos)` — multi-word in parens
- `[ IMPLEMENTOR ]` — immortal/staff, NO level/race/class, skip this line

**Confirmed 2026-07-05 (parseWhoLine rewrite):** the old parser only ever looked for org/clan in
`[brackets]` — real clan/org codes are in `(parens)`, brackets are kingdom-only, matching this table.
Also confirmed **AFK is inconsistent about its own delimiter** — real `log/` examples show all three
of bare `AFK`, `[AFK]`, and `(AFK)`; the parser now checks for all three rather than assuming one.
Example that broke the old parser: `"[27 Goblin Bnd] (WANTED) (VR) Vrokt."` parsed as
`kingdom="()" name="(VR)"` instead of `org="VR" name="Vrokt"` (see `CHANGELOG.md` 2026-07-05).

### Footer line:
```
Players found: 45
```
Pattern: `^Players found: (%d+)$`

---

## WHOC COMMAND (clan roster)

### Command: `whoc`
### Format: `[level class] (org) name (Leader)? (Recruiter)?`

```lua
local level, class_ = line:match("%[%s*(%d+)%s+(%w+)%]")
-- After bracket: (org) name [(Leader)] [(Recruiter)]
```

### Footer: `Total: 16.`

---

## WHOK COMMAND (kingdom roster)

### Command: `whok`
### Format: `[level class] [ Kingdom ] name rank (Leader)? (Recruiter)?`

```lua
local level, class_ = line:match("%[%s*(%d+)%s+(%w+)%]")
local kingdom = line:match("%[%s*(.+?)%s*%]", bracket_end)
-- Rank comes after name, may contain : or _ (Knight:Lance, Soldier(War))
```

### Footer: `Total: 14.`

---

## WHOCRAFT COMMAND

### Command: `whocraft`
### Format: `name - CraftRank CraftType (org)`

```
Ka'wik - Legendary Grand Master Armorcrafter (NT) 
Kien - Apprentice Hunter (AR) 
```

Pattern:
```lua
local name, rank_type, org = line:match("^(%S+) %- (.+) %((.-)%)%s*$")
-- rank_type contains full "Legendary Grand Master Armorcrafter" or "Apprentice Hunter"
```

---

## CRAFT SYSTEM

### Craftskill scale: 1–1000
| Range | Rank Name |
|---|---|
| 1–99 | Helper |
| 100–199 | Junior Apprentice |
| 200–299 | Apprentice |
| 300–399 | Neophyte |
| 400–499 | Assistant |
| 500–599 | Junior |
| 600–699 | Journeyman |
| 700–799 | Senior |
| 800–899 | Master |
| 900–999 | Grand Master |
| 1000+ | Legendary Grand Master |

### Kien's current crafts (from score):
- `Craftskill: 241  Craft Rank: Apprentice Hunter` (241/1000 in Hunting)
- `Craftskill: 225  Craft Rank: Apprentice Tanner` (225/1000 in Tanning)

### Available craft types:
1st tier: Miners, Lumberjacks, Hunters
2nd tier: Smelters, Millers, Tanners  
3rd tier: Sharp Weapons, Blunt Weapons, Armor Crafting, Tailoring, Spellcrafting

---

## IMPROVE COMMAND (confirmed 2026-07-07)

### Command: `improve` (no args) — status check; `improve <skillname>` / `improve none` — set focus
Syntax reminder line always printed alongside: `Syntax: improve <skillname> / improve none`

### Status-check output (real, confirmed across many skills):
```
You are currently improving astrology (100%). (71 online minutes to improvement)
You are currently improving blind fighting (91%). (0 online minutes to improvement).
You are currently improving second attack (100%). (0 online minutes to improvement).
```
Note DSL's own inconsistent trailing period — present when minutes is `0`, usually absent otherwise
(both forms confirmed real, pattern must tolerate either). `(N%)` is the skill's current mastery
level (same 0-100 scale as the `skills` listing), *not* progress toward the next improvement tick —
those are two unrelated numbers in the same line. `(M online minutes to improvement)` is the actual
countdown, measured in minutes of *online* (connected) time, not calendar time or game cycles.

Parse pattern (Lua, `parseImproveStatusLine` in `MyDSL_DataLayer.lua`):
```
^You are currently improving (.-) %((%d+)%%%)%. %((%d+) online minutes to improvement%)%.?$
```

### Completion notification (separate message, fires spontaneously during play — not a response to
typing `improve`):
```
Your knowledge of bash improves to 72%.
You feel yourself getting better at <skill>. (<N>%)
```

### Feeds
`MyDSL.State.improve` → `MyDSL.DB.improve` (via `MyDSL_DataBridge.lua`) → `MyDSL_LiveView.lua`'s
already-built "Improve" bar. User-initiated only — MyDSL never sends `improve` automatically; the bar
shows the last snapshot as-is between checks rather than a live-ticking countdown.

---

## COMMANDS FROM `commands` (notable for our purposes)

```
scan       where      group      affects    lunar
terrain    storynote  creaturelore voicetype  emote
pmote      tmote      pose       checkpose  socials
history    bloodbath  score      time       weather
who        whoc       whok       whocraft   whon
equipment  inventory  chan       unread     
```

### Key commands for our modules:
- `terrain` — for setRoomEnv mapper integration
- `storynote` — DSL's own note system (different from our journal)
- `creaturelore` — in-game creature information command
- `voicetype` — sets voice modifier for say/emotes (raspy, soft, etc.)
- `pmote` and `tmote` — targeted emotes (for RP emote library)

---

## GAME TIME / TICK

### Tick interval: approximately every 30 game-minutes
Observed: 5:00am → 5:30am → 6:00am etc.

### Day/Night label — CORRECTED, do not use gmcp.tick.time for this
The prompt's line 3 shows a day/night label (`Night Time`, `Day Time`), but
this is NOT available in GMCP and is NOT derivable from `gmcp.tick.time`.

**CONFIRMED:** `gmcp.tick.time` is a clock string ONLY — e.g. `"8:00am"`,
`"12:30pm"`. It never carries a "Night Time"/"Day Time" label. Confirmed via
multiple in-game `lua display(gmcp.tick)` captures across a full session.

**Resolved source:** Day/Night is derived from the `time` command's hour +
ampm (see TIME COMMAND section above), using Steven's existing trigger that
runs `time` twice per in-game day. This is the authoritative source — not the
prompt, not gmcp.tick.time. See `MyDSL_PromptView.lua` directly.

### GMCP tick carries:
- `gmcp.tick.time` — clock string only (e.g., `"8:00am"`) — CORRECTED, see above

---

## STILL NEEDED (TODO for CommandRef)

**Checkbox meaning, clarified 2026-08-23 after a Claude.ai review pass
correctly flagged 3 items reading as "done" when they weren't**: `[x]`
here means *the real pattern is confirmed and documented in this file*
— it does NOT mean a parser/capture/display for it exists in
`MyDSL_*.lua`. Some `[x]` items below do have real capture built
already (their own text says so); some don't yet (their own text says
that too). Always read the item's own prose, not just the checkbox, for
build status — but a plain `[ ]` means the pattern itself isn't even
confirmed real yet, which is a meaningfully earlier stage than "pattern
confirmed, capture not built."

**2026-07-05 audit: most of this checklist was stale — captured elsewhere
during Phase B but never checked off here.** Corrected:
- [x] `lunar` / `l moons` — captured, see "MOON SYSTEM" section this file
- [x] `time` — captured, see "GAME TIME / TICK" section this file
- [x] `scan` — see `MyDSL_ScanView.lua` / `MyDSL_DataLayer.lua`'s scan parse
      functions directly (the contract that used to document this is deleted)
- [x] `group` — see `MyDSL_GroupView.lua` / DataLayer's group parse functions
- [x] `consider <mob>` — see `MyDSL_TargetView.lua`'s consider-capture triggers
- [x] Weather description lines — trigger wired in DataLayer (`MyDSL._triggers.weather`);
      no display row consumes it yet (MoonWeather Gap, low priority)
- [x] `improve` — parser exists (`MyDSL.parseImproveLine`)
- [x] Combat (damage/evasion/condition/death/procs) — see "COMBAT" section
      this file, added 2026-07-05 (was worked on all session but never
      consolidated here until now)
- [x] `inventory` / `inv` — item list format — **confirmed real 2026-08-23**
      via a cross-profile log scan (sibling PNP profile corpus, DSL server
      text so applies here too). Real format:
      ```
      You are carrying:
           (Fireproof) (Glowing) a spirit hoard
           (Fireproof) a mage potion pouch
      ```
      Header `"You are carrying:"`, each item indented 5 spaces, any flags
      as parenthetical prefixes before the item name. No parser exists yet
      — this only confirms the pattern is real and capturable, not that
      it's built. See `docs/TODO.md`'s fuzzy-name-matching item, which
      already has a stub `MyDSL.beginInventory()`/`parseInventoryLine()`
      pipeline built for a different purpose (ground-item resolution) —
      check whether that can be extended before writing a second parser.
- [x] `equipment` / `eq` — equipped items format — **confirmed real
      2026-08-23**, same source. Real format:
      ```
      You are using:
      <used as light>     (Glowing) an illuminating crystal shard - [2] Bless, 1 Dam
      <worn on finger>    an Ofcol signet ring
      <worn around neck>  (Glowing) the Amulet of Kwainin
      <worn on torso>     a silk cloth shirt -[20C] 8/8/8/5 -[20C] 8/8/8/5
      <wielded>           something.
      <sheathed>          (nothing)
      ```
      Header `"You are using:"`, each line `<slot name>` (left-padded to
      align) then the item description, or `(nothing)` for an empty slot.
      No parser exists yet — same status as `inventory` above.
- [x] `affects` — spell list (text fallback format) — **confirmed real
      2026-08-23**. GMCP path already works; text fallback is:
      ```
      You are affected by the following spells:
      Song : song of war
      Spell: toughness
      ```
      matching `A.ids.triggers.start`'s existing regex. **Real capture
      gap found alongside this**: the modifier-less form above (no
      "modifies ... by ... for ... cycles" clause) matches neither
      `A.ids.triggers.song` nor `A.ids.triggers.spell` in
      `MyDSL_AffectsView.lua` — both current regexes require that clause.
      Tracked in `docs/TODO.md`.
- [x] Day/night transition messages — **confirmed real 2026-08-23**:
      `"The sun rises in the east."` appears to be the universal
      transition broadcast (repeated across many independent log files,
      room-independent). Room-specific flavor text conditioned on the
      same day/night clock also exists (e.g. a desert room's own sunset
      description) but is not the generic message — treat those as
      separate, room-flavor-only text. No History routing built yet.
- [ ] `terrain` command's real output while swimming/in the ocean/underwater —
      confirmed real terrain-command output shapes so far (full corpus grep,
      2026-07-19): "The terrain is that of fields/the forest/the heated
      desert.", "The terrain is very icy.", "The terrain type is
      undetermined.", "It's hard to see the terrain indoors.", "There is no
      terrain, your in the air!" (this last one is the confirmed "air"
      pattern already wired into `DSL_Generic_Mapper.xml`'s `normalizeSector()`
      and its native "DSL Terrain Capture" trigger). Zero occurrences of
      anything swim/ocean/underwater-shaped in the available corpus (578
      log files + PNP files + `DSL_Helpfiles/terrain.txt`, which only
      documents usage syntax, not output). **Re-checked 2026-08-23 against
      every other source on this machine** (all sibling profile logs, both
      `log/Archive.zip` files, and a previously-unswept `~/Downloads/
      logs.zip`, 121 files) — still zero occurrences anywhere. This gap is
      genuinely unresolved by any available log source; needs a live
      swim/ocean session. `normalizeSector()`'s `exact`
      table already has `swim`/`ocean`/`underwater` entries, but with no
      `:find()` substring fallback and no matching native trigger pattern
      — same class of gap the "air" fix closed, but deliberately NOT
      guessed at, per this project's no-invented-patterns rule (the
      original room-weight table was rejected for the same reason). Add
      the real pattern here the next time Steven types `terrain` while
      swimming/at sea/underwater, then wire it the same way "air" was.

---

## MOON SYSTEM (from wiki + in-game `lunar`)

### Three moons of Algoron
- **Red moon** — affects Neutral alignment characters (Kien's moon)
- **White moon** — affects Good alignment characters
- **Black moon** — affects Evil alignment characters. **Only visible to evil-aligned characters**

This is why `lunar` only showed red and white for Kien — he cannot see the black moon.

### Lunar output format (actual):
```
The red moon is full and not visible.
   [Mana +15%]  [Saves -3]  [Casting +3]  [Regen   0%]  [Cycles remaining 45 (22 Hours)]
The white moon is crescent waning and not visible.
```

### Parse patterns (corrected — old patterns were completely wrong):
```lua
-- Moon description line:
-- "The red moon is full and not visible."
local color, phase, visibility = line:match("^The (%a+) moon is (.+) and (.-)[%.%s]*$")

-- Bonus line (indented, in brackets):
-- "   [Mana +15%]  [Saves -3]  [Casting +3]  [Regen   0%]  [Cycles remaining 45 (22 Hours)]"
local mana = line:match("%[Mana ([%+%-]?%d+)%%%]")
local saves = line:match("%[Saves ([%+%-]?%d+)%]")
local cast  = line:match("%[Casting ([%+%-]?%d+)%]")
local regen = line:match("%[Regen%s+([%+%-]?%d+)%%%]")
local cycles, hours = line:match("%[Cycles remaining (%d+) %((%d+) Hours%)%]")
```

### Moon phases (8 phases):
Full, 3/4 Moon Waning, 1/2 Moon Waning, Crescent Waning,
Empty, Crescent Waxing, 1/2 Moon Waxing, 3/4 Moon Waxing

### Moon position effects on Regen:
| Position | Regen bonus |
|---|---|
| rising | +25% |
| high sanction | +50% |
| setting | +25% |
| not visible | 0% |

Note: "not visible" = moon is below horizon, NOT that it's the Empty phase.
Empty Moon can still show "high sanction" for its +50% window.

### Phase cycle lengths (ticks per full phase):
- Black moon: 66 ticks per phase
- Red moon: 90 ticks per phase
- White moon: 108 ticks per phase

### Who is affected by moons:
Mages and Mage Reclasses (including Conclave CSRs).
Kien (Druid) DOES show moon bonuses — verify if Druids are affected or if this is universal.

---

## ALGORON CALENDAR (from wiki)

### Days of the week (7 days):
1. Day of the Bull
2. Day of Deception
3. Day of Thunder
4. Day of Freedom
5. Day of the Great Gods
6. Day of the Sun
7. Day of the Moon

### Months of the year (17 months):
1. Month of the Old Forces
2. Month of the Grand Struggle
3. Month of the Spring
4. Month of Nature
5. Month of Futility
6. Month of the Dragon
7. Month of the Sun
8. Month of the Heat ← Kien is currently in this month
9. Month of the Battle
10. Month of the Dark Shades
11. Month of the Shadows
12. Month of the Long Shadows
13. Month of the Ancient Darkness
14. Month of the Great Evil
15. Month of the Winter
16. Month of the Winter Wolf
17. Month of the Frost Giant

### Calendar structure:
- 35 days per month (5 weeks × 7 days)
- 17 months per year
- Total days per year: 595

### Real-time equivalents:
| Game time | Real time |
|---|---|
| 1 game day | 33 minutes |
| 1 game week | 3 hours 51 minutes |
| 1 game month | 19 hours 15 minutes |
| **1 game year** | **13 days 15 minutes** |
| 1 tick | ~41 seconds (game-time: 30 game-minutes) |

### Implications for scripts:
- Birthday script: fires approximately every 13 real-time days
- A "daily note" prompt: fires every 33 real-time minutes
- Year note: fires every 13 real-time days

### Note on calendar:
Month order is documented but the "first month of the year" is unknown.
Crashes/reboots may change the current month randomly.

---

## TIME COMMAND

### Command: `time`

### Output (3 lines + period):
```
It is 3:00 o'clock am, Day of the Great Gods, 26th the Month of the Heat.
DSL started up at Thu May 28 21:12:10 2026
The system time is Tue Jun  9 17:48:34 2026
.
```

### Corrected parse pattern (Lua):
```lua
-- OLD (broken): "It is (%d+) o'clock (%a+), on the Day of ([^,]+), the (%d+)[^ ]+ of ([^%.]+)"
-- NEW (correct):
local hour, ampm, day_name, day_num, month =
    line:match("It is (%d+):%d+ o'clock (%a+), Day of ([^,]+), (%d+)%a+ the Month of ([^%.]+)")
-- Results: hour="3" ampm="am" day_name="the Great Gods" day_num="26" month="the Heat"
```

Note: day_name includes "the" (e.g., "the Great Gods", "the Moon"). This is correct.

---

## AFFECTS COMMAND

### Command: `affects`

### GMCP behavior: `affects` command triggers `gmcp.affect_data` to fire FIRST.
This means typing `affects` produces a full GMCP sync before the text output.
The text output is therefore almost never needed — GMCP delivers the authoritative list.

### Text output format:
```
You are affected by the following spells:
Spell: detect hidden     : modifies none by 0 for 32 cycles, (16 hours)
Spell: detect invis      : modifies none by 0 for 32 cycles, (16 hours)
```

---

## COMBAT (confirmed patterns — added 2026-07-05, gap this file had all session)

*Full 2026-07-05 combat-hardening pass produced all of this; it was never
consolidated here even though this file exists exactly to prevent
re-deriving patterns. Live triggers: `MyDSL_DataLayer.lua`, Section 10,
"Combat triggers" block. All patterns below are PCRE (double-backslash Lua
string convention), verified against `log/` and/or `PNP files/DSL_PNP_Battle.lua`.*

### Damage (one unified trigger for all severity tiers)
```
Your pierce misses a gnome student.
Your pierce hits a gnome student.
Your pierce *** DEVASTATES *** a gnome student!
A wild bear's slash MASSACRES a gnome student!
```
Pattern (PNP-derived, `combatDamage`):
```
^(You|[\w\-\s,']+?)(?:(?<=You)r|'s)?(?:\s?((?<=Your )[\w\s]+?|(?<='s )[\w\s]+?|))(?: do[es]*| [\>\<\=\*]+|) (VERB)[esES]*(?: things to| [\>\<\=\*]+|) ([\w\-\s,']+)([\.\.!]+)$
```
`VERB` = `miss|scratch|graze|hit|injure|wound|maul|decimate|devastate|maim|MUTILATE|DISEMBOWEL|DISMEMBER|MASSACRE|MANGLE|DEMOLISH|DEVASTATE|OBLITERATE|ANNIHILATE|ERADICATE|GHASTLY|HORRID|DREADFUL|HIDEOUS|INDESCRIBABLE|UNSPEAKABLE`
— 26-entry severity ladder (relative units, not real HP), see the `DAM_INFO`
table in `MyDSL_DataLayer.lua`'s Section 9q.

### Evasion — 5 confirmed forms (all direct ports of PNP's tested regex)
```
You dodge a gnome student's attack.
A gnome student dodges your attack.
You parry a gnome student's attack.
A gnome student parries your attack.
You block a gnome student's attack with your shield.
A gnome student senses they're about to be hit and deflects the blow.
A gnome student senses your attack coming and avoids its blow.
```
- `(You|[\w\-\,\s']+) (dodge)s? (your|[\w\-\,\s']+) attack\.$`
- `(You|[\w\-\,\s']+) (parry|parries) (your|[\w\-\,\s']+) attack\.$`
- `(You|[\w\-\,\s']+) (block)[s]? (your|[\w\-\,\s']+) attack .*\.$`
- `^[\w\-\s,']+ senses they.?re about to be hit and deflects the blow\.` (third-party form only, live — see gap below)
- `^[\w\-\s,']+ senses [\w\-\s,']+'s attack coming and avoids its blow\.` (third-party form only, live — see gap below)

**Confirmed gap, NOT fixed:** the two `senses` (sense-evade) triggers only match third-person phrasing
(`"A gnome student senses..."`), same historical bug class as dodge/parry/block had before the
2026-07-05 fix — unconfirmed whether DSL phrases a you-as-subject sense-evade differently; needs
checking against `log/` for a `"You sense..."` form before porting the same you-as-subject fix here.

### Condition ladder — 7 stages, confirmed THIRD-PERSON ONLY (self-condition gap, NOT fixed)
```
<mob> is in excellent condition.
<mob> has a few scratches.
<mob> has some small wounds and bruises.
<mob> has quite a few wounds.
<mob> has some big nasty wounds and scratches.
<mob> looks pretty hurt.
<mob> is in awful condition.
```
**Confirmed live in `log/` — self-condition uses second person, a different verb than every entry
above**, and neither our trigger nor PNP's own has ever matched it:
```
You are in excellent condition.
You have a few scratches.
You have some small wounds and bruises.
You have quite a few wounds.
You look pretty hurt.
```
(third-person `has`/`is`/`looks` → second-person `have`/`are`/`look`; not yet fixed, tracked in `TODO.md`)

### Death — 2 confirmed forms, BOTH now handled (as of 2026-07-05)
```
a gnome student is DEAD!!
A gnome student hits the ground ... DEAD.
```
Both fire `parseCombatDeathLine()` → `MyDSL.combat.ended`. Confirmed live: some sessions use only one
form for an entire session, others use both for the same kill (redundant, harmless —
`snapshotFight()` no-ops if the target's accumulator is already cleared).
- `^(.+) is DEAD!!$` (Lua pattern, inside `parseCombatDeathLine`)
- `^(.+) hits the ground %.%.%. DEAD%.$` (Lua pattern, inside `parseCombatDeathLine`)
- Triggers: `" is DEAD!!$"` / `" hits the ground \\.\\.\\. DEAD\\.$"` (PCRE)

### Killing-blow flavor text — new pattern class, confirmed 2026-07-07, NOT yet wired to anything
A random first-person flourish line fires on the finishing hit, alongside (not instead of) the
normal death line above — confirmed via a 216-file DSL2-era log-catalog pass (dates 2026-06-06
through 2026-07-07, includes a previously-missed `log/2026-0/` subdirectory the flat `log/*.html`
glob had skipped). Distinct from the damage VERB severity ladder — these are one-off finishers, not
part of that ladder:
```
You disembowel <target> with amazing skill!
You cleave <target> in half with one mighty swing!
You reach through <target>'s chest and pull out its/her/his still beating heart!
You tear <target>'s windpipe right out of its/his/her throat!
You pull <target>'s spine out through his/her mouth!
You smash your weapon through <target>'s skull!
You smash a hole into <target>'s body and watch his/her spleen fall to the ground!
You slam into <target>'s body!
```
Not wired to any trigger yet — flagged here as confirmed real text for whenever this is picked up
(e.g. as combat-window flavor, or folded into the death-line capture).

### Disarm — confirmed 2026-07-07 (see also `MyDSL_CharacterAssist.lua`'s rearm triggers)
```
An air elemental DISARMS you and sends your weapon flying!         (mob disarms you -- confirmed exact)
Rylae grabs Moe's weapon and sends it flying!                       (third-person analog, no comma before "and")
Rylae tries to disarm Moe, but fails.                                (fail form, both directions)
A cave bear tries to disarm you, but your grip is too strong!        (fail form, self-target variant)
```
No literal first-person `"You disarm <name>!"` success form was found anywhere in the 216-file
corpus — worth remembering if `"Skills/Spells -> Combat window"` (see `docs/TODO.md`) ever tries to
echo the player's own disarm success, since that exact phrasing doesn't appear to exist. PNP's
`"grabs your weapon, and sends it flying!"` pattern had a comma the confirmed third-person analog
doesn't have — `MyDSL_CharacterAssist.lua`'s `disarm2`/`disarm3` triggers made the comma optional
rather than assert one way, since only the third-person form (not the exact player-as-victim
wording) was actually confirmed.

### Bash-evasion — new confirmed form, NOT in the 5-form evasion list above
```
You evade a gnome machinist's bash, causing him to fall flat on his face.
You evade the quadrone's bash, causing it to fall flat on its face.
```
Distinct from the generic `dodge`/`parry`/`block`/`senses` evasion forms above — this is evading a
*bash* specifically, with a knockdown-avoidance flourish. Not yet wired to any trigger.

### Weapon-flag procs — 14 PNP-confirmed + 3 our own (Poison)

**Confirmed gotcha, applies to Frost/Flame/Shock/Vamp/Stun:** the "attacker" side of these lines is
frequently the **weapon's own name**, not the wielder — DSL's text never names the wielder here:
```
A grand arcanium hoopak draws life from Rylae.
A fine alloy great sword draws life from an office worker.
is knocked to the ground by a runehammer.
is knocked to the ground by "Nadrik's Honor".
```
Quoted weapon names (`"Nadrik's Honor"`) are real — Frost/Vampiric/Stunning trigger char classes
include `"` and strip it via `stripQuotes()` before normalizing.

| Code | Flag | Pattern(s) |
|---|---|---|
| C | Frost | `([\w\-\s,'"]+) freezes ([\w\-\s,'"]+)\.$` / `^The cold touch of ([\w\-\s,']+) surrounds you with ice` |
| F | Flaming | `([\w\-\s,']+) is burned by ([\w\-\s,']+)\.$` / `([\w\-\s,']+) sears your flesh` |
| L | Shocking | `([\w\-\s,']+) is struck by lightning from ([\w\-\s,']+)\.$` / `([\w\-\s,']+) is shocked by a` |
| H | Vampiric | `([\w\-\s,'"]+) draws life from ([\w\-\s,'"]+)\.$` / `^You feel ([\w\-\s,']+) drawing your life away` |
| S | Stunning | `([\w\-\s,'"]+) is knocked to the ground by ([\w\-\s,'"]+)\.$` |
| M | Mana drain | `^You feel something drawing your energy away` / `([\w\-\s,']+) draws energy from ([\w\-\s,']+)\.$` |
| O | Holy | `^You feel a surge of ([\w\-\s,']+)'s holy wrath race through your body` / `^A flash of holy power erupts from ([\w\-\s,']+) and hits ([\w\-\s,']+)!$` |
| U | Unholy | `^You feel a surge of ([\w\-\s,']+)'s unholy wrath race through your body` |
| P | Poison (our own addition, no PNP equivalent) | setup: `([\w\-\s,']+) coats ([\w\-\s,']+) with deadly lifebane poison\.$` — onset: `([\w\-\s,']+) is poisoned by the venom on ([\w\-\s,']+)\.$` — tick (~40s): `([\w\-\s,']+) shivers and suffers\.$` |

**Sharp**: no confirmed trigger text found in any log to date. **Vorpal**: confirmed non-functional,
produces no echo at all (Steven confirmed directly) — deliberately not wired.

### Combat-end (beyond death)
```
You flee from combat!
You cannot escape from combat!!!
<name> rescues you!
<name> has fled!
```
- `^You flee from combat!$` → snapshot + clear your own combat state
- `^You cannot escape from combat!!!$` → **not** an end condition, combat continues
- `rescues you!$` → snapshot + clear
- `^[\w\-\s,']+ has fled!$` → snapshot + clear that target's accumulator only

### Scope note — no relevance filter (as of 2026-07-05, deliberate)
Combat tracking has **no** filter on who's fighting whom — every combat line DSL shows you gets
tracked, matching PNP's own `handle_damage()` (which never filters either). Known tradeoff: ambient
bystander fights you happen to see (`"A boar's charge misses a liger cub."`) get tracked too. See
`MyDSL_DataLayer.lua`'s `parseCombatDamageLine()`/`parseCombatAvoidLine()`
for where the filter used to live and why it was removed.

### Corrected text parse pattern (Lua):
```lua
-- OLD (broken): line:match("^%s*(.-)%s+affects%s+(.-)%s+by%s+([%+%-]?%d+),%s+for%s+(%d+)%s+cycles?%.")
-- NEW (correct):
local name, loc, mod, cycles, hours = 
    line:match("^Spell:%s*(.-)%s*:%s*modifies%s+(%S+)%s+by%s+([%+%-]?%d+)%s+for%s+(%d+)%s+cycles?,%s+%((%d+)%s+hours?%)")
```

"none by 0" means the spell has no stat modifier (detection spells, protective auras, etc.)


# Module Contract: MyDSL_CombatView.lua
**Layer 3 Phase B — Combat Round Condenser + Per-Target Tally**
*Written 2026-07-04 — design finalized via extensive live-log analysis; several fields marked NEEDS LIVE CONFIRMATION per this project's established practice*

---

## What This Module Is

CombatView condenses the wall of raw combat spam DSL produces every round into
two things, shown in the existing (currently empty) `MyDSL_Combat` window:

1. **A live condensed round log** — one line per attacker→target→weapon per
   round, instead of DSL's raw multi-line-per-swing output. Weapon-flag procs
   (flaming, frost, etc.) fold into the same line as a small tag, not a
   separate line.
2. **A per-target hit/miss/proc tally** — accumulates while a specific target
   is being fought, snapshotted and displayed the moment that fight ends
   (death, flee, or rescue), then cleared for that target.

It is a **passive observer only**. It never sends commands, never auto-targets,
never auto-flees. It only reads and condenses what DSL already sent.

---

## Philosophy note vs. other Phase B windows

Group/Target/Scan all had a clean DSL-provided block boundary (`Score for`,
`Looking around you see:`, `Kien's group:`) to hang a begin/catch-all/end
trigger pattern on, same as `beginScore`/`beginScan`/`beginGroup`. **Combat
has no such clean boundary** — DSL just emits lines continuously whenever a
swing lands, with no "combat block started" header. So this module's
DataLayer integration is architecturally different: instead of one
begin-trigger installing a temporary catch-all, it's several **always-active**
triggers (damage, miss/dodge/parry/block, condition, death, flee/rescue,
weapon-flag proc) that each fire independently and feed a shared accumulator
table. The "round" boundary is DSL's own prompt line reprinting after a
combat batch — this already fires a working trigger elsewhere in the profile
(`parsePromptLine`, DataLayer Section 9d2). **Claude Code must read the actual
current `parsePromptLine()` implementation and hook the round-flush to
whatever event it already raises, rather than adding a second competing
prompt trigger.** Do not guess the event name — confirm it directly in the file.

---

## Scope filter — whose combat gets condensed

DSL's room-wide combat broadcast includes fights that have nothing to do with
you (confirmed live in the archive: `A boar's charge misses a liger cub.` —
an ambient NPC fight nowhere near Kien). CombatView must **ignore lines where
neither party is you nor a current group member**:

```lua
-- A line is "yours" if either side normalizes to you, or matches a key
-- currently present in MyDSL.State.group.members (same normalization as
-- GroupView/ScanView: lowercase, strip leading a/an/the).
local function isRelevant(attackerKey, targetKey)
  if attackerKey == "you" or targetKey == "you" then return true end
  local grp = MyDSL.State.group and MyDSL.State.group.members
  if not grp then return false end
  for _, m in ipairs(grp) do
    local mkey = m.name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
    if attackerKey == mkey or targetKey == mkey then return true end
  end
  return false
end
```

This reuses the exact key-normalization convention already established in
`ScanView`/`GroupView` — no new pattern invented here.

---

## Confirmed DSL Combat Vocabulary

*(Source: extensive normalized scan across the full uploaded log archive —
407 files, Jan–Jul 2026 — cross-checked against `DSL_PNP_Battle.lua`'s
already-solved condensation approach per the project reference summary.)*

### One unified severity ladder — corrected from PNP's actual source

**Earlier drafts of this contract theorized two separate ladders (weapon vs.
spell). That was wrong.** Cross-referencing PNP's actual `DSL_PNP_Battle.lua`
source (not just the architectural summary) proves it's **one continuous
scale** — words get more dramatic and more capitalized purely as a function
of damage amount, regardless of whether the source is a weapon or a spell.
`devastate` (lowercase) and `DEVASTATE` (ALLCAPS) are the same word at two
different tiers — that's what earlier logs showing both lowercase and
ALLCAPS versions of similar words actually meant, not a source-type split.

**Adopting PNP's exact tuned severity-score table** (relative units, not
real HP — battle-tested over years of PNP use, far more reliable than our
own guessed percentage bands):

| Score | Word | Bracket decoration |
|---|---|---|
| 0 | miss | — |
| 2.5 | scratch | — |
| 6.5 | graze | — |
| 10.5 | hit | — |
| 14.5 | injure | — |
| 18.5 | wound | — |
| 22.5 | maul | — |
| 26.5 | decimate | — |
| 30.5 | devastate | — |
| 34.5 | maim | — |
| 38.5 | MUTILATE | — |
| 42.5 | DISEMBOWEL | — |
| 46.5 | DISMEMBER | — |
| 50.5 | MASSACRE | — |
| 54.5 | MANGLE | — |
| 58.5 | DEMOLISH | `*** ... ***` |
| 68 | DEVASTATE | `*** ... ***` |
| 88 | OBLITERATE | `=== ... ===` |
| 113 | ANNIHILATE | `>>> ... <<<` |
| 138 | ERADICATE | `<<< ... >>>` |
| 163 | GHASTLY | rainbow-colored, uses "does ... things to" grammar |
| 188 | HORRID | same grammar |
| 213 | DREADFUL | same grammar |
| 238 | HIDEOUS | same grammar |
| 263 | INDESCRIBABLE | same grammar |
| 276 | UNSPEAKABLE | same grammar |

The top six tiers (GHASTLY through UNSPEAKABLE) use a different sentence
shape entirely: `"<attacker> does GHASTLY things to <target>!"` instead of
`"<attacker>'s <noun> GHASTLY <target>!"`. None of these six have appeared
in any of our own logs (nobody's hit anything that hard yet), but they're
real, confirmed DSL text via PNP's tuned table, and the regex below handles
all three sentence shapes in one pattern.

**Confirmed unified trigger pattern (adapted from PNP, same core logic):**
```
^(You|[\w\-\s,']+?)(?:(?<=You)r|'s)?(?:\s?((?<=Your )[\w\s]+?|(?<='s )[\w\s]+?|))(?: do[es]*| [\>\<\=\*]+|) (miss|scratch|graze|hit|injure|wound|maul|decimate|devastate|maim|MUTILATE|DISEMBOWEL|DISMEMBER|MASSACRE|MANGLE|DEMOLISH|DEVASTATE|OBLITERATE|ANNIHILATE|ERADICATE|GHASTLY|HORRID|DREADFUL|HIDEOUS|INDESCRIBABLE|UNSPEAKABLE)[esES]*(?: things to| [\>\<\=\*]+|) ([\w\-\s,']+)([\.!]+)$
```
One trigger, one severity table, no ladder-type branching needed anywhere
in the parser — this simplifies the implementation considerably compared
to the earlier two-ladder design.

**False-positive guard, adopted directly from PNP:** skip the line entirely
if the attacker or noun text contains any of `{"You gain", "has big nasty",
"Affects", "has some small", "Wimpy"}` — these are PNP's own battle-tested
exceptions preventing the damage trigger from misfiring on unrelated lines
(XP gain messages, affects listings, etc.) that happen to contain
overlapping words.

### Avoidance — 5 confirmed types (adopted from PNP's exact trigger set)

Earlier drafts only had 4 (miss/dodge/parry/block); PNP's source reveals a
5th — a perception-based dodge:
```
<name> dodges <attacker>'s attack.
<name> parries <attacker>'s attack.
<name> blocks <attacker>'s attack ...          -- trailing text varies, e.g. "with a shield"
<name> senses they're about to be hit and deflects the blow.
<name> senses <attacker>'s attack coming and avoids its blow.
```
`<name>` and `<attacker>` can each be `You`/`your` or any other name —
same normalization as everywhere else (lowercase, strip articles).

### Opponent condition ladder (the only enemy-HP signal DSL gives)
Fully confirmed, 8 stages, matches `DSL_PNP_Battle.lua`'s own "8 Condition
Triggers" count exactly:
```
<mob> is in excellent condition.        →  100%
<mob> has a few scratches.              →  ~90%
<mob> has some small wounds and bruises. → ~70%
<mob> has some big nasty wounds and scratches. → ~50%
<mob> has quite a few wounds.           →  ~35%
<mob> looks pretty hurt.                →  ~20%
<mob> is in awful condition.            →  ~10%
<mob> is DEAD!!                         →  0%, fight over
```
Percentages above are placeholders in the same "approximate, refine later"
spirit as the damage tiers — the stage *order* is solid, the exact % per
stage is a display nicety, not load-bearing logic.

### Death → loot → XP sequence (always this order)
```
<mob> is DEAD!!
You receive N experience points.
You hear <mob>'s death cry.
You get N silver coins and M gold coins from the corpse of <mob>.
N gold and M silver are collected for <kingdom>'s coffers.
The Gods give you N silver coins for your sacrifice.
```

### Combat-end triggers (beyond death)
Confirmed live, and confirmed **not** subject to player customization for
the forms CombatView needs (the `setflee` command only customizes the
*third-person broadcast* of a **player** fleeing — mobs/pets can't set one,
so `<name> has fled!` stays a reliable NPC-flee anchor):

| Event | Line | Ends this target's accumulator? |
|---|---|---|
| Kill | `<mob> is DEAD!!` | Yes — snapshot + clear |
| You flee successfully | `You flee from combat!` | Yes — snapshot + clear (your own combat state) |
| Flee attempt fails | `You cannot escape from combat!!!` | **No** — combat continues, not an end condition |
| Rescued out | `<name> rescues you!` | Yes — snapshot + clear |
| A mob/pet flees | `<name> has fled!` | Yes — snapshot + clear (that target's accumulator only) |

### Rage mode — corrected to match PNP's actual (simpler) proven model

**Earlier draft had this backwards and over-engineered.** PNP's real
implementation is simpler: on every prompt event, check if HP shows `???`.
If so, **re-raise the rage event every round** with the running totals
(not just once at the end); if HP is visible again, silently reset both
counters to zero. No separate "rage ended" event needed — the natural
absence of further updates once HP becomes visible again *is* the signal
that it's over.

```lua
MyDSL.State.combat.rage = { damage = 0, vamp = 0 }

-- Called every round (same round-flush hook as everything else):
local function handleRagePrompt(curHP)
  local rage = MyDSL.State.combat.rage
  if curHP == "???" then
    MyDSL.emit("combat_rage", rage.damage, rage.vamp)  -- re-fires every round while blind
  else
    rage.damage = 0
    rage.vamp = 0
  end
end
```

**Also corrected: what `vamp` actually tracks.** Earlier draft assumed it
meant "opponent vampiric hits landing on you" — backwards. PNP's real logic
tracks **your own vampiric procs landing on your target** during the blind
period (a fixed +2.5 severity-score unit per proc, same abstract unit as
the damage table), which makes sense as a signal of how much self-healing
you're likely getting back while your real HP is hidden:

```lua
-- Inside the flag-proc handler, when flag == "vampiric" and attacker == "you":
rage.vamp = rage.vamp + 2.5
```

`damage` tracks damage *taken* (target == "you") the same way, accumulating
normally regardless of rage state, but only meaningfully *displayed* while
blind since that's the only time your real HP total is hidden from you.

**Pre-check still required regardless:** whoever currently reads HP off the
prompt for other windows (MoonWeather's HP bar, AffectsView, etc.) needs to
already tolerate `???` gracefully — Claude Code should verify this before
CombatView ships, since it's a correctness issue for existing windows too,
not just new scope.

### Weapon-flag procs — confirmed complete set via PNP's actual source

**Correction from earlier drafts:** the DSL wiki lists 9 flags, but PNP's
real, battle-tested trigger set tracks **8 flags with 14 trigger patterns**
— including two the wiki never mentioned (Holy, Unholy), and it never
found triggers for Sharp, Vorpal, or Poison either (matching our own
findings exactly — Vorpal confirmed non-echoing by Steven directly, Sharp
never observed firing in any log by either of us). Our own Poison discovery
(from Steven's uploaded logs) is genuinely new ground beyond PNP's original
scope, kept as its own confirmed addition below.

**PNP's 8 tracked flags, single-letter codes, and their exact trigger text:**

| Code | Flag | Confirmed trigger pattern(s) |
|---|---|---|
| C | Frost | `<name> freezes <target>.` / `"The cold touch of <name> surrounds you with ice"` |
| F | Flaming | `<name> is burned by <attacker>.` / `<name> sears your flesh` |
| L | Shocking | `<name> is struck by lightning from <attacker>.` / `<name> is shocked by a ...` |
| H | Vampiric | `<attacker> draws life from <target>.` / `You feel <name> drawing your life away` (self, being drained) |
| S | **Stunning — the confirmed message we'd been missing:** | `<name> is knocked to the ground by <attacker>.` |
| M | Mana drain | `You feel something drawing your energy away` (self) / `<attacker> draws energy from <target>.` |
| O | Holy | `You feel a surge of <name>'s holy wrath race through your body` / `A flash of holy power erupts from <name> and hits <target>!` |
| U | Unholy | `You feel a surge of <name>'s unholy wrath race through your body` |

**Confirmed proc message forms we found independently (not in PNP's set —
genuinely new ground beyond what PNP tracks):**
```
-- Poison (full sequence, confirmed from Steven's uploaded logs):
<char> coats <weapon> with deadly lifebane poison.       -- setup
<target> is poisoned by the venom on <weapon>.            -- onset
<target> shivers and suffers.                              -- repeating tick (~40s)

-- Shocking (compound-noun form, confirmed independently, complements PNP's forms above):
<char>'s shocking bite <verb> <target>.

-- Vampiric (character-possessive form, complements PNP's forms above):
<char>'s life drain <verb> <target>.
```

**Sharp and Vorpal:** Vorpal confirmed to never echo at all (Steven
confirmed directly — settled, not a gap). Sharp remains genuinely
unconfirmed by both PNP and our own investigation — leave as a commented
placeholder.

**Why this matters beyond flavor:** these damage types (fire/cold/shock/
poison) are the exact categories `CreatureReference` already tracks under
`Resistances`/`Vulnerabilities`/`Immunities` (confirmed live: e.g. the wild
bear's `Vulnerbilities: fire mental`). CombatView should cross-reference a
firing proc's damage type against the current target's cached
`MyDSL.CreatureLore` record, if one exists, and visually flag when a proc
lands on a known vulnerability. This is additive — if no lore is cached for
that target, just show the proc tag with no cross-reference, no error.

**Implementation approach:** wire all 8 PNP-confirmed flags plus the
independently-confirmed Poison sequence — that's 9 working proc types
total, well beyond the original 5. Do not wire Vorpal. Leave Sharp as a
commented placeholder with a TODO referencing this table.

---

## Data Model

**Corrected to match PNP's proven 3-level keying** (`attacker → target →
noun`, not the flat `attacker → {single weapon field}` from an earlier
draft) — this properly supports an attacker using multiple different
weapon/damage nouns against the same target within one fight (e.g.
dual-wielding two different weapon types, or switching between a weapon
attack and a bare-hand skill):

```lua
MyDSL.State.combat = {
  -- Live, in-progress accumulators, keyed by target key (normalized name).
  -- Cleared entry-by-entry on that target's death/flee/rescue.
  active = {
    ["gnome student"] = {
      target_display = "a gnome student",
      target_condition = "excellent",   -- last-seen condition-ladder stage
      by_attacker = {
        ["you"] = {
          ["pierce"] = {                -- keyed by damage noun, 3rd level
            swings = 10, hits = 9, misses = 1,
            score_total = 245.5,        -- sum of PNP severity-scores this fight
            flags = { flame = 2 },      -- proc-type -> count, this fight
          },
        },
        ["wild bear"] = {
          ["slash"] = {
            swings = 6, hits = 6, misses = 0,
            score_total = 187.5,
            flags = {},
          },
        },
      },
      started_at = 0,   -- os.time() of first hit line seen for this target
    },
  },

  -- Last N completed fight snapshots, most recent first. Used to render
  -- the "fight summary" block after a kill/flee/rescue.
  history = {},          -- array of snapshots, same shape as one `active` entry
  history_max = 5,        -- keep last 5 fights; oldest drop off

  -- This round's per-(attacker,target,noun) running totals, used to build
  -- one condensed line per combo per round (see round-condensation below).
  -- Cleared and rebuilt every round-flush.
  round_data = {},

  -- Rage-mode tracking (see Rage mode section above).
  rage = { damage = 0, vamp = 0 },
}
```

### Round condensation — adopted from PNP: sum scores, derive one verb per round

Earlier draft had each hit append its own line immediately. PNP's actual
approach is better and is adopted here: **within a round, accumulate the
severity-score for each (attacker, target, noun) combo**, and only at the
round-flush moment derive **one representative line** per combo by looking
up which severity-tier's threshold is the highest one at-or-below that
round's summed score (same technique as PNP's `calc_dam_verb()`). A round
where you land 3 hits against the same target with the same weapon
produces **one line**, not three:

```lua
-- During the round, on each damage line:
local rd = MyDSL.State.combat.round_data
local key = attackerKey .. "→" .. targetKey .. "→" .. noun
rd[key] = rd[key] or { attacker = attackerKey, target = targetKey, noun = noun,
                        score = 0, swings = 0, hits = 0 }
rd[key].score  = rd[key].score + severityScore(verb)
rd[key].swings = rd[key].swings + 1
rd[key].hits   = rd[key].hits + (verb ~= "miss" and 1 or 0)

-- At round-flush, for each entry in round_data:
local verb = derivedVerbForScore(rd[key].score)  -- highest tier <= score, PNP-style lookup
-- render one line: "<attacker> → <target> (<noun>): <verb> [flags]"
```

This is a genuine improvement over the earlier per-hit-line design —
matches PNP's tested, readable output instead of producing a wall of
one-line-per-swing spam even after condensing multiple rounds together.

**The end-of-fight tally (death/flee/rescue snapshot) is unaffected by
this change** and remains MyDSL's own addition beyond PNP's scope — it
still breaks down cumulative hits/misses/procs per attacker+noun across
the whole fight, not just one round. Both views serve different purposes:
round line = "what just happened this round," fight-summary = "how did the
whole fight go."

---

## DataLayer Integration

**Always-active triggers (Section 10), not a begin/catch-all/end block:**

```lua
-- Damage lines (both "Your X" and "<mob>'s X" forms) — parseCombatDamageLine()
-- Avoidance lines (parry/dodge/block/miss) — parseCombatAvoidLine()
-- Condition lines — parseCombatConditionLine()
-- Death line — parseCombatDeathLine()
-- Flee/rescue/escape-fail lines — parseCombatEndLine()
-- Weapon-flag proc lines (Flaming confirmed; others as TODO placeholders)
```

Each parse function does two things: (1) update `State.combat.active[targetKey]`
accordingly, respecting the `isRelevant()` scope filter above (accumulating
into the fight-long tally, 3-level keyed as shown in Data Model); (2)
accumulate into `State.combat.round_data[attacker→target→noun]` for this
round's score-summing (see Round condensation above) — do not append a
display line immediately, only accumulate; lines are derived once at
round-flush.

**Round flush — confirmed, not a guess.** Cross-referencing the actual
`MyDSL_DataLayer.lua` (line 790), `parsePromptLine()` matches the
`"==-Day Time - 6:00pm :: ..."` prompt line — which reprints every combat
round — and calls `MyDSL.emit("time")`, raising `MyDSL.time.updated`.
CombatView hooks its round-flush to that exact existing event:
```lua
registerAnonymousEventHandler("MyDSL.time.updated", function()
  -- Derive one condensed line per (attacker,target,noun) combo from this
  -- round's summed scores (see Round condensation above), then:
  MyDSL.emit("combat")          -- raises MyDSL.combat.updated → CombatView.render()
  MyDSL.State.combat.round_data = {}   -- clear for next round's fresh batch
end)
```
No new prompt trigger needed — this repurposes an event that already fires
once per round for an unrelated reason (day/night tracking), which is fine;
multiple listeners on one event is normal Mudlet practice.

**Window registration — already provisioned, no changes needed.**
`WindowRegistry.lua` (`MyDSL_Combat = { obj=nil, type="UserWindow",
visible=true, created=false }`) and `LayoutEngine.lua`
(`MyDSL_Combat = { x=0.00, y=0.60, w=0.34, h=0.22 }`, comment already reads
*"condensed combat damage log"*) both already exist. `CombatView.init()`
just calls `Windows.ensure("MyDSL_Combat")` like every other window.

**Combat-end handling** (death/flee/rescue lines): when one of these fires
for a given target key, snapshot `State.combat.active[targetKey]` into
`State.combat.history` (insert at front, trim to `history_max`), then
`State.combat.active[targetKey] = nil`. Raise `MyDSL.combat.ended` with the
snapshot as payload so `CombatView` can render the fight-summary block.

---

## Window: MyDSL_Combat

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅ — currently an
empty tab, confirmed present in every screenshot this session)
**Content:** `Geyser.MiniConsole` inside at 100%×100%, scrollable

### Display layout

```
[Round log — scrolling, most recent at bottom]
Kien → gnome student (pierce): DEVASTATES 🔥
wild bear → gnome student (slash): MASSACRES
gnome student → Kien: misses

── Fight summary: a gnome student ──
pierce (you):    9 hits, 2 misses  (82% landed)
  🔥 flame procs: 2/9 (22%)
slash (wild bear): 6 hits, 1 miss  (86% landed)
────────────────────────────────────
```

**Round log color scheme** (reuse existing decho RGB conventions from other
windows, not new colors):
- Your own hits: `68,204,68` green (matches heal/positive-action convention)
- Ally (group member/pet) hits: `68,136,204` blue
- Incoming hits (mob → you or ally): `204,68,68` red
- Misses/avoidance: `136,136,136` dim grey
- Proc tags: gold `255,215,65` (matches Sanctuary/buff convention already in TargetView)

**Fight-summary block color scheme:**
- Header rule + target name: `255,204,68` gold (matches CreatureReference's header style)
- Weapon/attacker labels: `204,204,204` near-white
- Hit-rate percentage: green ≥75%, yellow ≥50%, red below (same threshold
  logic as `hpColor()` in GroupView, reused for consistency)
- Proc sub-line: gold, indented

Cleared/rebuilt each round for the live log portion; the fight-summary block
persists until the next fight-end event replaces it (or is appended below,
scrolling — Claude Code's call on whichever reads better once tested live).

---

## Public API

```lua
MyDSL.CombatView.init()      -- create window, register handlers
MyDSL.CombatView.render()    -- redraw round log from this round's derived lines (State.combat.round_data)
MyDSL.CombatView.renderSummary(snapshot)  -- render one fight-summary block
MyDSL.CombatView.renderRage(dmg, vamp)    -- render/update the live rage-mode indicator
MyDSL.CombatView.config = {
  -- Out-of-box: raw combat lines are gagged; condensed lines go to the
  -- combat window only (not echoed to main). Use "mydsl combat show <key>"
  -- to opt individual categories back into the round log.
  -- Corrected from earlier draft — all show_* default false matches PNP's
  -- actual tested behavior (display is opt-in, not opt-out).
  show_damage_by_me   = false,
  show_damage_to_me    = false,
  show_miss            = false,
  show_evade            = false,
  show_flag             = false,  -- weapon-flag proc tags
  show_condition        = false,  -- opponent condition-ladder line
  echo_to_main          = true,   -- echo condensed round line to main console
                                  -- (matches PNP "prints to both" behavior)
  gag_combat            = true,   -- gag DSL's raw combat lines from main
                                  -- console (PNP default; player can ungag
                                  -- with "mydsl combat ungag")
}
```

```lua
-- DataLayer (Section 9, new sub-section — combat)
MyDSL.parseCombatDamageLine(line)
MyDSL.parseCombatAvoidLine(line)
MyDSL.parseCombatConditionLine(line)
MyDSL.parseCombatDeathLine(line)
MyDSL.parseCombatEndLine(line)   -- flee/rescue/escape-fail
MyDSL.parseCombatProcLine(line)  -- Flaming/Frost/Shocking/Vampiric/Poison confirmed; Sharp/Stunning TODO
```

---

## Event Subscriptions

```lua
registerAnonymousEventHandler("MyDSL.combat.updated",
  function() MyDSL.CombatView.render() end)
registerAnonymousEventHandler("MyDSL.combat.ended",
  function(_, snapshot) MyDSL.CombatView.renderSummary(snapshot) end)
registerAnonymousEventHandler("MyDSL.combat_rage",
  function(_, dmg, vamp) MyDSL.CombatView.renderRage(dmg, vamp) end)
```

---

## Aliases

```
mydsl combat clear     → manually clear State.combat.active and round_data
                         (escape hatch if a fight's accumulator gets stuck —
                         e.g. you logged out mid-fight and it never got a
                         death/flee/rescue line to close it out)
mydsl combat history   → print the last N fight summaries again on demand
mydsl combat gag       → set config.gag_combat = true (hide raw combat
                         spam from main console, condensed log only)
mydsl combat ungag     → set config.gag_combat = false (default)
mydsl combat show <k>  → set config.show_<k> = true, one of the boolean
                         keys listed in the config table above
mydsl combat hide <k>  → set config.show_<k> = false
```

Config toggles ported from PNP's tested surface — see Public API section
above for the full list and defaults.

---

## init() Sequence

1. Ensure `MyDSL_Combat` UserWindow exists (already registered — just `Windows.ensure()`)
2. Create MiniConsole inside at 100%×100%
3. Register `MyDSL.combat.updated` and `MyDSL.combat.ended` handlers
4. `render()` — shows empty state initially (`"(no combat)"`, matching the
   `(no group)`/`(no target)` convention from other windows)

---

## What This Module Does NOT Do

- Does not send any command automatically — no auto-flee, no auto-target-switch
- Does not condense combat that doesn't involve you or a current group member
  (ambient third-party fights are ignored entirely)
- Does not invent precise numeric damage — severity-tier percentage bands are
  clearly-labeled estimates, not measured values, until the calibration pass
  described above happens
- Does not track the AGL/coliseum multi-room PvP combat format (bracketed
  `[Location]` tags, numeric `(88)` damage, `setflee`-customized third-person
  broadcasts) — that's a materially different message format handled
  separately if ever needed
- Does not wire a trigger for Vorpal — confirmed (directly, by Steven) to
  produce no combat echo at all, so there is nothing to parse
- Does not wire regex for Sharp or Stunning — both confirmed real mechanics
  but with zero observed trigger text across the full log investigation;
  placeholders only, filled in if/when either is actually encountered live
- Does not implement a configurable format-string engine in v1 — PNP's
  `dam_format`/`summary_format` token system (`%a/%t/%v/...`) stays deferred;
  the simpler show/hide and gag boolean toggles are adopted (see Public API),
  only the token-string engine itself waits for a hardcoded format to be
  tested live first

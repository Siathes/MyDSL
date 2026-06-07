# DSL1 Mudlet Profile — Complete Audit
Generated: 2026-06-06. Reference only — nothing changed.

---

## 1. Windows

All windows are `Geyser.UserWindow` (dockable, resizable) unless noted. Positions are defaults; actual positions saved in `MyDSL/settings.lua`.

| Window ID / Name | Script Module | Creation Method | Default Position | Purpose |
|---|---|---|---|---|
| `MyDSL_Chat` | ChatWrapper v4C11 | `Geyser.UserWindow:new` | x=65%, y=0%, w=35%, h=35% | EMCO chat tabs (Tells, OOC, City, Local, Group) |
| `MyDSL_Affects` | AffectsView v4C16 | `Geyser.UserWindow:new` | x=70%, y=35%, w=30%, h=25% | Active spell/affect list with countdown timers |
| `MyDSL_Portrait` | PortraitView v4C4 | `Geyser.UserWindow:new` | x=0%, y=0%, w=20%, h=30% | Per-character portrait image (HTML Label) |
| `MyDSL_Location` | LocationView v4C3 | `Geyser.UserWindow:new` | x=740px, y=80px (abs) | Room picture image + caption |
| `MyDSL_Live` | LiveView v1A14 | `Geyser.UserWindow:new` | x=32%, y=77%, w=34%, h=13% | Room name, exits, vitals bars, time, XP line |
| `MyDSL_Tick` | TickView v4C5 | `Geyser.UserWindow:new` | x=80%, y=70%, w=7%, h=18% | Tick countdown tube + seconds display |
| `MyDSL_Target` | TargetRightHere v4C32 | `Geyser.UserWindow:new` | x=0%, y=75%, w=25%, h=25% | Current combat target info + lore |
| `MyDSL_RightHere` | TargetRightHere v4C32 | `Geyser.UserWindow:new` | (dynamic) | Clickable mob list from scan output |
| `MyDSL_CreatureReference` | CreatureReferenceWindow v1 | `Geyser.UserWindow:new` | (not specified) | Creature lore lookup reference pane |
| `History` | WindowCore v4C12 | `Geyser.UserWindow:new` | x=5%, y=5%, w=35%, h=30% | Redirected notifications, events, broadcasts |
| `Combat` | WindowCore v4C12 | `Geyser.UserWindow:new` | x=5%, y=5%, w=35%, h=30% | Combat output condensed via BattleCondenser |
| `Scan` | WindowCore v4C12 | `Geyser.UserWindow:new` | x=5%, y=5%, w=35%, h=30% | Scan output (room occupants) |
| `Group` | WindowCore v4C12 | `Geyser.UserWindow:new` | x=5%, y=5%, w=35%, h=30% | Group member status |
| `PlayersNearYou` | WindowCore v4C12 | `Geyser.UserWindow:new` | x=5%, y=5%, w=35%, h=30% | `players near` output |
| `my_mapper` | generic_mapper | `Geyser.Mapper:new` | (dynamic, set by `map window`) | Mudlet map widget |
| EMCO container | EMCOChat Code | `Adjustable.Container:new` | (saved by EMCO) | Outer container for chat tabs |

**Sub-elements inside windows** (Geyser.Label / MiniConsole children):
- `MyDSL_Live`: Panel, RoomTitle, ExitsCon (MiniConsole), RoomMeta, Time, XPLine, Divider, HP/Mana/MV bar back/fill/text labels
- `MyDSL_Tick`: Panel, Title, Tube, Fill, Seconds, Detail, Strip labels
- `MyDSL_Portrait`: full-window image label + caption label (y=88%, h=11%)
- `MyDSL_Location`: Image label (100%×100%) + Caption label (y=82%, h=17%)
- `MyDSL_Target`: HP Gauge (`MyDSL_TargetCompact_HP_v4C17`), MP Gauge (`MyDSL_TargetCompact_MP_v4C17`)
- `MyDSL_CreatureReference`: MiniConsole (100%×100%) inside the UserWindow

---

## 2. Triggers

### Top-level / uncategorized

| Name | Active | Pattern(s) | Action |
|---|---|---|---|
| Do you want color? | yes | `Do you want color? (Y/N) ->` | (no script — likely auto-answer elsewhere) |
| is DEAD!! Scan | yes | `is DEAD!!`, `You hear something's death cry.` | (no script body — duplicate of combat group) |
| is DEAD!! Get all for food | yes | `is DEAD!!`, `You hear something's death cry.` | (no script body) |
| ---Highlight 1 word | **no** | `^You drink (.+?) from`, `mydsl bridge status` | disabled/empty |
| capture 2 items in the line | **no** | `^You drink (.+) from (.+)\.?$` | disabled example |

### Group: generic_mapper

| Name | Active | Patterns | Action |
|---|---|---|---|
| onNewLine Trigger | yes | `raiseEvent("onNewLine")` | `raiseEvent("onNewLine")` |
| English Exits Trigger | yes | 7 exit-line patterns | `raiseEvent("onNewRoom", exits)` |
| English Failed Move | yes | 8 blocked-move patterns | `raiseEvent("onMoveFail")` |
| English Vision Fail | yes | pitch black, too dark | `raiseEvent("onVisionFail")` |
| English Forced Move | yes | `Carefully getting your bearings...` | `raiseEvent("onForcedMove", dir)` |
| English Multi-Line Exits | **no** | `^(obvious\|visible) exits:` | disabled multi-line exit collector |
| Russian Exits/Fail/Vision | yes | Russian patterns | raiseEvent equivalents |
| Chinese Exits/Fail | yes | Chinese patterns | raiseEvent equivalents |

### Group: Actions

**Thirst**
| Name | Active | Pattern | Action |
|---|---|---|---|
| You are thirsty. | yes | `^You are thirsty\.$` | `send("drink decanter")` ×2 |
| You Drink from.. | yes | `^You drink .+ from .+\.$` | `MyDSL.Route.history(); deleteLine()` |
| Thirst quenched / not thirsty / too full | yes | various | (no script) |

**Hunger**
| Name | Active | Pattern | Action |
|---|---|---|---|
| You are hungry. | yes | `^You are hungry\.$` | `send("c 'create food'")` |
| Get/eat Rainbow Trout Filet | yes | specific text | `send("eat filet"); MyDSL.Route.history()` |
| Eat Trout / Mushroom sequences | yes | various | `MyDSL.Route.history()` |
| A Magic Mushroom appears | yes | `A Magic Mushroom suddenly appears.` | `send("get 'mushroom'")` |

**Improve**
| Name | Active | Pattern | Action |
|---|---|---|---|
| You have become better at... | yes | `You have become better at` | `send("improve"); MyDSL.Route.history()` |
| You focus your training on | yes | that pattern | `MyDSL.Route.history()` |
| You are currently improving | yes | that pattern | `MyDSL.Route.history()` |

**Room clean / corpse parts** — passive cosmetic highlights, no action (mostly)

**Quests**
| Name | Active | Pattern | Action |
|---|---|---|---|
| Quest item found triggers (5 items) | yes | item description lines | (highlight only) |
| You get [item] | yes | get confirmations | `MyDSL.Route.history()` |
| Vile thieves have stolen | yes | quest start | `MyDSL.Route.history()` |
| Quest info lines | yes | look, recover, time left | `MyDSL.Route.history()` |
| You can now quest again | yes | quest done patterns | `cecho` separator + `MyDSL.Route.history()` |
| Quest time warnings | yes | hurry, out of time | `MyDSL.Route.history()` |

### Group: Atmosphere

**Sailing** — 10+ triggers watching ship names (Black Crane, Golden Koi, Nomad, etc.) and port events; routes arrivals/departures to History, fires `onRandomMove` on board/disembark. Ship name triggers append destination labels via `cecho`.

**Waves** — 2 passive cosmetic triggers, no action.

**Lunar/Weather/Day effects**
| Name | Active | Pattern | Action |
|---|---|---|---|
| Night begins | yes | `The night has begun.` | `Route.to("History"); send("lunar")` |
| Day begins | yes | `The day has begun.` | `Route.to("History"); send("who")` |
| Sun rises/sets | yes | sun movement | `Route.to("History")` |
| Moon shape/position | yes | `The [color] moon is` | `Route.to("History")` |
| Moon bonuses | yes | 7 hardcoded bonus patterns | `Route.to("History")` |

**AGL** — match begins timer (no action).

**Areas / Gahboom** — 2 passive cosmetic triggers.

### Group: Combat

**Combat Sounds** — highlights/sounds for major combat events:
| Name | Active | Patterns | Action |
|---|---|---|---|
| experience | yes | `^You receive ([0-9]*) experience points.$` | `MyDSL.Route.history()` |
| BACKSTABS | yes | backstab patterns | `cecho` banner if battle active |
| WAYLAY | yes | waylay patterns | `cecho` banner if battle active |
| RIOT / BLINDS / GORE / DISARM / BASH / TRIP / POISON PLAGUE | yes | skill output patterns | cosmetic / no route |
| DISARM (fail) | yes | tries to disarm you... | cosmetic |
| Fall on face | yes | fall patterns | cosmetic |
| Acid / Gore / Need to SEE! | yes | breath/acid/gore patterns | cosmetic |
| has fled! | yes | `has fled!` | `MyDSL.Route.history()` |
| is DEAD!! | yes | `is DEAD!!` | `MyDSL.Route.history()` |
| Various parry/dodge/miss/block/punch | yes | attack verb patterns | cosmetic (no route) |

**Crusader stuff** — Rear, Charge, mount patterns — cosmetic banners for Crusader class skills.

**Health/Mana condition** — 8 condition-text triggers (awful → excellent), cosmetic only.

**Consider** — 6 difficulty-assessment text triggers, cosmetic only.

**NPCs** — 2 specific NPC interaction triggers, cosmetic.

### Group: Weapon Nouns
Passive highlights for 6 damage types (Slash, Pierce, Bash, Energy, Fire, Negative, Holy). No routing — cosmetic only.

### Group: Notifications

**Chat** — routes all game channels to EMCO tabs via `demonnic.chat:append(tabName)`:
| Pattern | Tab |
|---|---|
| Tells (sent/received) | Tells |
| auctions, OOC, ask/answer/newbie, radio, grats, bloodbath chat | OOC |
| gossip, clan gossip | City |
| kingdom, OOC Kingdom | City |
| says, whispers, yells, shouts | Local |
| group tells | Group |
| OOC/auction lines also `deleteLine()` from main console |

**Other Notifications**
| Name | Action |
|---|---|
| Broadcasts | `Route.to("History")` |
| Toasts/kills | `Route.to("History"); deleteLine()` |
| Portal transitions (25+ patterns) | `Route.to("History"); raiseEvent("onRandomMove")` |
| transports object to you | `Route.to("History")` |
| Must See! (crumbles, notes, Raethian) | `Route.to("History")` |
| arrived / appears | `cecho("[Opportunity]"); send("look")` |
| walks in / runs in / floats in / flies in | `Route.to("History")` |
| Blood Bath Notifications | `Route.to("History")` |
| peers at you / Imm / WARNING | `Route.to("History")` |
| Trumpet Sounds (level/kingdom/join events) | `Route.to("History")` |
| [Lv Blues Silver Qty] / Pets for sale | (highlight only) |

### Group: Random Affects
10 environmental effect lines (agile, focused, ill, etc.) — each does `Route.to("History")` and appends a stat annotation via `cecho`.

### Group: Skills / Stealth
One trigger group: "You no longer feel stealthy." — no action defined.

### Group: Spells

**Benedictions**: Bless, Frenzy, Imbue, Holy Word, Know Religion, Remove Curse, Calm, Sanctify — each has name-match trigger (cosmetic) plus wear-off detection that auto-recasts. Bless specifically: `send("c bless")` on wear-off. Sound cleanup triggers for `!!SOUND(...)` lines — `deleteLine()`.

**Detection**: Detect Invis, Detect Magic, Detect Hidden, Detect Evil, Detect Good, Detect Poison, Locate Object, Identify, Farsight, Know Alignment/Languages. Each has a wear-off trigger that auto-recasts: `send("c 'detect invis'")` etc.

**Protection**: Armor (auto-recasts on wear-off), Shield (routes to History), Stone Skin (routes), Sanctuary (routes), Cancellation, Dispel Magic, Fireproof, Proximity Dispel, protection variants — cosmetic/routing.

**Transportation**: Fly (auto-recasts `send("c fly")` on wear-off), Gate (routes), Pass Door (routes).

**Enhancement**: Giant Strength, Infravision, Refresh, Light Foot, Water Breathing, Haste — cosmetic highlights. Haste success routes to History; slow-down routes and re-casts Haste? (no explicit resend for Haste wear-off found).

### Group: Weather Conditions
Rain, Lightning, Breeze (cold/temperate/warm), Wind (temperate/warm moderate), Snow — all `Route.to("History")`.

---

## 3. Aliases

### Third-party package aliases (pass-through)

| Group | Commands | Purpose |
|---|---|---|
| enable-accessibility | `mudlet access(ibility)? on/reader` | Mudlet a11y setup |
| deleteOldProfiles | `delete old profiles/maps/modules [days]` | Profile cleanup |
| run-lua-code | `lua <code>` | Inline Lua evaluation |
| echo | `` `echo/cecho/decho/hecho <text>`` | Echo variants with `$` as newline |

### generic_mapper aliases

**Setup**: `map show`, `find prompt`, `map prompt`, `map ignore`, `map movemethod`, `map debug`, `map update`, `map config`, `map window x/y/w/h`, `map translate`

**Information**: `map basics`, `map help`, `map rooms`, `map areas`, `rf/room find`, `rl/room look`, `showpath`, `spe list`, `feature list`

**Regular use**: `map me`, `map path`, `map recall`, `map character`, `map stop`, `mpp on/off` (speedwalk toggle), `arealock`

**Map creation**: `set area`, `start/stop mapping`, `shift`, `add portal`, `show/clear moves`, `add door`, `merge rooms`, `map mode`, `set exit`, `rc/room coords`, `rld/room delete`, `rw/rwe` (weights), `rlk/room link`, `urlk/room unlink`, `rd` (doors), `rcc` (room char), `spe/spev/spe clear` (special exits), `room area`, `room label`, `area labels`, `area add/delete/cancel/rename`, `feature create/add/delete`

**Map sharing**: `map save/load`, `map import/export`

### EMCOChat aliases

| Command | Action |
|---|---|
| `emco save/load/font/fontSize/blink/blankLine/timestamp/show/hide` | EMCO config |
| `emco gag/ungag/gaglist` | Line gag management |
| `emco notify/unnotify` | Tab notification toggle |
| `emco addtab/remtab` | Dynamic tab management |
| `emco color [tab] [color]` | Tab color config |
| `emco usage` | Help |
| `emco update` | Self-update via mpackage |
| `emco title/lock/unlock` | Window title/lock |

### MyDSL Audit Phase aliases (from previous Claude sessions — all debug/inspection only)

These are residual from prior auditing work. All follow the pattern `mydsl <phase> <command>`:

- **Phase 2A–C**: `mydsl targetstate`, `mydsl ts` — TargetState status/verify/save
- **Phase 3**: `mydsl phase3 *`, `mydsl targetapi *`, `mydsl apiuse *`, `mydsl tsapi *`
- **Phase 4**: `mydsl rhapi *`, `mydsl tapi2rh *`
- **Phase 5**: `mydsl targetwrite *`
- **Phase 6A**: `mydsl targetcycle *`
- **Phase 7**: `mydsl clickbridge *` (dry-click, exec-click, compare, enable/disable)
- **Phase 8**: `mydsl clickbridge mode/enable/disable/phase8 verify/save`
- **Phase 9**: `mydsl phase9 *` — consolidation report
- **Phase 10A/B/C**: `mydsl phase10 *`, `mydsl phase10b *`, `mydsl phase10c *`
- **Phase 11C**: `mydsl rhdisplay *` — RightHere display source bridge

> **Gap**: These 60+ audit aliases are from the prior multi-session audit that built and verified the current stack. They call modules (`MyDSL.Phase3`, `MyDSL.TargetAPI`, etc.) that are still loaded. They are debug artifacts — not part of the live UI. No cleanup has been done.

---

## 4. Timers

**None defined.** The TimerPackage in autosave.xml is empty. All timing in this profile is handled by Mudlet's `tempTimer` API called from within Lua scripts (e.g., AffectsView uses `0.25s` staggered delays for recast commands; TickView has an internal polling loop via `MyDSL.TickSource.loop`).

---

## 5. Scripts (autosave.xml ScriptPackage)

### Third-party packages

| Script | Lines | Purpose |
|---|---|---|
| deleteOldProfiles script | 60 | Cleans old profile/map/module backups |
| workaround for add | 11 | Patches `Adjustable.Container:add` for gui-drop |
| createDropManager | 48 | GUI drag-drop manager factory |
| Global Variable Functions | 21 | `GUIDropManager.getKeyFrom` utility |
| createDropScript | 11 | Installs drop handler script if missing |
| ImageDrop | 68 | Handles image file drops onto containers |
| AdjustableContainer Additions | 69 | Adds setDropImg, convertToLabel, saveAll to AC |
| Mudlet Package Manager CLI (mpkg) | 512 | CLI package manager; installs from repo |
| Semantic Versioning (semver) | 175 | Semver library for mpkg |
| Map Script (generic_mapper) | 3860 | Full generic mapper — room tracking, speedwalk, area management |
| EMCOChat Code | 115 | Creates EMCO chat window + tab configuration |

### MyDSL Core Stack (Alpha 1 Reset Quiet Live, v4C series)

| Script | Lines | Namespace | Purpose |
|---|---|---|---|
| 00 MyDSL.AlphaCore v1 Quiet | 17 | `MyDSL.Alpha` | Version marker, verbose flag |
| MyDSL.SourceCore v4B6 | 1425 | `Source`, `Settings`, `Events`, `State`, `Gate` | Data foundation: GMCP ingestion, text parsers, DB record management, coverage tracking, debug tools |
| MyDSL.SourcePack.Items v4B3 | 654 | `Pack` (items) | Inventory, equipment, identify, shop, skills parsers; item DB upsert/search |
| MyDSL.SourcePack.People v4B6 | 718 | `Pack` (people) | Who, players near, local sight, whois parsers; people DB upsert/search |
| MyDSL.SourcePack.Combat v4B4 | 577 | `Pack` (combat) | Combat event parser: target tracking, death, attacks, skills, spells |
| MyDSL.RouteCore v4C3 | 242 | `MyDSL.Route`, `R` | Text routing layer; defines named windows (History, Combat, Scan, Group, Players, Target, Info); `R.route`, `R.to`, `R.history` |
| MyDSL.RouteBindings v4C2 | 313 | `B` | Trigger-based routing: installs live triggers for scan/group/players blocks; combat line routing |
| MyDSL.DBAudit v4C4 | 564 | `A` (audit) | Read-only inspection: status dashboards for all DB sections, routes, windows, target, scan, group |
| 040 MyDSL.LayoutCore v4C1 | 172 | `MyDSL.LayoutCore`, `L` | UserWindow position/size persistence; save/load/autoload on boot |
| 05 MyDSL.WindowCore v4C12 | 584 | `MyDSL.Windows`, `W` | Window registry; `ensure`, `appendText`, `appendCecho`, `copyCurrentLine`, `clear`, font/wrap/title/timestamp setters |
| 17 MyDSL.StatusSource v4C6 | 410 | `S` (status) | GMCP char/login/tick handlers; score text parser; time/improve line parsers; prompt fallback |
| MyDSL.SourceViewBridge v4C5 | 558 | `B` (bridge) | Bridges SourceCore DB into view layer: group, where, scan block parsing; raises `scanUpdated` event |
| 150 MyDSL.PortraitView v4C4 | 811 | `MyDSL.Portrait`, `P` | Portrait window: per-character image path management, HTML label rendering, cover/missing fallback |
| 160 MyDSL.LocationView v4C3 | 681 | `MyDSL.Location`, `M` | Room picture window: canonical path lookup (room name → file), mapper integration, profile map |
| 20 MyDSL.TickSource v4C1 | 218 | `MyDSL.TickSource`, `T` | Tick timing authority: GMCP tick handler, internal 1s loop, average tick calculation, publishes tick events |
| 23 MyDSL.LiveView v1A14 | 640 | `MyDSL.LiveView`, `L` | Live panel: room name + sector, exits bar (MiniConsole), vitals bars (HP/Mana/MV), time/XP display |
| 21 MyDSL.TimerSource v4C1 | 228 | `MyDSL.TimerSource`, `TS` | Countdown source: computes tick/improve/affects/world-time remaining; internal 1s loop |
| 12 MyDSL.ChatWrapper v4C11 | 544 | `MyDSL.Chat`, `C` | EMCO integration: creates MyDSL_Chat UserWindow, creates EMCO inside it, configures tabs, font/wrap/timestamp settings |
| 13 MyDSL.AffectsView v4C16 | 934 | `MyDSL.Affects`, `A` | Affects window: GMCP sync, text capture fallback, per-character persistence, tracked list, auto-respell/spellup, clickable links, column display |
| 22 MyDSL.TickView v4C5 | 351 | `MyDSL.TickView`, `V` | Tick countdown tube display; compact/full mode; renders seconds + detail |
| 99 MyDSL.AlphaSummary v1 Quiet | 44 | `MyDSL.Alpha` | `Alpha.check()` / `Alpha.status()` — verifies all modules loaded |

### MyDSL Add-on Scripts

| Script | Lines | Namespace | Purpose |
|---|---|---|---|
| 150 MyDSL.TargetRightHere v4C32 | 2410 | `T`, `RH`, `V` (target), `TC`, `CDB` | Combined: Target window (current target info), RightHere window (scan mob list, clickable), creature lore DB, combat target tracking, visual HP/MP gauges |
| 160 MyDSL.CreatureReferenceWindow v1 | 386 | `MyDSL.CreatureReference`, `CR` | Standalone creature lookup window; patches TargetCompact for open-on-click |
| 171 MyDSL.BattleCondenser v1H | 527 | `MyDSL.BattleCondenser`, `BC` | Combat output condenser: writes to existing Combat window, tracks kill XP/drops/averages, target HP priority display |

### Audit Phase Scripts (prior session artifacts — debug only)

| Script | Lines | Namespace | Purpose |
|---|---|---|---|
| Phase2A–C | ~750 | `MyDSL.Compat`, `MyDSL.StatusTruth`, `MyDSL.TargetState` | Target/status compatibility layer verification |
| Phase3A–C | ~683 | `MyDSL.TargetAPI`, `MyDSL.APIUse`, `MyDSL.TargetStateAPI` | API surface mapping and equivalence checks |
| Phase4A–B | ~523 | `MyDSL.RightHereAPI`, `MyDSL.TargetAPIUsesRightHereAPI` | RightHere API verification |
| Phase5A–C | ~869 | `MyDSL.TargetWriteAPI` | Target write API dry-run and execute verification |
| Phase6A | 275 | `MyDSL.TargetWriteCycle` | Write-cycle verification |
| Phase7A–C | ~837 | `MyDSL.ClickBridgeAudit` | Click bridge audit, dry/exec |
| Phase8A | 267 | `MyDSL.ClickBridgeAudit` | Click bridge opt-in |
| Phase9 | 242 | `MyDSL.Phase9` | Consolidation report |
| Phase10A/B/C | ~341 | `MyDSL.Phase10`, `.Phase10B`, `.Phase10C` | Rollup/install-order/smoke-test |
| Phase11C | 263 | `MyDSL.RightHereDisplayAudit` | RightHere display source bridge audit |
| TestBatchAliases | 166 | `MyDSL.TestAliases` | Batch test runners for phases 2–8 |

---

## 6. Key Functions by Module

Functions are local helpers unless prefixed with their module namespace.

**MyDSL.SourceCore** — `Source.boot`, `Source.ingestLine`, `Source.parseGMCPChar/Room/Tick/Affects`, `Source.finishRoomdesc`, `Source.publishRoomdesc`, `Source.findCreature/Item/Person`, `Source.save/load`, `Gate.isFighting/isSleeping/canAct`, `Events.on/emit`, `Settings.get/set/save/load`

**MyDSL.RouteCore** — `R.route`, `R.to`, `R.history`, `R.combat`, `R.scan`, `R.group`, `R.players`, `R.target`, `R.setGag`, `R.setEnabled`, `R.status`

**MyDSL.WindowCore** — `W.ensure`, `W.appendText`, `W.appendCecho`, `W.copyCurrentLine`, `W.clear`, `W.setFont`, `W.setWrap`, `W.setTitle`, `W.setTimestamp`, `W.normalizeId`, `W.list`, `W.status`

**MyDSL.AffectsView** — `A.syncGmcpFull`, `A.gmcpAdd`, `A.gmcpRemove`, `A.recast`, `A.spellup`, `A.display`, `A.track/untrack`, `A.save/load`, `A.install`

**MyDSL.TargetRightHere (TC)** — `TC.setCombatTarget`, `TC.setCondition`, `TC.setBattleHP`, `TC.parseLoreLine`, `TC.parseCombatLine`, `TC.renderTarget`, `TC.renderRightHere`, `TC.creatureLookup`, `TC.installTriggers`, `TC.install`; `CDB.search`, `CDB.lookup`, `CDB.describe`, `CDB.print`, `CDB.loadLearned/saveLearned`

**MyDSL.BattleCondenser** — `BC.parseLine`, `BC.parseCondition`, `BC.parseCombatTarget`, `BC.finalizeKill`, `BC.appendCombat`, `BC.installTriggers`

**MyDSL.TickSource** — `T.onGameTick`, `T.loop`, `T.publish`, `T.setAverage`

**MyDSL.TimerSource** — `TS.computeTick/Improve/Affects/WorldTime`, `TS.update`, `TS.loop`

**MyDSL.LiveView** — `L.render`, `L.setBar`, `L.setBarPercent`, `L.setColoredExitsFromCurrentLine`, `L.ensureUI`, `L.boot`

**MyDSL.PortraitView** — `P.pathForName`, `P.setPath`, `P.renderImage`, `P.renderMissing`, `P.refresh`, `P.init`

**MyDSL.LocationView** — `M.roomData`, `M.pathForRoom`, `M.render`, `M.refresh`, `M.mapRoom`, `M.boot`

**MyDSL_DataLayer.lua** (standalone, not in autosave.xml) — `MyDSL.get`, `MyDSL.set`, `MyDSL.on`, `MyDSL.emit`, `MyDSL.save`, `MyDSL.load`, `MyDSL.restoreChar`, all `beginX/parseXLine/endX` parser pairs for score, flags, lunar, time, weather, who, whok, whoc, group, unread, inv, map, affects-text, improve

---

## 7. Data Flow

```
Game server
    │
    ├─ GMCP packets ──────────────────────────────────────────────────────┐
    │   char_data, login_data, room_data,                                  │
    │   affect_data, add_affect, remove_affect, tick                       │
    │                                                                      ▼
    │                                              MyDSL_DataLayer.lua (Layer 1)
    │                                              MyDSL.State[section] updated
    │                                              MyDSL.emit(section) → raiseEvent
    │                                                     │
    │                                              MyDSL.SourceCore (parallel GMCP handler)
    │                                              Source.parseGMCPChar/Room/Tick/Affects
    │                                              → SourceCore DB (in settings.lua)
    │
    ├─ Text output ───────────────────────────────────────────────────────┐
    │                                                                      │
    │   ┌─── Triggers fire on matched lines ────────────────────────────┐  │
    │   │                                                               │  │
    │   │  Chat channels ──────► demonnic.chat:append(tab) ──────────► MyDSL_Chat (EMCO)
    │   │  + deleteLine() for OOC/gossip/auction                        (tabs: Tells/OOC/City/Local/Group)
    │   │
    │   │  Notifications ───────► MyDSL.Route.to("History") ──────────► History window
    │   │  (broadcasts, arrives,   (copies current line to window)
    │   │   portal transitions,
    │   │   kills, toasts,
    │   │   weather, moon, day,
    │   │   quest events)
    │   │
    │   │  Combat lines ────────► RouteBindings.combatLine() ─────────► Combat window
    │   │                         BattleCondenser.parseLine()            (via WindowCore)
    │   │
    │   │  Scan output ─────────► RouteBindings.scanLine() ────────────► Scan window
    │   │                         SourceViewBridge.scanLine()             (via WindowCore)
    │   │                         → raises "scanUpdated" event
    │   │                         → RightHere window updates
    │   │
    │   │  Group output ────────► RouteBindings.groupLine() ────────────► Group window
    │   │                         SourceViewBridge.groupLine()             (via WindowCore)
    │   │
    │   │  Players Near ─────────► RouteBindings.playersLine() ──────────► PlayersNearYou window
    │   │
    │   │  Auto-drink/eat ───────► send() commands (thirst/hunger)
    │   │  Spell wear-off ───────► send() recast commands
    │   │  Improve ─────────────► send("improve")
    │   │  Night begins ─────────► send("lunar")
    │   │  Day begins ──────────► send("who")
    │   │
    │   └───────────────────────────────────────────────────────────────┘
    │
    └─── Everything else stays in main console (untouched)

Display windows update from:
  MyDSL_Live     ← GMCP room_data + char_data + time/XP events
  MyDSL_Tick     ← TickSource 1s loop (from GMCP tick timing)
  MyDSL_Affects  ← GMCP affect_data/add_affect/remove_affect + text fallback
  MyDSL_Portrait ← per-character portrait path (set manually per char)
  MyDSL_Location ← room name → image file lookup on room data events
  MyDSL_Target   ← combat target events + scan click events
  MyDSL_RightHere← scan output (via SourceViewBridge scanUpdated event)
```

---

## 8. Gaps and Issues

### Critical

1. **MyDSL_DataLayer.lua is loaded from where?** The file exists on disk (`/MyDSL_DataLayer.lua`, 959 lines) but there is **no trigger, script, or alias in autosave.xml that loads it**. It is not `require()`d anywhere visible. It will not execute unless it is manually added to Mudlet's Script editor as a script. If it exists only as a standalone file, it is currently inert.

2. **Duplicate GMCP handlers** — `MyDSL_DataLayer.lua` and `MyDSL.SourceCore` both install GMCP handlers for the same branches (`char_data`, `login_data`, `room_data`, `affect_data`, tick). They will both run, storing data in different structures (`MyDSL.State` vs. SourceCore's `Source.db`). The rest of the UI stack (WindowCore, TargetRightHere, etc.) reads from SourceCore's DB, not from `MyDSL.State`. The DataLayer's data is currently unused by any display module.

3. **Moon bonus triggers are hardcoded string patterns** — 7 exact strings for specific moon bonus combinations. Any bonus combination not in that list will not match. These should be a regex pattern capturing the bonus values.

### Moderate

4. **60+ audit phase aliases/scripts still loaded** — Phases 2–11 from the prior audit process remain active in autosave.xml. They consume namespace, load time, and alias slots. Modules like `MyDSL.TargetAPI`, `MyDSL.ClickBridgeAudit`, `MyDSL.Phase9`, etc. are live in memory. None are harmful, but they are dead weight.

5. **Duplicate alias definitions** — `mydsl targetstate`, `mydsl targetstate status`, `mydsl targetstate verify`, `mydsl targetstate save`, `mydsl status target`, `mydsl ts` appear **twice** in autosave.xml (once in Phase 10A group, once in Phase 3 group). Mudlet will fire both.

6. **`is DEAD!!` has three duplicate triggers** — "is DEAD!! Scan", "is DEAD!! Get all for food", and the one in Combat group. All three match the same pattern. Only the Combat group one has meaningful action (`MyDSL.Route.history()`). The first two have no script.

7. **Hunger/thirst automation sends commands** — This violates the "passive observation" design principle in DSL_UI_Philosophy.md. The thirst trigger sends `drink decanter` twice and the hunger trigger sends `c 'create food'`. These are active automations, not passive observation. Worth flagging for the planning session.

8. **Spell auto-recast** — Bless, Detect Invis, Detect Magic, Detect Hidden, Detect Evil, Detect Good, Armor, Fly all auto-recast on wear-off. Same principle violation as above — these are active automations. They are functional but conflict with the documented design philosophy.

9. **`LocationView` uses absolute pixel position** (`x=740px, y=80px`) instead of percentage positioning. This will break at non-1920×1080 resolutions.

10. **`arrived` trigger does `send("look")`** — active command, philosophy violation. Also appends `[Opportunity]` to main console which may not be desirable.

### Minor

11. **`MyDSL_Live` footer labels** — `x=32%` hardcoded for the outer UserWindow position. If the window is moved by the user, the internal Geyser children use percentages relative to the window (correct), but the window's own default position is hardcoded and only overridable via saved settings.

12. **`generic_mapper` is installed but DSL likely doesn't have a walkable map** — the mapper is configured and aliases exist, but DSL's room structure may not be mappable via standard exit triggers. The `mHaveMapperScript = true` flag in autosave.xml suggests a mapper script is active.

13. **`---Highlight 1 word` and `capture 2 items in the line`** — both disabled, left over from tutorial/example triggers. Cosmetic clutter.

14. **No timer-based periodic actions** — There is no scheduled "refresh" for Who, Score, Lunar, Weather, etc. The system depends entirely on natural game output triggering updates. If a player never types `score`, the score section of `MyDSL.State` stays at `last_updated=0`. This is by design (Principle 6) but means some windows may always show stale/empty data during a session.

15. **`MyDSL.SourceCore` and `MyDSL_DataLayer` both have `deregisterHandlers` / handler ID management** — if both are installed, they each manage their own handler IDs independently and cannot deregister each other's handlers. A profile reload could accumulate duplicate GMCP listeners from both systems.

# MyDSL Idea Backlog
*Absorbed from `~/Downloads/aistuff.txt` (Steven's running idea dump) on 2026-07-05.
Raw, unscoped, uncommitted-to. This is a running list per Steven's instruction —
"keep a running list but don't action unless pertinent." Nothing here is
started unless it also appears in `TODO.md`. Add new ideas here directly going
forward instead of a separate scratch file.*

---

## Display / window features

- RightHere window should update on more than scan: walks in/out, runs in/out,
  floats in/out, flies in/out, arrives/portals, etc.
- Night/day picture variants for LocationView; weather effects on the location
  image (falling particles for rain/snow); weather icon column in the
  Moon/Weather widget (wind, rain, snow icons), vertical on the left side,
  present if seen this update, blank if not.
- Quest widget — items and location, maybe a route/path hint to the room.
- Add room data as an optional mapper-window display.
- Move most scraped main-console info to its own window via `appendBuffer()`
  (keep in-game text color) instead of leaving it in main console.
- `cecho` for notification banners.
- `cechoPopup` for the murder/heal button swap on TargetView (see "murder
  changes to heal" idea below).
- Map room borders as directional warning indicators — thicker/colored border
  if there's a warning in that direction, standard otherwise.
- Toolbars for buttons.
- Suffix-style item stats display instead of appending a `cecho` block.
- Text wrap in all windows, like EMCO already does.
- `map 15` transparent silent-updating window, top right, ASCII terrain map.
- Banner/announcement window — e.g. entering Gahboom throws a banner "get some
  ear plugs, it's loud."
- Outdoor forest background art.
- Configurable button row (up to 4) for infrequent commands (weather, map,
  areas, etc).
- Stats display current + boosted, e.g. `str 60(67)`.
- Sanctuary indicator, maybe haste/protection too.
- Improve-in-progress indicator.
- Inventory window, Equipment window, Disarm indicator.
- Item collector — log every item picked up + where, build an item/mob
  database as you go (ties into the reference-library ideas below).
- AGL viewer as its own window, watching alongside the battle condenser.
- Del Nechi gets its own text box.
- Chat text fades after 30 minutes.
- Bloodbath as a pop-out window.
- Eq/Inv minimize to a button, expand to a window.
- Per-context feature toggles: turn off AGL features, turn off Combat
  features, flags to prevent certain actions while in combat/AGL.
- Panic-command aliases, all starting with `~` (tilde).
- Test room-card rendering with an unusually long room name.
- Tab RightHere/chat/inventory/scan together.
- Silent auto-refresh of score/time/inv/eq at login (maybe just score+time;
  eq/inv should persist across sessions instead).
- Target gauge/mini-console popup with mob info, upgradeable from mob list.
- Pop-up windows for choosing what to drink/eat/quaff (potion, wand, staff).
- In-game guide (not a website) — want reference material inside the client.
- Pop-up window linking the main DSL website; DSL web-links header bar
  (forums, items, Shattered, AGL, Discord, other community links) as a
  dropdown.
- Disarm/malediction/poison status pop-ups that fade; persistent-but-fading
  affect alerts; low-HP border flash ("you sure are bleeding").
- Unhorsed-flee-mount / dead-horse-flee-and-mount handling; stun action timer
  or duration sound cue.
- "Walks in" popup, emphasis on known players / dragons / giants / angels.
- Room-item window (what's actually on the ground here).
- Down-the-road ambient sound — musical instruments playing over a "radio"
  channel.
- Unread-notes indicator.
- Room-description window.
- Audit that our capture scripts never *modify* main-console lines — only
  remove text we intentionally relocate; anything "injected" should be a
  disappearing label or routed to History, not left looking like it modified
  the original line.
- Autowhere/history/command-response as popups, split so others' output is on
  one side and yours on the other.
- Move text around so emotes/actions stay visible without scrolling past
  spam.
- Repetitive messages (food/drink/spell-up spam) get relocated like combat
  does.
- Duplicate text stacked as "×3" the way the battle condenser already
  collapses repeats.
- Global per-module/per-window "turn off" toggle.
- Command button bar at top; social/emote command buttons at bottom; buttons
  are generic when no target is set, use the active target when one exists.
- Auto-cast toggle button (with an active-state light) for a spell/skill —
  watches sleep/combat state before firing.
- Target damage-noun display.
- `murder` configurable for waylay or other opening actions instead of always
  a straight attack.
- `murder` auto-swaps to `heal` based on a friend/enemy/neutral flag per
  player — default neutral, can be flagged friend or enemy; enemy-flagged
  players who attack you should auto-flip to enemy. **Flagged 2026-08-23
  (Claude.ai review pass): this is a meaningfully different shape than
  every other assist in this project.** Spellup reminders, disarm
  alerts, autowhere — all of those help the player decide faster but
  never change what the player typed. This one would send a DIFFERENT
  real command than the one the player actually typed, based on a flag
  they may not be actively thinking about at that moment. Needs an
  explicit Steven sign-off before ever being scoped, the same way the
  Leveling/Questing automation exception got one — not assumed covered
  by "reasonable UI convenience" just because it's alias-level.
- Consider shortening the DB keyword used for `murder`/`consider` — some mob
  names are too long for reliable keyword matching (e.g. "a horribly
  disfigured blue jay, right here").
- "Improve" queue needs a next-in-queue view; currently requires a manual
  click.
- `mydsl window <name>` should print help for that window's own options.
- GMCP enabled/disabled indicator.

## Mapper

- AI-assisted room-drawing tool for the mapper — draw/color rooms to look
  like wilderness.
- Modify `generic_mapper`; also look at the "Ire" mapper for ideas.
- "Cork compass" maze-mapping quest idea — hints toward its location, need
  multiples to fully map a maze area.
- Path highlighter — bolder/thicker border the more a room has been visited.

## Reference library / database (Layer 4 territory)

- Item database + mob database, populated as you encounter things; identify
  new items via creaturelore, open an editable window, submit to Shattered
  for validation.
- Quest-item auto-pickup: pattern-match "quest master name gives you a quest,"
  stay active until quest done/failed, highlight the right item to grab.
- Book-copier alias: `read book <page#>` copies the text into your own
  journal/reference library.
- Terminology glossary for in-character terms (e.g. "triggers" ↔ "contingency
  spells").
- Oathbound-journal org-info manual; first quest is finding a quest master,
  second is a Dracon.
- Census (DSL color census) should only record "last seen" when a player
  actually passes through your room, not just from `who` — otherwise it's
  just counting how often `who` was run.
- Friends list — add friend, populate from `who`, highlight friends/enemies.
- Recommended gear + leveling guide by class, broken out by level bracket
  (5/10/25/35/45).
- Age alias — current age from score creation date + approximate Algoron
  time, with a confidence percentage; separate script to track DSL year
  length and remind you of in-game birthdays, auto-incrementing age.

## RP / social / immersion

- Emote/pmote/tmote lesson generator — have AI draft a dozen example rituals
  (e.g. a daily Cleric-I ritual, thirst/hunger flavor emotes).
- RP-journal-keeping lesson.
- Daily "storynote" writing practice.
- Custom in-character constructed language ("Serpantol" or similar).
- Subtle in-world lore clues/hidden messages (example fragment logged:
  "...SEEK OUT VAELIS").
- Easter eggs.
- Newbie module to walk new characters through mud school + RP/emote lessons.
- Custom socials — button/alias for emotes and says.
- Discord integration for musical notes; "group maps" (shared map view)
  flagged with real enthusiasm ("for the love of god, group maps!!!!").

## Combat / character mechanics research

- Track stat changes from level 1 as a human, to understand stat scaling.
- Correlate drink/food usage with hunger/thirst-per-tick to find the actual
  tick-rate relationship.
- Vrokt quote logged for reference: "Your muscles twitch as they re-energize
  from the poison." — tied to an idea about poison auto-becoming the
  selected target.
- Terrain-based footstep sounds on movement keys (snow/grass/mountain/etc).
- Flying/landing triggers to set an `imFlying` flag, then have the movement
  keybind play `characterflapping.mp3` when flying / `characterwalk.mp3`
  when not. (This is what those two loose `.mp3` files at the profile root
  are for — not orphaned assets, they're waiting on this trigger wiring.)

## Research questions (for a future "have AI summarize this" pass)

- Mudlet MSP sound support — summarize play/pause/stop options and realistic
  usage scenarios.
- `roomUserData` and room naming — research + ELI5 summary.
- `setRoomChar` — look at a font package to support it.
- `setRoomEnv` — possible connection to the `terrain` command.
- Mudlet Lua UI functions (wiki: Manual:Lua_Functions#UI_Functions) — build a
  worked-example tutorial trying each one in-game.
- Mudlet supported protocols (wiki: Manual:Supported_Protocols) — same
  treatment.
- Can Mudlet capture/color-match everything on the main screen and reproduce
  it exactly (CSS/HTML) for a fully theme-able window system?
- Do item prices/data sync across different game clients?
- Confirm whether there's a way to double-check/validate a room via
  `roomIsByHash` (hash-based room identification).

## Personal / game notes (not project scope — kept for continuity only)

- In Nereza's most recent retrain: averaged 21.1 mana/level as a mage, 17.88
  as an enchanter. Most leveling was done during a full moon.
- Kien should practice portals and make them at Grey Church for low-level-area
  nexuses.

# DSL PNP Package — Reference Summary
Source: PNP.zip (Desktop copy, dated 2025-05-25 / 2025-07-03 for Chat).
This is a read-only reference for understanding the PNP system before Layer 2 work.

---

## Window_Manager.lua
**v2.00c — Zachary Hiland**

A coordinate math and layout engine for Mudlet windows. All measurements support mixed percent+pixel strings (e.g. `"25% + 50px"`). Registered windows are stored in `windowManager.list` and automatically repositioned on `sysWindowResizeEvent`. Supports labels, miniConsoles, gauges, menus, and "autowrap" miniconsoles (which maintain a shadow buffer to reflow text on resize). This is the foundational layout primitive used by all PNP sidebar panels.

**Public API:**
- `windowManager.list` — table of all registered windows and their layout info
- `windowManager.create(name, type, x, y, w, h, origin [, font])` — creates and registers a new window (label/miniConsole/gauge/mapper/menu/autowrap)
- `windowManager.add(name, type, x, y, w, h, origin [, font])` — registers an already-created window without creating it
- `windowManager.remove(name)` — deregisters a window from the manager
- `windowManager.move(name, x, y)` — moves a registered window and saves new position
- `windowManager.resize(name, w, h)` — resizes a registered window and saves new size
- `windowManager.relocate(name, origin)` — changes which corner (topleft/topright/bottomleft/bottomright) is the positioning origin
- `windowManager.show(name)` — shows a registered window (handles mapper specially via `createMapper`)
- `windowManager.hide(name)` — hides a registered window (hides mapper by creating 0×0)
- `windowManager.refresh(name [, main_w, main_h])` — recalculates and applies pixel positions from stored percent/pixel values
- `windowManager.refreshAll()` — refreshes all registered windows; called automatically on `sysWindowResizeEvent`
- `windowManager.getValue(name, value)` — returns calculated pixel value for `x`, `y`, `width`, or `height`
- `windowManager.math(measure, num, op)` — arithmetic on mixed measurements (add/subtract/multiply/divide)
- `windowManager.simplify(measure)` — collapses a compound measurement string to canonical form
- `windowManager.makeBuffer(name)` — creates the shadow buffer for an autowrap window
- `windowManager.append(name)` — appends current buffer line to an autowrap window and its buffer
- `windowManager.echo(name, text)` — echoes to an autowrap window and its buffer
- `windowManager.cecho(name, text)` — color-echo to an autowrap window and its buffer
- `windowManager.decho(name, text)` — decho to an autowrap window and its buffer
- `windowManager.hecho(name, text)` — hecho to an autowrap window and its buffer
- `windowManager.clear(name)` — clears an autowrap window and its buffer
- `windowManager.setFontSize(name, font_size)` — sets font size for an autowrap window

---

## DSL_PNP_Sidebar.lua
**v4.00e**

Manages a three-section sidebar (`top`, `middle`, `bottom`) that divides the right or top edge of the screen. Each section can display up to two panels simultaneously using tab buttons that users click to switch views. Any module can register itself as a sidebar tab by calling `raiseEvent("onConfig", module_name, section, x, y, width, height, origin)`. The active panel in each section is tracked in `dslpnp.displayed`. Layout and display state are restored after `sysWindowResizeEvent`. Controlled by the PNP event system (`onConfig`, `onToggle`).

**Public API:**
- `dslpnp.sidebar` — namespace table containing per-section geometry (`top`, `middle`, `bottom`) and config
- `dslpnp.displayed` — tracks which panels are currently shown in each sidebar section
- `dslpnp.sidebar.configs` — active configuration (width, position, per-section heights)
- `dslpnp.sidebar.maketab(section, name, text)` — creates a clickable tab label in the given sidebar section; tabs auto-resize to share space equally
- `dslpnp.sidebar.display(name, windows, tab [, extra])` — shows a named panel in its section, hides the previously active secondary panel, and fires `displayWindow` events to position/show its windows
- `dslpnp.sidebar.eventHandler(event, ...)` — handles `onToggle`, `onConfig`, and `sysWindowResizeEvent`

---

## DSL_PNP_Support.lua
**v4.04d**

Utility library providing color handling, text formatting, and command helpers used across all PNP modules. Registers DSL-specific named colors into Mudlet's `color_table`. Defines `{r`, `{G`, etc. color code mapping to cecho tags. Installs several foundational aliases and triggers on `onConfig`: Tab Fix (replaces tab characters), Blank Line, Toggle (`toggle <module>`), Update Package, Initialize, Fix Prompt.

**Public API:**
- `dslpnp.support` — namespace table
- `dslpnp.support.color_codes` — table mapping DSL `{x` color codes to cecho color strings
- `dslpnp.support.debug` — boolean; when true, `dsend` echoes commands instead of sending
- `dslpnp.support.formatLabelText(text, fontSize, center, bold, italic, underline, r, g, b, font)` — wraps text in HTML spans for display in Geyser labels; all formatting params optional
- `dslpnp.support.replaceColors(text [, for_label])` — substitutes DSL `{x` color codes with cecho tags; if `for_label` is true, further converts to HTML color spans
- `dslpnp.support.getAnsiColor(text [, start])` — returns the ANSI color index (0–15) of the first character of a match on the current line
- `dslpnp.support.adjustWordWrap(window, width, font_size)` — recalculates and sets word wrap for a windowManager-managed miniConsole; `width` is optional if window is registered
- `dslpnp.support.wrapLines(text, length [, pad])` — soft-wraps a string to `length` characters per line, with optional hanging indent `pad`
- `dslpnp.support.unpack(tbl)` — converts a key-value table to a flat alternating array
- `dslpnp.support.repack(tbl)` — converts a flat alternating array back to a key-value table
- `dslpnp.support.eventHandler(event, ...)` — handles `onConfig`, `onConfigEnd`, `onToggle debug`, `onTab`
- `dsend(...)` — sends one or more commands; routes through `.v` if the in-game editor is open
- `fprint([window,] text [, wrap])` — prints DSL color-code text to main console or a named window, with optional newline wrapping
- `sendQueue(...)` — sends a sequence of commands with optional delays between them; args are alternating `(delay, command)` pairs
- `getColorWildcard(color)` — returns substrings of the current line that have the given ANSI foreground color index

---

## DSL_PNP_Affects.lua
**v4.02n**

Tracks active spell/song affects and displays them in a miniConsole sidebar panel (`affects_list`). Affect entries are added via the `affectAdd` event, decremented each tick via `onTick`, and removed on expiry via `affectRemove`. Affects approaching expiry (`highlight_time` ticks remaining) are shown in a configurable highlight color. Affect names in the list are clickable to recast (`cast '<name>'`, `sing '<name>'`, or bare command for skills). A "tracked affects" secondary list shows monitored affects that are currently down. Uses `raiseEvent("onAffect", name, duration)` as the public add interface.

**Public API:**
- `dslpnp.affects` — namespace table
- `dslpnp.affects.Active` — boolean; whether the affects module is currently enabled
- `dslpnp.affects.affects_list` — array of `{duration, name}` pairs for currently active affects
- `dslpnp.affects.configs` — active configuration (fontSize, columns, column_width, highlight_time, highlight_color, cast_command, track_location, show_border)
- `dslpnp.affects.songs_list` — list of song names that use `sing` to recast
- `dslpnp.affects.skills_list` — list of skill names that use bare send to recast
- `dslpnp.affects.help` — help text table
- `dslpnp.affects.findAffect(affectName)` — searches active affects list; returns `true, duration` if found, else `false, false`
- `dslpnp.affects.eventHandler(event, ...)` — handles: `onTick` (decrement), `onAffect` (clear/resync), `affectAdd`, `affectRemove`, `affectClear`, `onTrackAffect`, `onToggle`, `onConfig`, `onDisplay`, `onReveal`, `displayWindow`

**Events consumed:** `onTick`, `onAffect`, `affectAdd`, `affectRemove`, `affectClear`, `onTrackAffect`, `onToggle`, `onConfig`, `onDisplay`, `onReveal`, `displayWindow`
**Events raised:** `affectRemove` (on expiry), `affectClear`
**Alias registered:** `track affect <name>` → `raiseEvent("onTrackAffect", name)`

---

## DSL_PNP_Battle.lua
**v4.03h**

Captures and condenses combat output into a `battle_console` miniConsole sidebar panel, with configurable gagging and summarization of damage. On each prompt update (`updatePrompt`), a per-round summary is printed to both the main console and the battle window. All damage, evade, and weapon-flag events arrive via `onCombat`. Tracks damage by attacker→target→weapon noun, calculates damage ranges from verb names (`scratch`→`UNSPEAKABLE`), applies weapon flag abbreviations, and formats output using a configurable `dam_format` / `summary_format` string with `%a/%t/%v/%n/%d/%h/%s/%f/%r/%p` substitution tokens. Also tracks rage mode data (damage taken / vampiric hits) and fires `onRage` on prompts where HP is `???`.

**Public API:**
- `dslpnp.battle` — namespace table
- `dslpnp.battle.Active` — boolean; whether the battle module is enabled
- `dslpnp.battle.configs` — active configuration (offset, fontSize, gag_combat, gag_non_damage, show_damage, show_damage_by_me, show_damage_to_me, show_miss, show_evade, show_flag, show_condition, summarize_damage, dam_format, summary_format, show_border)
- `dslpnp.battle.rage_info` — `{damage, vamp}` table tracking damage received and vampiric hits this round
- `dslpnp.battle.help` — help text table
- `dslpnp.battle.eventHandler(event, ...)` — handles: `onCombat` (damage/evade/flag sub-events), `onCondition`, `updatePrompt`, `onToggle`, `onConfig`, `onDisplay`, `onReveal`, `displayWindow`

**Events consumed:** `onCombat`, `onCondition`, `updatePrompt`, `onToggle`, `onConfig`, `onDisplay`, `onReveal`, `displayWindow`
**Events raised:** `onRage(damage, vamp)` when HP is `???` on prompt
**Triggers installed:** Battle Damage Trigger (regex captures attacker/weapon/verb/target), 8 Condition Triggers, 5 Evade Triggers, 14 Flag Triggers

---

## DSL_PNP_People.lua
**v4.06a**

A persistent player database that collects information from who lists, whois, kingdom/clan rosters, and craft lists. Stores per-character records in `dslpnp.data.people` keyed by lowercase name. Records contain: org_type, org, name, level, race, class, craft, craft_rank, last_seen timestamp. Updated passively whenever who output appears. Other modules query it for ally/enemy/team highlighting and display. Includes `show info/kinfo/cinfo/craft <name>` aliases for offline whois-style lookups.

**Public API:**
- `dslpnp.people` — namespace table
- `dslpnp.people.configs` — active configuration
- `dslpnp.people.rank_list` — list of known kingdom/clan rank strings
- `dslpnp.people.clan_list` — list of known clan names
- `dslpnp.people.king_list` — list of known kingdom names
- `dslpnp.people.showInfo(show, name)` — prints formatted who-style listing for all names matching `name`; `show` is one of `info`/`kinfo`/`cinfo`/`craft`
- `dslpnp.people.addPerson(name, info)` — adds a new person to the database if not already present; `info` table: `{org_type, org, name, level, race, class, craft, craft_rank}`
- `dslpnp.people.removePerson(name)` — removes a person from the database by name (case-insensitive)
- `dslpnp.people.getInfo(name [, info])` — returns full info table for a person, or a single field if `info` key is given
- `dslpnp.people.setInfo(name, info)` — updates one or more fields in an existing person's record
- `dslpnp.people.eventHandler(event, ...)` — handles `onLine` (parses who/whois/roster output), `onToggle`, `onConfig`

**Aliases registered:** `show (info|kinfo|cinfo|craft) <name>`

---

## DSL_PNP_Highlighter.lua
**v4.03c**

Colors player names inline in main console output based on organization membership (clan/kingdom) and manually assigned ally/enemy/team status. Depends on the People module for org data. Enemy names get a configurable suffix sign (default `*`), allies get `+`. Team tags appear in square brackets before the name. Status and team data are stored in `dslpnp.data.highlighter`. The `highlight()` function is called for each game line and does selective text replacement.

**Public API:**
- `dslpnp.highlighter` — namespace table
- `dslpnp.highlighter.help` — help text table (including `set status` and `set team` alias docs)
- `dslpnp.highlighter.changeStatus(clan, status)` — sets ally/enemy/neutral status for a name or organization; toggles between enemy and neutral if status is omitted
- `dslpnp.highlighter.setTeam(name, team)` — assigns a team label (with optional color codes) to a named player; `team = "none"` removes it
- `dslpnp.highlighter.highlight(text)` — scans a line of game output and applies highlighting to any player names found; called from the line event handler
- `dslpnp.highlighter.eventHandler(event, ...)` — handles `onLine`, `onToggle`, `onConfig`, and alias events for `set status` and `set team`

**Aliases registered:** `set status <name> [status]`, `set team <name> <team>`

---

## DSL_PNP_Moons.lua
**v4.00c**

Captures the moon display output (from `l moons` or `lunar`) and prints a forward-projection of the next 8 lunar phase changes for the viewed moon, with both game-tick countdown and real-world clock time estimates. Moon color is captured from `"The (color) moon is (phase)..."` and tick count from the bonus bar line. Phase cycle lengths are hardcoded: black=66 ticks, red=90 ticks, white=108 ticks. Real-time estimates assume a tick length of 42 seconds.

**Public API:**
- `dslpnp.moons` — namespace table
- `dslpnp.moons.Active` — boolean; whether the moons module is enabled
- `dslpnp.moons.help` — help text table
- `dslpnp.moons.eventHandler(event, ...)` — handles `onMoons` (color/phase/time sub-events), `onToggle`, `onConfig`

**Events consumed:** `onMoons`, `onToggle`, `onConfig`
**Triggers installed:** Moons Trigger 1 (moon color/phase line), Moons Trigger 2 (bonus bar with cycles remaining)

---

## Gauges.lua
**v4.00b**

Replaces Mudlet's built-in gauge functions with a custom implementation that stores all gauge state (position, size, value, color, orientation) in `gaugesTable`. Each gauge is three overlapping labels: `_back` (dimmed, full width), `_front` (bright, scaled to current value), and the text overlay. Supports four fill orientations: horizontal (left→right), vertical (bottom→top), goofy (right→left), batty (top→bottom). All standard Mudlet gauge API names are preserved so existing code continues to work.

**Public API (global replacements for Mudlet built-ins):**
- `gaugesTable` — global table of all gauge state keyed by gauge name
- `createGauge(name, width, height, x, y [, gaugeText, r, g, b, orientation])` — creates three labels forming a gauge; color defaults to grey; orientation defaults to `"horizontal"`
- `hideGauge(name)` — hides all three label components
- `showGauge(name)` — shows all three label components
- `resizeGauge(name, width, height)` — resizes back and text labels, recalculates front fill position
- `moveGauge(name, x, y)` — moves all gauge labels and recalculates front fill position
- `setGaugeStyleSheet(name, css [, cssback, csstext])` — applies CSS to front, back, and text label components separately
- `setGaugeText(name, gaugeText [, r, g, b])` — sets displayed text on the gauge overlay label
- `setGauge(name, currentValue, maxValue [, gaugeText])` — updates fill proportion and optionally text; handles all four orientations

---

## Notes for Layer 2

1. **windowManager vs Geyser.UserWindow** — PNP uses `windowManager` (raw `createMiniConsole`/`createLabel` + coordinate math). The existing MyDSL stack uses `Geyser.UserWindow`. These are incompatible layout systems. Layer 2 should not adopt windowManager — it wraps the existing UserWindow windows.

2. **Event bus model** — PNP modules communicate entirely through `raiseEvent` / `registerAnonymousEventHandler`. The key events are: `onConfig`, `onToggle`, `onTick`, `onLine`, `onCombat`, `onCondition`, `onDisplay`, `displayWindow`, `onReveal`, `affectAdd`, `affectRemove`, `onMoons`, `onRage`. Any MyDSL module listening to these events will interact with PNP if both are loaded simultaneously.

3. **`dslpnp` namespace** — All PNP state lives under `dslpnp.*`. MyDSL state lives under `MyDSL.*`. There is no collision at the namespace level, but shared event names (`onTick`, `onLine`, `onCombat`) will be received by both systems if both are running.

4. **Affects model difference** — PNP Affects uses tick-decrement and text-capture (from the `affects` command output). MyDSL AffectsView uses GMCP `affect_data` / `add_affect` / `remove_affect` for real-time sync. The GMCP approach is more accurate and does not drift between ticks.

5. **Battle module** — PNP Battle uses `battle_console` (a raw miniConsole). MyDSL BattleCondenser writes to the `Combat` UserWindow via WindowCore. Same conceptual purpose, different window systems.

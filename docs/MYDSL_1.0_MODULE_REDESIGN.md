# MyDSL 1.0 — Module-by-Module Redesign Pass (Step 3)

Written by Claude Desktop, 2026-08-26, per `docs/MYDSL_1.0_PHILOSOPHY.md`'s
own sequencing ("3. Module-by-module... redesign summaries — for each
module: how it should work under these principles, its on/off surface,
real interconnections, and any new features"). Built strictly FROM
`docs/OPTIMIZATION_AUDIT.md`'s pass-1 findings (all grep-confirmed there
already) plus the philosophy doc's principles — no re-deriving what the
audit already established. Every audit finding cited below was spot-
checked against current source (this session, 2026-08-26) via targeted
grep, not assumed still current: all still real as of commit `76ad4a5`
(nothing in `docs/CHANGELOG.md` between the audit's 2026-08-25 write and
today touches any of the cross-cutting findings below).

**Scope note:** covers every git-tracked `MyDSL_*.lua` file the audit
numbered (39 modules; `MyDSL_state.lua`/`MyDSL_theme_settings.lua`/
`MyDSL_windowfonts.lua` are data files, not logic modules, same
exclusion the audit itself already made). `DSL_Generic_Mapper.xml`
(audit section 10) is out of scope per the task's own "each `MyDSL_*.lua`
module" framing, but its duplicate-GMCP-parsing finding is load-bearing
context for section 1/9 below, so it's referenced, not re-analyzed.
`MyDSL_Login.lua` postdates the audit entirely (built 2026-08-26) — not
in `docs/OPTIMIZATION_AUDIT.md` at all, covered here from this session's
own direct review instead.

**Format per module:** what it should do under 1.0 (one line, from the
audit's "What it does"), **Toggle** (does it have independent on/off per
Principle 2 — Y / Partial / N / N/A for infra that isn't a player-facing
feature), **Connection** (State-direct / Get-Set / `MyDSL.on()` / events-
only / standalone, per Principle 3's decided standard), **Audit flag**
(the specific duplicate-call/perf/connection issue already on record, if
any), **Verdict** (Compliant / Needs a decision / Contradicts 1.0).

---

## Layer 1 — DataLayer split (foundation, hot path)

**1. `MyDSL_DataLayer.lua`** — shared State/event-bus/GMCP-entry
infrastructure everything else depends on. Toggle: N/A (substrate, not a
feature). Connection: this file IS the State-direct standard everything
else should use; also hosts the deprecated Get/Set API (1 real caller,
`MyDSL_MovementSounds.lua`) and `MyDSL.on()` (1 real caller,
`MyDSL_Leveling.lua`). Audit flag: none in this file directly, but its
re-raised `MyDSL.<section>.updated` events are the root cause of finding
1 below. **Verdict: needs a decision** — Principle 3 already decided
"standardize on State-direct + event handlers," which makes Get/Set's
continued existence (1 caller) and `MyDSL.on()`'s (1 caller) open
questions the philosophy doc itself flagged but didn't resolve: delete
Get/Set and port MovementSounds off it, and decide whether `MyDSL.on()`
is worth keeping as a second pattern for just Leveling.

**2. `MyDSL_DataLayer_CreatureLore.lua`** — captures `creaturelore
<keyword>`. Toggle: N/A (Layer-1 capture, not a feature). Connection:
State-direct, self-contained. Audit flag: none. **Verdict: compliant.**

**3. `MyDSL_DataLayer_Combat.lua`** — the full combat-capture pipeline,
hottest file in the addon (24 always-active triggers). Toggle: N/A
(capture layer; the player-facing toggle lives one layer up, in
`MyDSL_CombatView.lua`'s `config.gag/show`, correctly). Connection:
State-direct, soft-checks `MyDSL.CombatView.config`. Audit flag: 24
always-on regex triggers, cited in the doc's own unresolved cross-cutting
question (how many always-active registrations does one incoming line
pay for, project-wide). **Verdict: compliant** — no toggle needed at this
layer, the real open item is the project-wide always-on-trigger count,
tracked as its own follow-up, not a per-module fix.

**4. `MyDSL_DataLayer_ScanLook.lua`** — scan/look/ground-item/
PlayersNear capture. Toggle: N/A. Connection: State-direct + the two
cross-domain-promoted helpers. Audit flag: `isLookFixtureLine()`'s
growing allowlist (9+ patches historically) — already tracked in
`docs/TODO.md`, not re-flagged here. **Verdict: compliant.**

**5. `MyDSL_DataLayer_ItemLore.lua`** — identify/lore/equipment/
inventory/container capture. Toggle: N/A. Connection: State-direct.
Audit flag: none. **Verdict: compliant.**

**6. `MyDSL_DataLayer_PromptVitals.lua`** — score/flags/lunar/time/
weather/who/group/improve + real-time Pos'n/Wimpy/Dragon-Vitality.
Toggle: N/A. Connection: State-direct. Audit flag: `parsePromptLine()`
is the single highest-frequency trigger in the whole addon, with zero
test coverage for the entire domain. **Verdict: compliant on
architecture; the zero-coverage gap on the highest-frequency trigger in
the codebase is worth prioritizing over cosmetic module work once step 6
(verification) comes around.**

**7. `MyDSL_RawCapture.lua`** — opt-in raw-text diagnostic logger.
**Toggle: Y** (`mydsl rawlog on|off`, and it's the model example —
zero-cost while off, trigger only registered while enabled). Connection:
standalone. Audit flag: none (a prior perf issue already fixed
2026-07-19). **Verdict: compliant — cite as the reference example for
what Principle 2 should look like everywhere else.**

**8. `MyDSL_TickSource.lua`** — shared tick-timing authority. Toggle:
N/A (infra everything else's timers key off; player-facing toggle is
TickView's). Connection: events-only, bypasses State by design (sole
authority for `MyDSL.DB.tick`). Audit flag: **`T.loop()` self-
reschedules at 4Hz unconditionally for the entire session regardless of
whether TickView is visible** (cross-cutting finding 4). **Verdict:
contradicts 1.0's spirit even though it's not a "feature toggle" gap per
se** — an unconditional, always-on 4Hz cost with no visibility gate is
exactly the kind of thing "toggleable by default" should prevent one
layer up; needs either TickSource to drop to 1Hz while nothing needs
sub-second precision, or TickView to gate its own render (see #26,
same root cause, connects both ends).

**9. `MyDSL_DataBridge.lua`** — translates `MyDSL.State.*` into
`MyDSL.DB.*` for DSL1-era display modules. Toggle: N/A. Connection:
events-only (11 `registerAnonymousEventHandler` registrations, all
firing the same `sync()`). Audit flag: **the confirmed real double-fire
bug Steven specifically asked this audit to find** — `sync()` runs twice
per `char_data`/`room_data`/`tick` packet (raw GMCP + DataLayer's
re-raised event, 3 of 11 total registrations), refined to "coalesce all
11 into one debounced call" as the real fix (cross-cutting finding 1).
**Verdict: contradicts the performance goal the whole audit was
commissioned to serve** — this is the single highest-frequency confirmed
double-fire in the addon (every combat round) and should be the first
item on the interconnection-optimization pass (step 4), not deferred
further.

---

## Layer 1 — standalone capture/assist modules

**11. `MyDSL_PromptSetup.lua`** — one-click prompt setup for new
characters. Toggle: N/A (one-shot setup action + a manual re-apply
alias, not an ongoing feature). Connection: standalone. **Verdict:
compliant.**

**12. `MyDSL_AutoWhere.lua`** — state-aware periodic `where` polling.
**Toggle: Y** (`autowhere on|off|status`). Connection: State-direct +
soft `CharacterAssist.checkVision()` reuse. Audit flag: the file's own
header still flags an **unresolved manual step** — Steven's native
`(autowhere)` alias needs disabling by hand in Mudlet's Alias Editor, or
this double-fires against it. **Verdict: needs a decision** — worth
Steven confirming during this pass whether that manual step was ever
actually done; if not, this is a live double-timer bug hiding behind a
doc note, not just a documentation gap.

**13. `MyDSL_PromptView.lua`** — prompt-gag toggle state owner (actual
gagging lives in 2 native triggers this file doesn't create). **Toggle:
Y** (`mydsl prompt on|off|toggle`). Connection: State-direct (own
per-character file) + `MyDSL.login.updated` event. Audit flag: none —
unusual design (state in script, action in native triggers) but
deliberate and documented. **Verdict: compliant.**

**14. `MyDSL_MovementSounds.lua`** — movement-key sound selector.
**Toggle: Partial** — `cfg.enabled` exists and is checked at runtime, but
this session's spot-check (grep) found **zero alias exposing it** — the
flag can't actually be set to false by a player today, same class of
finding as the already-flagged `MyDSL.MoveSound.status()` having zero
callers. Connection: **the one and only real caller of the deprecated
Get/Set API project-wide** (audit section 1/14 cross-reference).
**Verdict: contradicts 1.0 on two counts** — (a) Principle 2: the
toggle mechanism exists in code but isn't reachable by the player, so in
practice this feature has no real on/off; (b) Principle 3: this is the
literal single holdout still calling `MyDSL.get()` instead of reading
`MyDSL.State` directly, the one file blocking a clean deletion of the
deprecated API. Both are small, mechanical fixes once Steven confirms
he wants them.

**15. `MyDSL_CreatureLore.lua`** — Layer 4 persistent creature-lore DB.
Toggle: N/A (a passive DB, not a feature with a UI to hide; the display
side, `MyDSL_CreatureReference.lua`, is what's toggleable). Connection:
standalone (own save file). Audit flag: none — one of the most cleanly-
wired modules in the audit. **Verdict: compliant.**

**16. `MyDSL_Roller.lua`** — character-creation stat-reroll assistant.
Toggle: N/A (character-creation-only, not an ongoing feature to hide).
Connection: standalone. **Verdict: compliant.**

**17. `MyDSL_ChatTriggers.lua`** — routes chat lines to EMCO tabs, gags
the main-console copy for most channels. **Toggle: N** — this session's
spot-check (grep for "enabled"/"toggle" across the whole file) found
**zero occurrences**. There is no way to turn chat routing/gagging off;
`mydsl chat show/hide` (in `MyDSL_Chat.lua`) only hides the *window*, it
doesn't stop `route()` from removing lines from the main console. Audit
flag: 20 always-active triggers (part of the doc's cross-cutting
always-on-trigger question). **Verdict: contradicts Principle 2
concretely, not just in spirit** — if a player hides the Chat window,
gagged channels (City/OOC/Group/etc.) still vanish from the main console
with nowhere visible to land, which is also in tension with "main
console is sacred" / "move text, don't replace it" (hiding the
destination while the gag stays active functionally deletes the text,
not just relocates it). Worth a real toggle here, not just documentation
of the gap — this is one of the largest, most central features in the
whole addon and it currently has zero off switch.

**18. `MyDSL_ItemLore.lua`** — Layer 4 persistent item-stats DB. Toggle:
N/A (passive DB). Connection: standalone. Audit flag: full-DB
`table.save()` on every single capture (same un-debounced-save class
`MyDSL_DataLayer.lua` already fixed once for a hotter path) — low
urgency since identify/lore captures are infrequent. **Verdict:
compliant; the save-debounce is a nice-to-have, not urgent.**

**19. `MyDSL_ItemReference.lua`** — Layer 4 display, driven by
`MyDSL.itemlore.updated` + hover-link clicks. **Toggle: Y** (standard
show/hide/status window lifecycle). Connection: direct calls into
`MyDSL.ItemLore.*` (a deliberate Layer-4-to-Layer-1 read, not State).
Audit flag: none. **Verdict: compliant.**

**20. `MyDSL_RouteHelper.lua`** — generic text-to-window routing helper.
**Toggle:** the `MyDSL_PlayersNear`/`MyDSL_History` windows it feeds have
the standard show/hide surface (Y), but see the flag below. Connection:
`MyDSL.Windows.*` infra. Audit flag: **`MyDSL_History` is fully wired
(registry, layout slot, theme, help text, full command surface) but
`MyDSL.Route.history()` — the only function that would ever put text
into it — has zero callers anywhere** (cross-cutting finding 9).
**Verdict: needs a decision, not a code fix** — this is a real "every
line has a destination" gap under Principle 4's own mandate: a window
built to receive a category of text (sailing/quests/atmosphere) that
was never actually wired to capture it. Worth Steven confirming whether
History was ever populated, or scoping the missing capture as new work.

**21. `MyDSL_CreatureReference.lua`** — Layer 3 Bestiary display.
**Toggle: Y.** Connection: direct calls into `MyDSL.CreatureLore.*` +
State-direct for the live-capture fallback. Audit flag: none. **Verdict:
compliant.**

**22. `MyDSL_ScanView.lua`** — Scan/RightHere display. **Toggle: Y**
(per-window show/hide, plus `SV.setGag()` for header-line gagging).
Connection: State-direct + real Layer-1-reaches-into-Layer-3 coupling
(DataLayer_ScanLook writes directly into `SV.ui.scanConsole` for raw
`appendBuffer`) — a deliberate, documented exception, not drift.
**Verdict: compliant** — the tight coupling is a real architectural
choice, not an accidental namespace violation, and should stay as-is.

**23. `MyDSL_CombatView.lua`** — Combat window + fight-summary blocks.
**Toggle: Y** (`mydsl combat mode <raw|condensed|gag>`, plus
show/hide/gag per flag). Connection: `config` read defensively by
`MyDSL_DataLayer_Combat.lua` — this is genuinely where the gag/show
decision surface for the whole combat pipeline lives, a deliberate
View-owns-the-policy design. Audit flag: none. **Verdict: compliant.**

**25. `MyDSL_GroupView.lua`** — group-members window. **Toggle: Y.**
Connection: State-direct + real cross-View read of
`MyDSL_TargetView.lua`'s `actions` table (shared by construction, not
duplicated). Audit flag: none. **Verdict: compliant.**

**26. `MyDSL_TickView.lua`** — tick countdown display, render-only.
**Toggle: Y**, but see the flag. Connection: reads `MyDSL.DB.tick`
only, correctly never owns timing itself. Audit flag: two independently-
persisted visibility flags for the same window (`V.config.shown` vs.
`MyDSL.Windows.registry[...].visible`, partially mitigated but not
unified); and — the other half of #8's finding — **`V.render()` has no
visibility check and redraws at TickSource's full 4Hz even while fully
hidden.** **Verdict: contradicts 1.0's toggle spirit the same way #8
does** — the window claims to be toggleable (`hide()` exists and calls
`win:hide()`), but the actual work behind it keeps running at full rate
regardless, so "off" only stops the *display*, not the *cost*. Fixing
either this file or TickSource alone doesn't fully solve it (documented
in the audit); needs both.

**27. `MyDSL_CharacterAssist.lua`** — rearm/standup/spellup assists,
the one module besides Leveling with an explicit exception to send real
commands. **Toggle: Partial** — spellup has real start/stop; **rearm and
standup fire unconditionally on their trigger match, with no toggle at
all**, by original 2026-07-07 design (Steven's explicit sign-off,
predating the 1.0 mandate). Connection: State-direct
(`equipment.slots`/`.ignore`, written directly — one more confirmed
State-bypasses-Get/Set instance, which is fine, that's the decided
standard). Audit flag: none performance-wise. **Verdict: needs a
decision, not necessarily a contradiction** — Principle 2 is explicit
that "a native gameplay trigger... absorbed into MyDSL's own code
doesn't get to skip having a toggle just because it used to be native,"
and rearm/standup's no-toggle design predates that mandate. Worth Steven
either re-confirming the original "zero typed input, need faster
reaction than typing allows" reasoning still overrides Principle 2 here
specifically (a legitimate case, given the reasoning), or adding a
`mydsl characterassist rearm/standup on|off` pair to bring it in line
like everything else.

**28. `MyDSL_LayoutEngine.lua`** — first-position layout system.
Toggle: N/A (a positioning system, not a feature to hide). Connection:
standalone by design (avoids circular import with WindowRegistry).
Audit flag: 4 lines of dead handler-deregistration scaffolding
(`characterIdentified`, never registered) — cosmetic. **Verdict:
compliant**, trivial cleanup item only.

**29. `MyDSL_Help.lua`** — in-UI help system. Toggle: N/A (a reference
window, standard show/hide already covers it like any other window).
Connection: standalone. Audit flag: self-identified maintenance-drift
risk (hand-maintained command list vs. live alias tree, not
independently audited). **Verdict: compliant** — the drift risk is
worth a dedicated cross-check pass at some point but isn't a 1.0
contradiction on its own.

**30. `MyDSL_ThemeEngine.lua`** — visual theme system. **Toggle:
N/A** (not player-hideable, it's the styling layer; `theme` alias family
covers switching). Connection: standalone by design (Layer 2, no
cross-imports, matches Principle 3's spirit even before that principle
existed). Audit flag: 3 lines of dead `_handlers` scaffolding (never
used — this file registers no event handlers at all). **Verdict:
compliant**, trivial cleanup only. Also the model example for Principle
1's "visual pass" being genuinely finished (real custom theme
new/edit/delete/preview shipped 2026-08-25, see `docs/CHANGELOG.md`).

**31. `MyDSL_AlterformView.lua`** — Alterform countdown widget.
**Toggle: Y** (show/hide/toggle + `setSoundEnabled()`). Connection: real
View-to-View dependency on `MyDSL_AffectsView.lua`'s
`getRemaining()` — correctly reuses rather than re-tracks. Audit flag:
none — `F.checkSoundWarning()` correctly fires once per zone transition,
not per render (the sound-spam bug this class of feature is prone to).
**Verdict: compliant** — cite as the reference example alongside
`MyDSL_RawCapture.lua` for what a clean, correctly-gated module looks
like.

**32. `MyDSL_WindowRegistry.lua`** — central window lifecycle manager,
depended on by 17+ other files. Toggle: N/A (infra). Connection:
`MyDSL.Windows.*` IS the standard every View module should call through.
Audit flag: `table.getn` debug line has been silently dead since this
project moved to LuaJIT (always prints hardcoded "20," never the real
count of 19) — cosmetic only. **Verdict: compliant**, trivial one-line
fix (the doc already has the exact replacement pattern used one line
above it in the same file).

**33. `MyDSL_PortraitView.lua`** — character portrait window.
**Toggle: Y** (standard surface exists), **but see the flag — it may
not actually reach the visible window.** Connection: intends
`MyDSL.Windows.*` but **reads `MyDSL.Windows.windows[...]`, a table that
has never existed anywhere in this codebase** (the real table is
`MyDSL.Windows.registry`) — confirmed still present in current source
this session. **Verdict: contradicts Principle 3 concretely** — this is
a real, live "not in the same namespace" bug, exactly what the audit was
commissioned to find: `P.ensureWindow()` silently falls through to
building a second, orphaned window object under the same name, so
`MyDSL_WindowRegistry.lua`'s theme/dock/layout logic is operating on a
window nothing shows. Worth Steven confirming live whether portrait
theme/dock/layout changes have, in fact, never applied — if so, this bug
is why, and it's a one-line fix (`windows` → `registry`).

**34. `MyDSL_Leveling.lua`** — auto-navigate/auto-engage leveling addon,
separate from `MyDSL_Full.mpackage`. **Toggle: Y**
(start/pause/resume/stop). Connection: the other real consumer of
`MyDSL.on()` (twice — `"scan"` and `"char"`), same narrow-exception
question as #1. Audit flag: none — the audit explicitly checked this
file for "special attention" given it sends autonomous commands and
found no polling loop, no hot-path concern. **Verdict: compliant** — the
one item to fold into #1's `MyDSL.on()` decision, not a Leveling-specific
issue.

**35. `MyDSL_MoonWeather.lua`** — moon/weather/clock HUD. **Toggle: Y.**
Connection: State-direct + `MyDSL.DB.tick`. Audit flag: none — two real,
already-shipped perf fixes (unchanged-HTML early return, shared 1Hz
heartbeat instead of its own timer chain). **Verdict: compliant** — cite
as a positive example alongside RawCapture/AlterformView.

**36. `MyDSL_AffectsView.lua`** — active-affects window + spell-command
profiles. **Toggle: Y.** Connection: raw GMCP + State-adjacent, own
dedicated save file (correctly separate from DataLayer's `MyDSL.save()`,
per the audit's own disambiguation). Audit flag: two real, already-
shipped perf fixes (1Hz throttle, mode-gated redraw); one **not yet
confirmed either way** — 6 separate event registrations for
`onGmcpEvent()` that may double-fire the same underlying GMCP signal
(same shape as the confirmed DataBridge bug, not independently verified
to actually double-fire). **Verdict: needs verification, not yet a
contradiction** — worth tracing whether Mudlet/DSL genuinely raises both
the `gmcp.`-prefixed and bare forms for the same packet before treating
this as bug #4 in the same family as DataBridge/LocationView.

**37. `MyDSL_LocationView.lua`** — room-picture window. **Toggle: Y.**
Connection: raw `gmcp.room_data` directly (not State) + real cross-View
call from `MyDSL_LiveView.lua`. Audit flag: **confirmed real double-fire
this session** (spot-checked, still current) — `M.onRoomData()`
registered on both raw `gmcp.room_data` and the mapper's `onNewRoom` for
the same room-entry moment, neither with an unchanged-room early return,
and `contain`/`stretch` fit modes pay a real image-size I/O call each
time (cross-cutting finding 2). Also: a dead `gmcp.Room.Info` handler
registration (DSL never uses that capitalized generic-GMCP form).
**Verdict: contradicts the performance goal** — smaller blast radius than
DataBridge (once per room, not per combat round) but the same root
cause and a real, fixable double-render; worth bundling into the same
interconnection pass as #9.

**38. `MyDSL_LiveView.lua`** — largest single-window HUD (vitals, room,
Improve bar). **Toggle: Y.** Connection: `MyDSL.State.*` + `MyDSL.DB.*`
+ real cross-View call to `MyDSL_LocationView.lua`'s `roomData()`. Audit
flag: **at least 6 of 10 registered event names are permanently dead**
(capitalized `MyDSL.Live.Updated`/`Status.Updated`/`Score.Updated`/
`Time.Updated`/`Room.Updated` plus `gmcp.Room.Info` — `MyDSL.emit()`
lowercases section names, so none of these capitalized forms have ever
matched anything DataLayer raises; the file's own comment already
half-admits this for one entry). **Verdict: compliant on architecture,
real dead-code cleanup pending** — harmless (never fires) but worth
removing once this file is touched for other reasons, per the audit's
own "double-check against a fresh grep before deleting" caution.

**39. `MyDSL_TargetView.lua`** — Target/Focus nameplate + condition bar,
the most cross-module-depended-on View module in the audit (Leveling,
GroupView, ScanView all call `MyDSL.Target.set()`). **Toggle: Y.**
Connection: State-direct + real call into
`MyDSL.getTargetCondition()` (`MyDSL_DataLayer_Combat.lua`) — the audit's
own self-correction (section 3 originally said this connection didn't
exist; section 39's fresh grep found it does, live and working). Audit
flag: none, positive example of the doc catching its own error. **Verdict:
compliant.**

---

## Layer 3 — Chat (audited last, largest file)

**40. `MyDSL_Chat.lua`** — EMCO class (ported, ~72% of the file) + chat
window management (this project's own code, ~28%). **Toggle: Y**
(`mydsl chat show/hide`, but see #17's finding above — hiding the window
doesn't stop ChatTriggers from gagging content that would have gone
there). Connection: the one real load-bearing cross-file dependency
(`MyDSL.Chat.emco`, read by `MyDSL_ChatTriggers.lua`) + soft `MyDSL.
Windows`/`MyDSL.Theme` checks with real fallback branches. Audit flag: a
genuine dead-logic bug (`local old = C.emco; if old and old ~= C.emco
then` — can never be true, confirmed still present this session) and a
stale error message naming two files merged away in 2026-07-17.
**Verdict: compliant on architecture** (correct buffer trimming, correct
event-driven theme re-apply, no duplicate parsing) — the two bugs above
are small, cosmetic, and don't affect real behavior, but worth fixing
alongside #17's real toggle gap since they're the same file pairing.

---

## New since the audit

**`MyDSL_Login.lua`** (built 2026-08-26, not in `docs/OPTIMIZATION_
AUDIT.md`). **Toggle: Y** (`mydsl login on|off`, independent of whether
credentials are configured — correct Principle 2 shape from day one).
Connection: standalone, no State reads (nothing to read — it only sends
two values on two fixed prompts). Reviewed directly this session (see
`HANDOFF.md`): 16/16 tests independently re-run, 3 targeted-revert
mutations independently reproduced. **Verdict: compliant** — built
correctly under 1.0 principles from the start, nothing to flag.

---

## Cross-module patterns worth resolving before step 4 (interconnection pass)

Not new findings — these are the audit's own cross-cutting section,
restated here only to connect them to the specific modules above so
step 4 has a ready-made punch list instead of re-deriving one:

1. **The two real double-fire bugs** (#9 DataBridge, #37 LocationView)
   share one root cause — a raw GMCP event and a same-moment
   derived/re-raised event both wired to the same expensive handler.
   Fix pattern is the same for both: pick one signal per section, or
   debounce to one call per real-world moment.
2. **The 4Hz-with-no-visibility-gate problem** (#8 TickSource / #26
   TickView) needs both ends addressed together, per the audit's own
   note that fixing only one side doesn't fully solve it.
3. **Get/Set API's fate** (#1, blocking on #14 MovementSounds being the
   only real caller) and **`MyDSL.on()`'s fate** (#1/#34, Leveling's two
   real uses) are both open Principle-3 cleanup decisions the philosophy
   doc flagged but left to this pass.
4. **Toggle gaps found this session, not in the original audit**: #17
   ChatTriggers (zero toggle for 20 always-active chat-routing triggers,
   with a real "text vanishes with nowhere to go" consequence when the
   Chat window is hidden), #27 CharacterAssist's rearm/standup (zero
   toggle by original pre-1.0 design), #14 MovementSounds (toggle exists
   in code, unreachable by any alias).

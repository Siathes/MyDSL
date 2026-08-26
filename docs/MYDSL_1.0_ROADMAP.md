# MyDSL 1.0 — Completion Roadmap

**Purpose of this document, distinct from every other doc in `docs/`:**
this is the one place that says *where the whole 1.0 effort stands right
now and what order the rest happens in*. It doesn't restate detail that
already lives elsewhere:
- `docs/MYDSL_1.0_PHILOSOPHY.md` — the principles (confirmed, not
  re-litigated here).
- `docs/OPTIMIZATION_AUDIT.md` — the raw per-file findings (44 sections:
  1-40 pass 1, 41-44 pass 2, plus two "Cross-cutting findings" wrap-ups).
- `docs/MYDSL_1.0_MODULE_REDESIGN.md` — the per-module Toggle/Connection/
  Verdict table (step 3).
- `docs/TODO.md` — the day-to-day punch list (gets pruned as items close).
- `docs/CHANGELOG.md` — the permanent record of what actually shipped.

**Update this file whenever a phase below changes status.** Unlike
`TODO.md`, don't prune closed phases away — a short "done" line per
phase is the whole point of tracking progress here, not the append-only
sprawl `TODO.md` has to guard against. Do keep each module's own entry
to one line once it's closed, same discipline as everywhere else.

---

## Where things stand, 2026-08-26 (comparing all passes so far)

| Stage | Owner | Status |
|---|---|---|
| Philosophy document (6 principles) | Both, confirmed | **Done** (2026-08-25) |
| Pass 1 audit — 39 `.lua` modules + mapper's `map.dsl.*` fork | Claude Code, re-verified by Desktop | **Done** (2026-08-25) |
| Visual pass v1 — theme presets + custom themes | Claude Code | **Done** (2026-08-25) — `theme new/edit/delete/preview` |
| Login security fix | Claude Desktop built, Claude Code integrated | **Done** (2026-08-26), needs live confirm |
| Step 3 — module-by-module redesign write-up | Claude Desktop | **Done** (2026-08-26) |
| Pass 2 audit — 4 native XML files (mapper's stock code, DslColors, gameplay triggers, personal aliases) | Claude Desktop, re-verified + partly fixed by Claude Code | **Done** (2026-08-26) |
| `check_text_coverage.py` build + spot-check | Claude Code built, Claude Desktop spot-checked | **Done** (2026-08-25/26), 2 known blind spots documented, not fixed |
| Bug-fix sweep on pass-1/pass-2 findings (no-decision-needed items) | Claude Code | **Phase 1 mostly done** 2026-08-26 — 7 fixed, including 1 critical regression found along the way (see table below) |
| Visual pass v2 — title-bar hiding, UI best-practices research, 3 mockups | Claude Desktop researched, Steven locked the spec, Claude Code building | **Foundation done** 2026-08-26; per-window header rollout (~13 files) still ahead |
| Step 4 — interconnection/performance pass | Not started | **Not started** |
| Step 5 — unknown-line routing design (Principle 4 Part B) | Deferred | **Deferred**, blocked on coverage tool maturity |
| Mapper's own DSL-specific rewrite | Deferred | **Deferred**, own dedicated pass, scope not yet sized |

Every module the audit ever touched (44 sections) is accounted for in
the table below — nothing was skipped between pass 1, the redesign
write-up, and pass 2.

---

## Per-module status (all 44 audited units)

Legend: ✅ compliant, nothing to do — 🔧 fixed this session — ⚠️ real bug,
no decision needed, not yet fixed — ❓ needs a decision from Steven before
any code changes — 🔭 out of scope for now (own future pass).

| # | Module | Status | Note |
|---|---|---|---|
| 1 | `MyDSL_DataLayer.lua` | ❓ | Get/Set API (1 caller) + `MyDSL.on()` (2 callers) fate |
| 2 | `MyDSL_DataLayer_CreatureLore.lua` | ✅ | |
| 3 | `MyDSL_DataLayer_Combat.lua` | ✅ | 24 always-on triggers — folds into the project-wide trigger-count question |
| 4 | `MyDSL_DataLayer_ScanLook.lua` | ✅ | |
| 5 | `MyDSL_DataLayer_ItemLore.lua` | 🔧 | **critical**: `endEquip()`/`endInventory()` were silently crashing, same root cause as #6 — fixed 2026-08-26 |
| 6 | `MyDSL_DataLayer_PromptVitals.lua` | 🔧 | **critical**: every capture function in this file was silently crashing (`update()`/`now()` calls broken by the 2026-08-25 split, fixed 2026-08-26) — see CHANGELOG |
| 7 | `MyDSL_RawCapture.lua` | ✅ | reference example for Principle 2 |
| 8 | `MyDSL_TickSource.lua` | ⚠️ | 4Hz with no visibility gate — pairs with #26 |
| 9 | `MyDSL_DataBridge.lua` | ⚠️ | confirmed double-fire, 11 registrations onto one `sync()` — step 4's #1 priority |
| 10 | `DSL_Generic_Mapper.xml` (DSL fork layer) | ✅ | duplicate GMCP parsing vs. DataLayer is a known, reasoned tradeoff |
| 11 | `MyDSL_PromptSetup.lua` | ✅ | |
| 12 | `MyDSL_AutoWhere.lua` | ❓ | unresolved manual step (disable native `(autowhere)` alias) — confirm it was done |
| 13 | `MyDSL_PromptView.lua` | 🔧 | its own native trigger pair was the prompt-gag bug — fixed 2026-08-26 |
| 14 | `MyDSL_MovementSounds.lua` | ❓ | toggle exists in code, unreachable by any alias; only remaining Get/Set caller |
| 15 | `MyDSL_CreatureLore.lua` | ✅ | |
| 16 | `MyDSL_Roller.lua` | ✅ | |
| 17 | `MyDSL_ChatTriggers.lua` | ❓ | **largest toggle gap in the addon** — zero on/off for 20 always-on triggers |
| 18 | `MyDSL_ItemLore.lua` | ✅ | un-debounced save, low urgency |
| 19 | `MyDSL_ItemReference.lua` | ✅ | |
| 20 | `MyDSL_RouteHelper.lua` | ❓ | ~~`MyDSL_History` "zero callers"~~ **resolved pass 2: 83 real native callers, not dead** |
| 21 | `MyDSL_CreatureReference.lua` | ✅ | |
| 22 | `MyDSL_ScanView.lua` | ✅ | |
| 23 | `MyDSL_CombatView.lua` | ✅ | |
| 25 | `MyDSL_GroupView.lua` | ✅ | |
| 26 | `MyDSL_TickView.lua` | 🔧 | no visibility-gated render — fixed 2026-08-26, new test |
| 27 | `MyDSL_CharacterAssist.lua` | ❓ | rearm/standup fire with zero toggle, pre-1.0 design — re-confirm or add toggle |
| 28 | `MyDSL_LayoutEngine.lua` | ✅ | dead handler-deregistration scaffolding, cosmetic |
| 29 | `MyDSL_Help.lua` | ✅ | drift-risk vs. live alias tree, not urgent |
| 30 | `MyDSL_ThemeEngine.lua` | ✅ | reference example for Principle 1's visual pass |
| 31 | `MyDSL_AlterformView.lua` | ✅ | reference example alongside RawCapture |
| 32 | `MyDSL_WindowRegistry.lua` | 🔧 | dead `table.getn` line — fixed 2026-08-26 |
| 33 | `MyDSL_PortraitView.lua` | 🔧 | `Windows.windows` → `.registry` — fixed 2026-08-26, new test |
| 34 | `MyDSL_Leveling.lua` | ✅ | folds into #1's `MyDSL.on()` decision |
| 35 | `MyDSL_MoonWeather.lua` | ✅ | reference example |
| 36 | `MyDSL_AffectsView.lua` | ⚠️ | possible GMCP double-fire, not yet confirmed either way |
| 37 | `MyDSL_LocationView.lua` | ⚠️ | confirmed double-fire — step 4's #2 priority |
| 38 | `MyDSL_LiveView.lua` | ✅ | 6 dead event names, harmless cleanup whenever the file's next touched |
| 39 | `MyDSL_TargetView.lua` | ✅ | |
| 40 | `MyDSL_Chat.lua` | 🔧 | dead old/new comparison in `createInWindow()` — fixed 2026-08-26; #17's toggle gap still applies to it |
| 41 | `DSL_Generic_Mapper.xml` (stock ~5,666 lines) | 🔭 | live dependency confirmed (`MyDSL_Leveling.lua` calls `map.speedwalk()`) — own dedicated rewrite pass |
| 42 | `DslColors_Core_v1_0.xml` | ❓ | no master toggle at all, plus a real per-line perf cost (re-lowercases per term) |
| 43 | `MyDSL_GameplayTriggers.xml` | 🔧 / ❓ | prompt-gag bug fixed 2026-08-26; 30 hardcoded sound paths + "BACKSTABS Fail" dead trigger still open |
| 44 | `MyDSL_PersonalAliases.xml` | ❓ | does Principle 2 even apply to personal command shortcuts? |
| — | `MyDSL_Login.lua` (postdates the audit) | ✅ | built correctly under 1.0 from day one |

(Data files excluded from numbering, same as the audit itself:
`MyDSL_state.lua`, `MyDSL_theme_settings.lua`, `MyDSL_windowfonts.lua`.)

**Scoreboard**: 22 compliant, 7 fixed this session (2 of them critical —
see below), 3 real bugs still open with no decision needed, 9 waiting on
a decision from Steven, 2 explicitly deferred to their own future pass.

**Critical finding, 2026-08-26**: while adding the test coverage Phase 1
called for on `MyDSL_DataLayer_PromptVitals.lua`, found that the
2026-08-25 DataLayer split-by-domain refactor left every one of that
file's and `MyDSL_DataLayer_ItemLore.lua`'s state-writing functions
silently crashing (`update()`/`now()` calls broken across a `dofile()`
boundary — full detail in `docs/CHANGELOG.md`). This meant
score/flags/lunar/time/weather/who/group/improve/position/wimpy/dragon-
vitality and equipment/inventory capture were all non-functional for
the entire day between the split landing and this fix. Fixed and
covered by two new regression tests. This is the single most important
thing this roadmap has caught so far — worth remembering as the reason
Phase 1's "add missing test coverage" items matter even when nothing
looked obviously broken.

---

## The plan, in order

### Phase 0 — Decisions (blocks nothing else, but blocks *these* modules)
All 9 ❓ rows above, already written up with their tradeoffs in
`docs/TODO.md`'s TOP PRIORITY section. Nothing else in this roadmap
requires them to be answered first — they're independent, module-local
questions. Answer them whenever, in any order; each unblocks exactly
one module's fix.

### Phase 1 — Finish the no-decision-needed bug sweep (⚠️ rows)
**Mostly done 2026-08-26.** `MyDSL_DataLayer_PromptVitals.lua`'s test
coverage turned up the critical `update()`/`now()` regression above —
fixed, tested. `MyDSL_TickSource.lua`/`MyDSL_TickView.lua`'s shared 4Hz
gate — fixed on the render side (TickView skips its work while hidden;
TickSource's own loop cadence deliberately left alone, see the
CHANGELOG entry for why). `MyDSL_AffectsView.lua`'s suspected GMCP
double-fire — investigated and ruled out with high confidence: 2 of its
6 `onGmcpEvent()` registrations are for bare event names nothing in
this codebase ever raises (confirmed dead, harmless), and the 3 real
`gmcp.`-prefixed registrations map to 3 genuinely distinct DSL message
types (full resync vs. two different deltas), not the same packet
counted twice — the 6th (`gmcp.affect_data.affects`) is very likely
also dead, since `MyDSL_DataLayer.lua`'s own real consumer of this
packet only ever reads `.affects` as a nested field of the `gmcp.
affect_data` event payload, never as its own event name; not deleted
outright since this rests on Mudlet's internal GMCP-to-event dispatch
behavior, which wasn't independently verified against Mudlet's own
source or a live test — low-priority cosmetic cleanup, not a
correctness bug either way.

Left in this phase: the one item that's a genuine project-wide
question, not a single-module fix — **how many always-active regex/
event registrations does a single incoming line pay for, added up
across the whole addon** (combat's 24, chat-triggers' 20, the mapper's
`onNewLine` hook, plus whatever else). No single file's audit section
can answer this; needs a dedicated project-wide count. Worth doing if
Steven is still seeing lag after Phase 2's fixes land, not necessarily
before.

### Phase 2 — Step 4: interconnection/performance pass
The two confirmed double-fires (`MyDSL_DataBridge.lua`'s 11-registration
coalesce, `MyDSL_LocationView.lua`'s dual-render) are the concrete,
already-diagnosed work here — both share one fix pattern (pick one
signal per section, or debounce to one call per real-world moment,
same shape `MyDSL.save()` already uses). Do these after Phase 1's
TickSource/TickView pair, since all three touch the same "how much
does one line/tick cost" question and are easier to reason about
together than interleaved with unrelated module fixes.

### Phase 3 — Visual pass v2 ("Direction A+ — Quiet Chrome, Cross-Platform")
Research done by Claude Desktop 2026-08-26 (`docs/MyDSL_MudletWindowManagement.md`
cross-checked, 3 mockup directions delivered against the real 5 presets,
full detail in `HANDOFF.md`). **Steven picked and locked a final spec
the same day** — not still open:
- Native title bar flattened to a blank sliver matching the window's
  own background (kept alive only so drag/dock still works — Qt exposes
  no Lua-reachable way to remove it outright). Linux-only rendering,
  confirmed via Mudlet's own manual — harmless no-op on Windows/macOS.
- A plain `Geyser.Label` underneath carries the real visible title —
  ordinary widget CSS, renders identically on every OS, which is the
  actual fix for Steven's Linux+Windows requirement.
- Uniform across every window (no mixing in the bolder "Direction B"
  style anywhere), small/discreet (~10.5px, low-opacity tint), header
  text is the window name only — no "MyDSL —" prefix.

**Done 2026-08-26**: the safe foundation — `MyDSL.Theme.titleBarCSS()`/
`headerLabelCSS()` (exact formula confirmed against Desktop's mockup:
text=`titleColor`, background=`titleBgColor`, border=the window's own
`borderColor`), wired into `MyDSL_WindowRegistry.lua`'s `applyTheme()`
for the native-bar flatten half. Two new tests, full suite clean.

**Header Label rollout: 12 of 15 done, 2026-08-26.** `MyDSL_CombatView.lua`,
`MyDSL_RouteHelper.lua` (History + PlayersNear), `MyDSL_ScanView.lua`
(Scan + RightHere), `MyDSL_GroupView.lua`, `MyDSL_CreatureReference.lua`,
`MyDSL_Help.lua`, `MyDSL_ItemReference.lua`, `MyDSL_Leveling.lua`,
`MyDSL_LocationView.lua`, `MyDSL_PortraitView.lua` (preserves its
existing user-customizable title, unlike every other window's fixed
name). Full suite clean, not yet live-confirmed by Steven — a real,
visible change across 12 windows, delivered for his own look first
per his own ask, before being called final.

**3 windows deliberately deferred, real architectural reasons, not
oversights**:
- `MyDSL_Chat.lua` — EMCO's own internal tab-bar/console geometry
  already owns y=0 in its parent via its own pixel-offset math.
  Inserting a header means touching EMCO's internal layout code, not a
  percent shift like everywhere else.
- `MyDSL_AffectsView.lua` — writes directly into the UserWindow's own
  raw `cecho()` target, no bounded child console exists to resize.
  Needs converting to a MiniConsole child first, a bigger change than
  this pass's scope.
- `MyDSL_TargetView.lua` — already has its own custom top row (y=0-10%:
  nameplate + MP/Clear buttons) plus a tightly-tuned action-button grid
  with real prior live-bug history around exactly this vertical space
  budget (docs/CHANGELOG.md, 2026-07-11). Shifting it blind risks
  reintroducing a previously-fixed regression.

Each of these 3 needs its own dedicated design pass, not a repeat of
the mechanical percent-shift used for the other 12.

### Phase 4 — Step 5: unknown-line routing design (Principle 4 Part B)
Still blocked on the known-pattern catalog maturing — `check_text_
coverage.py`'s two documented blind spots (wrapper-built patterns,
narrowed-variable `:find()`/`:match()` calls) are worth closing first
so the "what's actually unknown" signal is trustworthy before designing
a mechanism to route it somewhere. Low priority relative to Phases 1-3.

### Phase 5 — Mapper's own DSL-specific rewrite
Explicitly its own dedicated pass, not folded into general module work
— confirmed in pass 2 that `MyDSL_Leveling.lua` has a real, live
dependency on the stock package (`map.speedwalk()`), so this isn't a
clean-slate rewrite; whatever replaces it needs to keep that caller
working. Not started, not scoped yet. Last phase before "feature
complete" can be declared, since it's the one piece of Principle 1's
mandate ("no more third-party/reference-only code") still genuinely
outstanding at real scale (7x the line count everything else in this
project has touched).

### "Feature complete 1.0" means
Every ❓ in the table above answered and acted on, every ⚠️ fixed,
Phase 3's visual direction chosen and built, Phase 4's routing
mechanism built (or explicitly re-deferred by Steven), and Phase 5
either finished or explicitly re-scoped as post-1.0. Update the
scoreboard above as each phase closes rather than waiting for the end
to check state — this doc should always answer "how close are we"
truthfully.

---

## Design philosophy already chosen for the UI (read before Phase 3)

Grepped directly rather than assumed, so Phase 3's research starts from
what's real, not from a blank page:
- **Typography**: monospace throughout (`Courier New` default, same
  font/titleFont), no serif/sans mixing anywhere in the theme system.
- **Palette shape**: dark near-black-blue background (`rgb(18,20,28)`,
  alpha 242 — slightly translucent, not opaque black), warm off-white
  text (`rgb(210,208,200)`), cool blue-grey borders (`rgb(60,70,90)`),
  gold highlight accent (`rgb(220,180,60)`), plus semantic warn (red)/
  good (green)/dim (grey) colors held separately from the accent —
  already matches the "semantic color is separate from the accent hue"
  principle generally recommended for UI/HUD work.
- **Shape language**: 1px borders, 6px corner radius — soft, not sharp,
  not heavily rounded either.
- **5 named presets** already exist as real, switchable, player-
  creatable-from options: `refined_convergence` (default),
  `terminal_purist`, `zoned_hud`, `obsidian_ember`, `arcane_midnight` —
  read `MyDSL_ThemeEngine.lua`'s `presets` table directly for each
  one's actual values before proposing a 4th/5th/6th direction from
  scratch.
- **Structural constraints already decided, non-negotiable**: main
  console is sacred (never hidden or obscured), all positioning is
  percentage-based (never hardcoded pixels — `MyDSL_Audit.md` item 9 is
  the on-record example of what NOT to repeat), every window/feature
  needs independent on/off (Principle 2), moved text must stay
  recognizable as what the game sent (never re-styled into something
  unrecognizable).
- **Known technical territory for the title-bar-hiding ask**:
  `docs/MyDSL_MudletWindowManagement.md` documents Geyser.UserWindow's
  real constructor defaults, the `sysWindowResizeEvent`/`reflowAll()`
  reset bug, and console border management — read this before proposing
  anything that touches window chrome, since this project has already
  been burned by window-geometry assumptions that didn't match Geyser's
  actual behavior. Title-bar visibility itself has **never been touched
  anywhere in this codebase** (confirmed via grep — zero references to
  hiding/showing a UserWindow's title bar) — this is genuinely new
  ground, not a rediscovery of an existing toggle.

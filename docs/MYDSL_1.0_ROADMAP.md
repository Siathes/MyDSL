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
| Bug-fix sweep on pass-1/pass-2 findings (no-decision-needed items) | Claude Code | **In progress** — 4 of ~7 fixed 2026-08-26 (see table below) |
| Visual pass v2 — title-bar hiding, UI best-practices research, 3 mockups | Claude Desktop (assigned below) | **Not started** |
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
| 5 | `MyDSL_DataLayer_ItemLore.lua` | ✅ | |
| 6 | `MyDSL_DataLayer_PromptVitals.lua` | ⚠️ | highest-frequency trigger in the addon, zero test coverage |
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
| 26 | `MyDSL_TickView.lua` | ⚠️ | no visibility-gated render — pairs with #8 |
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

**Scoreboard**: 24 compliant, 4 fixed this session, 5 real bugs still
open with no decision needed, 9 waiting on a decision from Steven, 2
explicitly deferred to their own future pass.

---

## The plan, in order

### Phase 0 — Decisions (blocks nothing else, but blocks *these* modules)
All 9 ❓ rows above, already written up with their tradeoffs in
`docs/TODO.md`'s TOP PRIORITY section. Nothing else in this roadmap
requires them to be answered first — they're independent, module-local
questions. Answer them whenever, in any order; each unblocks exactly
one module's fix.

### Phase 1 — Finish the no-decision-needed bug sweep (⚠️ rows)
5 left: `MyDSL_DataLayer_PromptVitals.lua` (add test coverage for the
highest-frequency trigger in the addon), `MyDSL_AffectsView.lua`
(confirm or rule out the GMCP double-fire), plus the 3 that are really
one project-wide question (`MyDSL_TickSource.lua` + `MyDSL_TickView.lua`'s
shared 4Hz gate, and the "how many always-on registrations does one
line pay for" count neither pass could answer on its own). Claude
Code's to pick up directly, same standard as this session's sweep
(targeted-revert verification, full suite, `check_known_patterns.py
--all`).

### Phase 2 — Step 4: interconnection/performance pass
The two confirmed double-fires (`MyDSL_DataBridge.lua`'s 11-registration
coalesce, `MyDSL_LocationView.lua`'s dual-render) are the concrete,
already-diagnosed work here — both share one fix pattern (pick one
signal per section, or debounce to one call per real-world moment,
same shape `MyDSL.save()` already uses). Do these after Phase 1's
TickSource/TickView pair, since all three touch the same "how much
does one line/tick cost" question and are easier to reason about
together than interleaved with unrelated module fixes.

### Phase 3 — Visual pass v2 (Steven's new ask, 2026-08-26)
Assigned to Claude Desktop — see the prompt below. Scope: research
title-bar hiding and general Mudlet/Geyser UI polish techniques, cross-
check against the 6 window-management gotchas already documented in
`docs/MyDSL_MudletWindowManagement.md`, integrate the MyDSL 1.0
philosophy (Principle 2 toggles, "main console is sacred," percentage-
only positioning — no new absolute-pixel regressions), and deliver 3
distinct visual mockup directions built from the *existing* 5 theme
presets in `MyDSL_ThemeEngine.lua` (`refined_convergence`,
`terminal_purist`, `zoned_hud`, `obsidian_ember`, `arcane_midnight`) —
not a disconnected new palette. Claude Code implements whichever
direction Steven picks, same as the v1 theme work.

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

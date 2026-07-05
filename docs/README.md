# DSL Observer UI — Project Folder Index
*Read this first. Everything lives here. Updated 2026-07-05.*

---

## What This Project Is

A modular 4-layer passive observation UI for Dark and Shattered Lands (DSL),
built in Mudlet 4.20.1. Built directly by Steven and Claude Code, working
from this repository — no separate design-chat relay or upload/download step.
(That changed 2026-07-05; see `SESSION_START.md`'s "Workflow" section for why.)

---

## Start Here Every Session

1. **Read `SESSION_START.md`** — current state, what's done, what's next
2. **Read `TODO.md`** — what the current task is
3. **Read the relevant `Contract_*.md`** — before touching any module, but
   verify it against the live `.lua` file rather than trusting it blindly —
   contracts are summaries and have been found to drift from what shipped
   (see `MyDSL_MudletAPIReference.md`'s "read source directly" note)

---

## File Map

### Always-Current (Claude Code updates these directly now)
| File | What it is |
|---|---|
| `SESSION_START.md` | Current project state, layer status, orientation guide |
| `TODO.md` | Actionable backlog with priorities |
| `CHANGELOG.md` | What changed in each session/commit |
| `DSL_SessionNotes.md` | Running session log |

### Reference — Don't Change Unless Adding Data
| File | What it is |
|---|---|
| `DSL_CommandRef.md` | Actual DSL in-game output with confirmed Lua parse patterns |
| `DSL_UI_Philosophy.md` | Design principles and "why" |
| `MyDSL_MudletWindowManagement.md` | Mudlet window API — corrected June 28 |
| `MyDSL_MudletAPIReference.md` | Mudlet API reference Part 1 — PCRE-vs-Lua-pattern rules, Lua 5.1 gotchas, "read PNP source directly" and "templates files aren't authoritative" lessons |
| `MyDSL_MudletAPIReference_Part2.md` | Mudlet API reference Part 2 — borders, database, strings, dynamic triggers, EMCO internals, createBuffer. Was missing from this repo earlier in the 2026-07-05 session; Steven re-added it mid-session (in two near-duplicate versions — kept the corrected one, which fixes a stale "resize handler still needs retiring" section that was actually resolved back on 2026-06-25) |
| `../MyDSL_Audit.md` | DSL1 complete audit (reference for what existed) — profile root, not docs/ |
| `../MyDSL_PNP_Reference.md` | PNP package reference summary — profile root, not docs/. Read `../PNP files/*.lua` directly for anything that needs porting or verifying |
| `Contract_Addendum_2026-06-21.md` | Addendum superseding parts of several contracts |
| `templates_by_freq.txt` / `templates_with_examples.txt` | Pre-distilled combat-message shapes from the `log/` archive — fast first pass only, confirmed gaps exist |
| `MyDSL_IdeaBacklog.md` | Raw, unscoped feature/research idea dump, categorized. Absorbed from Steven's `~/Downloads/aistuff.txt` 2026-07-05 (now deleted — this is the only copy). Add new ideas here directly; nothing here is started unless it also appears in `TODO.md` |

### Contracts — Written From Actual Code, Spot-Checked 2026-07-05
| File | Module | Status |
|---|---|---|
| `Contract_DataLayer.md` | Layer 1 — DataLayer | ✅ Working |
| `Contract_ThemeEngine.md` | Layer 2 — ThemeEngine | ✅ Working — 1 minor gap open |
| `Contract_LayoutEngine.md` | Layer 2 — LayoutEngine | ✅ Working — 2 minor gaps open |
| `Contract_WindowRegistry.md` | Layer 2 — WindowRegistry | ✅ Working — 2 minor gaps open |
| `Contract_DataBridge.md` | Layer 3 — DataBridge | ✅ Working — all documented gaps confirmed fixed |
| `Contract_RouteHelper.md` | Layer 3 — RouteHelper | ✅ Working, see addendum |
| `Contract_TickSource.md` | Layer 3 — TickSource | ✅ Working — all gaps confirmed fixed |
| `Contract_TickView.md` | Layer 3 — TickView | ✅ Working |
| `Contract_ChatWrapper.md` | Layer 3 — ChatWrapper | ✅ Working — 2 minor gaps open |
| `Contract_AffectsView.md` | Layer 3 — AffectsView | ✅ Working — template module |
| `Contract_PortraitView.md` | Layer 3 — PortraitView | ✅ Working |
| `Contract_LocationView.md` | Layer 3 — LocationView | ✅ Working |
| `Contract_LiveView.md` | Layer 3 — LiveView | ✅ Working |
| `Contract_PromptView.md` | Layer 3 — PromptView | ✅ Working — simple prompt-gag design |
| `Contract_MoonWeather.md` | Layer 3B — MoonWeather | ✅ Feature-complete, confirmed live |
| `Contract_ScanView.md` | Layer 3B — ScanView | ✅ Confirmed live |
| `Contract_GroupView.md` | Layer 3B — GroupView | ✅ Built, not yet live-tested |
| `Contract_TargetView.md` | Layer 3B — TargetView | ✅ Confirmed live |
| `Contract_CreatureReference.md` | Layer 3B — CreatureReference | ✅ Built, not yet live-tested |
| `Contract_CombatWindow.md` | Layer 3B — CombatView | ✅ Built and hardened 2026-07-05, not yet live-tested |

Full detail on every open gap (what's confirmed fixed vs. still genuinely
open) lives in `TODO.md` — this table is a one-line summary.

### Source Code (reference copies — profile root has the live copies)
| File | What it is |
|---|---|
| `../MyDSL_DataLayer.lua` | Layer 1 source — this is the live, actually-loaded copy |
| `../MyDSL_creaturelore.lua` | Creature DB (do not break) |
| `claude_export_2026-07-05/` | Snapshot produced for the old Claude.ai handoff — obsolete now, safe to delete whenever this repo gets tidied |

### Old/Stale (keep for reference, do not use as current)
| File | Notes |
|---|---|
| `2026-06-07_09-42-43.xml` | Old DSL1 audit XML — reference only |
| `MyDSL_WorkflowPlan.md` | Early planning doc, superseded by SESSION_START |
| `MyDSL_FeatureComparison.md` | Feature matrix from early session |
| `MyDSL_Backlog.md` | Early backlog, superseded by TODO.md |

---

## Session End Ritual (revised 2026-07-05)

**Claude Code does, every session:**
- Append to `CHANGELOG.md` on every commit
- Update `TODO.md` and `SESSION_START.md` if project state materially changed
- Append a dated entry to `DSL_SessionNotes.md`
- Correct any `Contract_*.md` found to have drifted from live code
- Tag git milestones on request

**Steven does:** tests in-game, reports bugs/confirmations, approves changes.
No upload/download step anymore — everything lives in this repo directly.

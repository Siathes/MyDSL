# DSL Observer UI — Project Folder Index
*Read this first. Everything lives here. Updated June 29, 2026.*

---

## What This Project Is

A modular 4-layer passive observation UI for Dark and Shattered Lands (DSL),
built in Mudlet 4.20.1. Three tools build it together:
- **Claude.ai** (this chat) — design, contracts, specifications
- **Claude Code** (terminal) — writes files, runs git
- **Steven** — tests in-game, approves, uploads files here

---

## Start Here Every Session

1. **Read `SESSION_START.md`** — current state, what's done, what's next
2. **Read `TODO.md`** — what the current task is
3. **Read the relevant `Contract_*.md`** — before touching any module

---

## File Map

### Always-Current (updated every session)
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
| `MyDSL_MudletAPIReference.md` | Mudlet API reference Part 1 |
| `MyDSL_MudletAPIReference_Part2.md` | Mudlet API reference Part 2 |
| `MyDSL_Audit.md` | DSL1 complete audit (reference for what existed) |
| `MyDSL_PNP_Reference.md` | PNP package reference |
| `Contract_Addendum_2026-06-21.md` | Addendum superseding parts of several contracts |

### Contracts — Written From Actual Code
| File | Module | Status |
|---|---|---|
| `Contract_DataLayer.md` | Layer 1 — DataLayer | ✅ Working. Score trigger fixed June 29 |
| `Contract_ThemeEngine.md` | Layer 2 — ThemeEngine | ✅ Contracted |
| `Contract_LayoutEngine.md` | Layer 2 — LayoutEngine | ✅ Working. Resize handler removed June 28 |
| `Contract_WindowRegistry.md` | Layer 2 — WindowRegistry | ✅ Working. Layout persistence working |
| `Contract_DataBridge.md` | Layer 3 — DataBridge | Contracted, gaps documented |
| `Contract_RouteHelper.md` | Layer 3 — RouteHelper | Contracted, see addendum |
| `Contract_TickSource.md` | Layer 3 — TickSource | ✅ Working |
| `Contract_TickView.md` | Layer 3 — TickView | ✅ Working |
| `Contract_ChatWrapper.md` | Layer 3 — ChatWrapper | ✅ Working |
| `Contract_AffectsView.md` | Layer 3 — AffectsView | ✅ Working — template module |
| `Contract_PortraitView.md` | Layer 3 — PortraitView | ✅ Working |
| `Contract_LocationView.md` | Layer 3 — LocationView | ✅ Working |
| `Contract_LiveView.md` | Layer 3 — LiveView | ✅ Working |
| `Contract_PromptView.md` | Layer 3 — PromptView | Design confirmed, contract stub |

### Source Code (reference copies)
| File | What it is |
|---|---|
| `MyDSL_DataLayer.lua` | Layer 1 source (reference — live copy is on disk in DSL2 profile) |
| `MyDSL_creaturelore.lua` | Creature DB (do not break) |

### Old/Stale (keep for reference, do not use as current)
| File | Notes |
|---|---|
| `2026-06-07_09-42-43.xml` | Old DSL1 audit XML — reference only |
| `MyDSL_WorkflowPlan.md` | Early planning doc, superseded by SESSION_START |
| `MyDSL_FeatureComparison.md` | Feature matrix from early session |
| `MyDSL_Backlog.md` | Early backlog, superseded by TODO.md |

---

## The Session End Ritual

**Claude.ai always produces at end of session:**
- Updated `SESSION_START.md`
- New entry in `DSL_SessionNotes.md`
- Updated `TODO.md`
- Any new or corrected `Contract_*.md` files

**Steven always does at end of session:**
- Download new/updated files from Claude.ai outputs
- Upload them to this project folder
- Copy same files to DSL2/doc/ for Claude Code

**Claude Code always does on each commit:**
- Append to `CHANGELOG.md`
- Tag git milestones

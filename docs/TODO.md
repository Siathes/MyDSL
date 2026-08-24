# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06; pruned 2026-07-07 after
it grew back to 1300+ lines; pruned again 2026-07-11 after it grew to 1900+
lines (a single TargetView entry alone had ballooned past 500 lines across
10 "rounds" of the same live-debugging conversation — all of that detail is
in `CHANGELOG.md` already, appended in real time as each fix landed). If
this file is turning back into a growing append-only history again, prune
it — don't let it happen a third time.*

**Feature creep is paused as of 2026-07-07, per Steven** — bug fixes, live
confirmation, and finishing already-scoped work only. Nothing under
DEFERRED gets started without an explicit go-ahead.

---

## TOP PRIORITY — project-wide audit & optimization phase (opened 2026-08-23)
Per Steven, both in chat and independently in MyDSL's own `notes_utf8.txt`
("moving into the optimization phase soon for UI, start looking at code
that can be removed or made more efficient", "check for lag spikes... we
need to do an optimization pass on the entire mydsl suite", "do a really
really thorough deep scan of the current state of the project... cross
check connections of modules... make sure its all in the same namespace...
review it like its a new project"). This is an explicit go-ahead — not
scope creep — for a dedicated audit phase, separate from and in addition
to the per-item live confirmations below.
- [ ] **Reduce `MyDSL.logWindow()` scope** — Steven: "stop logging anything
      except combat/main window/chat and history, if they are already
      logged thats good, but others dont seem needed and seem to be
      useless." Needs a pass over every `logWindow()` call site to confirm
      which categories exist today and cut the rest.
- [x] **Full cross-module code audit — completed 2026-08-23, findings
      reconciled, low-risk items fixed directly.** Two background passes:
      a log/file corpus scan (findings folded into the PAUSED section and
      `docs/DSL_CommandRef.md` above) and a static code audit across all
      `MyDSL_*.lua` modules. Fixed directly (all tests + the known-pattern
      sweep re-run clean afterward):
      - **`dslpnp` nil-global error, confirmed on a SECOND native trigger
        ("BACKSTABS"), not just "Charge" as previously flagged.** Found
        live in MyDSL's own error log (2026-08-21/22, unswept until this
        audit) — 4 error-log lines per proc, harmless to gameplay (the
        backstab still lands correctly) but real, reproducible spam.
        Root cause confirmed identical to the earlier "Charge" finding:
        leftover native triggers guard themselves with `if
        dslpnp.battle.Active then`, a global from the old PNP framework
        this profile no longer loads. Fixed with a 2-line stub in
        `MyDSL_DataLayer.lua` (`dslpnp = dslpnp or {}; dslpnp.battle =
        dslpnp.battle or { Active = false }`) — confirmed via the newest
        native XML in both DSL2 and the live MyDSL profile that
        `dslpnp.battle.Active` is the ONLY field any real trigger reads,
        so the stub fully covers it without resurrecting any other part
        of the old API. Doesn't touch the fragile native trigger XML
        itself, consistent with this project's established caution there.
      - **4 confirmed-dead functions removed**: `MyDSL_RouteHelper.lua`'s
        `Route.combat/scan/group/righthere` shorthands (zero call sites
        anywhere, including native XML — those windows are populated by
        their own View modules' MiniConsoles directly, not by raw-text
        routing, so this isn't a missing-routing bug, just superseded
        scaffolding). `Route.players` looked similar but is genuinely used
        3× in `MyDSL_DataLayer.lua` — kept.
      - **`MyDSL_ThemeEngine.lua`**: removed 3 dead functions
        (`titleCSS()`, `bodyTextCSS()`, `colorToEcho()` — zero call sites;
        every real consumer builds CSS itself via `get()`+`colorToCSS()`
        instead) and corrected the file's own header comment, which still
        named the dead functions as the intended Layer-3 contract.
        `setOverride()`/`clearOverride()` looked similarly dead but were
        NOT removed — `Theme.get()` still reads the `overrides` table
        they'd populate, so it was an incomplete-but-live mechanism, not
        pure dead code. **Steven's call: finish it — done 2026-08-23.**
        Added `theme override <window> <key> <value>` / `theme override
        <window> clear` / `theme override <window>` (show current) as
        real aliases, and persisted `overrides` into the same
        `MyDSL_theme_settings.lua` file `active` already uses (previously
        only `active` survived a reload). Numeric/string keys take a
        plain value; color keys take `"r,g,b"` or `"r,g,b,a"`. Needs live
        confirmation.
      - **`MyDSL_Help.lua` doc gaps closed**: added 3 real, working
        `mydsl leveling` commands that had zero documentation (bare
        `show`/`hide` toggling the window, `area info <name>`, `buff
        <name> <cast-cmd|off>`), and the 12-alias `charpic *` legacy
        vocabulary (`MyDSL_PortraitView.lua`) which had none at all.
      Found, NOT fixed (needs a decision, not a blind guess — same class
      as the `MyDSL.Windows.setTitle` no-op already tracked below):
      - **`MyDSL_Leveling.lua`'s own status window was permanently
        blank — Steven's call: wire it up — done 2026-08-23.** `L.log()`
        (writes to a dedicated MiniConsole created and styled for exactly
        this) was defined but never called anywhere; all real leveling
        output went through a separate `ce()`/cecho helper to the main
        console instead. Fixed: `ce()` now mirrors every line into
        `L.log()` too (kept the main-console line as well — Steven asked
        to see it in the window, not to relocate it away from where he
        already looks for it). Also fixed `L.log()` itself while wiring
        it up: it called `:decho()`, but every real message uses cecho-
        style named tags (`<cyan>`, `<reset>`) which `:decho()` doesn't
        understand — switched to `:cecho()` to match. Needs live
        confirmation.
      - **Lifecycle naming drift, cosmetic only**: 8 modules use
        `.init()`, 6 use `.boot()` for the same file-load-time role
        (`MyDSL_PortraitView.lua:1000` even bridges both:
        `CharPic.boot = function() return P.init() end`, showing this was
        noticed once and never resolved project-wide). No central
        dispatcher requires uniformity, so this is real but harmless drift
        — low priority, fix opportunistically if a module's being touched
        anyway, not worth a dedicated pass.
      - **Mapper vs. DataLayer: confirmed two fully independent GMCP
        parsers of the same `char_data`/`room_data` fields**, direct
        answer to Steven's "does mapper prompt collection help any other
        window" question: no, neither reuses the other's parsed output.
        Confirmed deliberate (the mapper fork is documented to survive
        standalone even without DataLayer loaded, with real staleness-
        guard reasoning behind the duplication), not an oversight — a
        real correctness-drift risk if DSL's GMCP shape ever changes (one
        side could get updated, the other silently not), but a known,
        already-reasoned tradeoff, not a new gap.
      - **`MyDSL/log/` (the live profile) had 5 large, substantial session
        logs from the past week (2026-08-16 through 2026-08-22, up to
        10MB each) never swept for this project's purposes** — the
        ~1-month gap in this repo's own commit history (last real code
        commit 2026-07-25) meant real play sessions went unreviewed.
        Checked: no `cecho()` bug markers from Steven in any of them, and
        the only recurring `[LUA]` errors are the `dslpnp` one (fixed
        above) plus two cosmetic native-mapper-alias errors (a disabled
        self-updater's version-check script erroring harmlessly on every
        login; `centerview: bad argument... roomID nil` when a mapper area
        alias is run with no room context) — neither is a MyDSL_*.lua bug,
        left alone as native-XML-only issues, same caution as `dslpnp`.
      - TODO.md-vs-code spot check (4 items): no drift found — every
        checked "fixed, needs live confirmation" item's code matches its
        TODO.md description exactly.
- [ ] **GitHub hosting — Steven's call 2026-08-23: yes, public repo. BLOCKED
      2026-08-23, same day, on a real finding — do not push before this is
      resolved.** The original "safe to make public" check only scanned
      the CURRENT tracked tree with a fixed set of secret-shaped regexes
      (password=, api_key, BEGIN...PRIVATE KEY, etc.) — it never looked at
      git HISTORY, and wouldn't have caught this shape anyway. While
      extracting `MyDSL_GameplayTriggers.xml` (see the tracking-completeness
      item above), found that filename was already git-tracked from very
      early in this project (commits `ef8b6d6` through `5c7944f`, a DSL1-era
      raw trigger extraction) — and that old version's `<mCommand>` field
      contains `y;;y;;m;;vzon;;[REDACTED, see CHANGELOG git blame if truly needed];;v`, an automated-answer sequence
      shaped exactly like a character-creation/login flow, with
      `[REDACTED]` sitting in the password/PIN slot. Ran a full scan of
      **every commit in the entire git history** (not just HEAD) for this
      shape (`word#digits`) and for any other `;;`-delimited answer
      sequence — confirmed this is genuinely the only instance anywhere.
      **Why this blocks the push**: this string only ever existed in that
      one old file, which my own extraction today already overwrote with
      current live content (the string is gone from the working tree and
      from HEAD once this session's commit lands) — but deleting it from
      the current file does NOT remove it from git history. A `git push`
      of the full history to a public repo would make every old commit,
      including this one, permanently browsable on GitHub. **Needs Steven
      to decide, not assumed**: (a) confirm whether `[REDACTED]` is/was a
      real, still-valid credential or something already changed/harmless,
      and (b) pick a path — rewrite history to purge it (`git filter-repo`
      or BFG, changes every commit hash), push a fresh single-commit
      history instead of the real one (loses commit-by-commit history),
      or keep the repo private instead of public. Not actioned in any
      direction without that decision.
- [ ] **Live per-window smoke test** — Steven asked for "go to each window
      and check functions connections, toggle on/off, all window commands,
      then confirm helpfiles match." The audit above covers the static
      half (helpfile text vs. registered commands); actually toggling each
      window and exercising each command needs Steven live in-game — needs
      a session together once the static audit lands.
- [x] **Full native-content inventory of the live MyDSL profile — done
      2026-08-23, one real gap found and fixed, everything else confirmed
      complete.** Per Steven's explicit ask ("make sure it includes the
      entire current state of the profile... check all the changes i made
      in game to triggers and scripts as well before losing them").
      Programmatically enumerated every Script/TriggerGroup/AliasGroup/
      KeyGroup in the live profile's newest `current/*.xml` (confirmed via
      each object's real XML container, not a name guess) and cross-
      checked every single one against known git-tracked source or the
      package build's known native-only exceptions:
      - Scripts (44 total), Triggers (296, under 91 TriggerGroups), and
        Keys (45, under 1 KeyGroup): **fully accounted for, zero gaps.**
        `DSL_Generic_Mapper`'s installed content is byte-identical to the
        tracked `DSL_Generic_Mapper.xml` across all 81 objects. Every
        Trigger/Key under `MyDSL_Full` is tagged `packageName="MyDSL_Full"`
        and already gets captured wholesale by `build_mydsl_package.py`
        on every rebuild (that's how the huge native GameplayTriggers
        taxonomy -- Areas/Actions/Atmosphere/Combat/Spells/Weather, dozens
        of sub-groups -- survives reinstalls without needing its own
        git-tracked source file). The remaining top-level Script/Alias
        groups (`gui-drop`, `mpkg`, `deleteOldProfiles`, `echo`,
        `run-lua-code`, `enable-accessibility`) are stock Mudlet/
        third-party infrastructure, already recognized in `.gitignore`.
      - **Real gap found: a top-level `Aliases` group with 29 real, hand-
        built personal aliases** ((k)/(oak) target-and-attack, (kall)/
        (lall) all-direction knock/look, (pqr)/(pqi)/(pqt)/(pqc)/(pqf)/
        (pqh) personal-quest shortcuts, (inv) multi-bag inventory, (RV)/
        (SW-dh)/(SW-dw) navigation macros, (casual)/(combat) attire
        swaps, (safetoleave)/(safetoreturn), (start writing)/(stop
        writing), (MYMOTD), (smoke *) roleplay macros) -- every one has
        `packageName=None`, meaning it was created directly in Mudlet's
        Alias editor and was never part of any package, so
        `build_mydsl_package.py`'s packageName-based capture could never
        have picked it up. **No backup of this content existed anywhere
        before today.** Extracted verbatim into a new git-tracked file,
        `MyDSL_PersonalAliases.xml` (a standalone, directly re-importable
        Mudlet package XML) -- verified via a full round-trip check
        (re-parsed the new file and diffed every alias's regex/command/
        script against the live source: 0 mismatches across all 29).
      - **Correction to a stale claim found along the way**: the DSL
        Generic Mapper fork install item (PACKAGING section below) said
        "not yet live-tested at all" -- the byte-identical check above
        proves it actually IS installed and has been for a while; that
        claim was simply never updated after Steven installed it.
      - **Not yet done, real next step**: `build_mydsl_package.py` still
        doesn't know about `MyDSL_PersonalAliases.xml` -- it isn't spliced
        into `MyDSL_Full.mpackage` automatically, so a from-scratch
        reinstall still wouldn't restore these 29 aliases without a
        manual import of the new file. Worth folding in properly (same
        packageName-splice pattern already used for GameplayTriggers)
        once there's time to test a rebuild+reinstall cycle against it,
        rather than rushed alongside discovering the gap.
      - **General lesson, worth remembering**: any native content created
        directly in Mudlet's UI without ever being installed as part of a
        package can silently escape every existing backup mechanism.
        `CLAUDE.md`'s housekeeping routine now includes a periodic full
        inventory check (not just the 2-3 previously-known exceptions)
        so this doesn't quietly happen again with some other hand-built
        trigger/alias down the line.
      - **Follow-up, same day (2026-08-23), per Steven: "make sure we are
        tracking all the scripts/code in mydsl."** Two more native
        objects had real functionality with zero readable git source
        (not at active risk of loss, since `build_mydsl_package.py`
        already re-splices both wholesale on every rebuild, but
        undiffable and unreviewable until now): the `DslColors_Core_v1_0`
        Script itself (138,754 chars -- the entire DSL color-coding
        engine) plus its `DslColors v1.0 Triggers` group, and the
        `MyDSL_GameplayTriggers` group (277 triggers) plus the native
        `MyDSL_Full` KeyGroup (45 movement/scan/look keys). Extracted
        verbatim into `DslColors_Core_v1_0.xml` and
        `MyDSL_GameplayTriggers.xml`, both round-trip verified against
        the live source (exact match on every object). Between these two
        files and `MyDSL_PersonalAliases.xml`, every single native
        Script/Trigger/Alias/Key actually in use now has real,
        git-tracked source -- confirmed by construction, since this was
        a full inventory, not a sample. Same "not yet folded into the
        build script's splice logic" caveat applies to both new files.
      - **Also fixed the same day, a genuinely different but related
        ask: "settings we have in the files should become default
        settings in the scripts... check dslcolor and window layouts
        themes etc."** Checked every settings-vs-hardcoded-default pair
        that actually exists:
        - **Window layout** (`MyDSL.Layout.defaults` in
          `MyDSL_LayoutEngine.lua`): nothing to sync. The live MyDSL
          profile has no `MyDSL_layout.lua` at all -- Steven has never
          run `mydsl layout save` -- so on-screen positions are governed
          entirely by Mudlet's own native geometry cache (see the
          PACKAGING section's fresh-install-docking item), not by
          anything this project's layout system controls. A stale
          `MyDSL_layout.lua` was found sitting in DSL2's own profile
          root (not MyDSL's) -- June-dated, referencing window names
          that don't even exist anymore (`MyDSL_AsciiMap`,
          `MyDSL_Equipment`, `MyDSL_Banner`...) -- confirmed pre-
          restructure dev-testing leftover, not real data, and deleted
          (gitignored, zero git impact).
        - **Theme** (`MyDSL.Theme.active` in `MyDSL_ThemeEngine.lua`):
          nothing to sync either. No `MyDSL_theme_settings.lua` exists
          live -- Steven has never run `theme set`, so the hardcoded
          default (`refined_convergence`) already is what's actually
          running.
        - **DslColors**: nothing separate to sync -- its accumulated
          title/palette/kingdom-color data lives inside the
          `DslColors_Core_v1_0` native script's own state, which is
          already captured fresh from the live (currently-tuned)
          instance on every rebuild by design, and is now also the exact
          content preserved in `DslColors_Core_v1_0.xml` above.
        - **Real fix found and made: per-window font-size fallback
          defaults were stale in 6 places across 5 files.**
          `MyDSL_windowfonts.lua` (the live, real, accumulated font
          settings Steven has actually tuned over time) has
          `MyDSL_RightHere=8, MyDSL_PlayersNear=8,
          MyDSL_CreatureReference=8, MyDSL_Scan=7, MyDSL_ItemReference=8,
          MyDSL_Focus=9` -- but every one of these windows' own
          `MyDSL.Windows.getFontSize(WIN, N)` fallback (used only for a
          brand-new window with nothing saved yet) still hardcoded the
          old pre-tuning value (9 for the first five, 11 for Focus). A
          genuinely fresh install was shipping the wrong, too-large font
          for all 6 windows until manually re-tuned by hand, every time.
          Fixed all 6 (`MyDSL_ScanView.lua` x2 windows x3 call sites each,
          `MyDSL_CreatureReference.lua` x3 call sites,
          `MyDSL_ItemReference.lua` x3 call sites,
          `MyDSL_TargetView.lua`, `MyDSL_RouteHelper.lua`) to match
          Steven's real live values. Does not change any current live
          behavior (the saved value always wins when present) -- only
          changes what a genuinely fresh window/install sees.

---

## PACKAGING — fresh-install status
- [ ] **`MyDSL_Full.mpackage` — one combined package, several rounds of
      real fresh-install feedback fixed, still needs a full live
      confirmation pass.** Current contents (33 scripts + GameplayTriggers
      + movement/door keys + DslColors, one import): the 31 MyDSL modules,
      chat fully self-contained (EMCO ported in, `MyDSL_Chat.lua`, no
      separate EMCOChat dependency), namespace fully MyDSL-owned (no
      `demonnic.*` left anywhere), `MyDSL_MovementSounds.lua` (recovered
      from a native-only script the earlier builds missed entirely — this
      is why the NumPad keys silently did nothing on the fresh profile),
      the native GameplayTriggers/keys/DslColors content scrubbed of every
      hardcoded character name and machine-specific path (sound triggers
      now resolve via `getMudletHomeDir()`, two door/portal triggers that
      could only ever fire for one specific character rewritten as
      wildcarded regex), and DslColors' own title list merged with
      Steven's full accumulated `dslcolor title` additions. `Sounds.zip`/
      `RoomPics.zip` ship separately (media can't be embedded in a
      `.mpackage`) — placement instructions in `INSTALL.md`.
      Still true from the original build: no packaged/documented process
      for the PNP base-client prerequisite (always manual, outside this
      session's visibility); `generic_mapper`/`DslColors` raw exports
      already sit in `~/Downloads/`. One required manual native step
      confirmed: disable the native `(autowhere)` alias. Full history:
      `CHANGELOG.md`; day-to-day detail: `INSTALL.md` shipped alongside
      the package.
- [x] ~~The actual package-build script has no durable, repo-tracked copy~~
      — **fixed 2026-07-19**: `build_mydsl_package.py` rewritten from
      scratch and committed to the repo (the original was lost with a
      session scratchpad). Bundles the git-tracked `.lua` dofiles (read
      fresh from disk, list auto-derived from DSL2's own reference
      `current/*.xml`, not hardcoded) plus native-only content pulled from
      the newest `current/*.xml` in the live MyDSL profile. Fails loudly
      on any structural mismatch instead of silently under-counting. Full
      detail + 3 real gaps it surfaced while being written:
      `docs/CHANGELOG.md` (2026-07-19).
- [ ] **DSL2's own dev reference profile has 3 dofile-wiring gaps — found
      2026-07-19 while writing the real build script, not yet fixed
      (manual Script Editor step, can't be done via file edit).**
      1. `MyDSL_Chat.lua` and `MyDSL_MovementSounds.lua` are both real,
      git-tracked files with no `dofile()` entry in DSL2's Script Editor —
      same class of gap as the older `MyDSL_PromptSetup` miss. The build
      script now works around this (reads both fresh from disk directly),
      but the real fix is adding the two `dofile()` entries so this
      doesn't keep depending on a workaround. 2. A stale `dofile()` entry
      for `MyDSL_ChatWrapper.lua` still exists in DSL2's Script Editor —
      that file was deleted when merged into `MyDSL_Chat.lua` (commit
      `4aca249`), but the old Script entry pointing at it was never
      removed. The build script skips it (loud warning), but it should be
      deleted by hand. 3. Two Script entries have display names that don't
      match their real filenames (`MyDsl_Alterform` for
      `MyDSL_AlterformView.lua`, `MyDSL_Creaturelore` for
      `MyDSL_CreatureLore.lua`) — cosmetic only (the build script derives
      the real name from the dofile path, not the display name), but worth
      renaming for anyone reading the Script Editor directly.
- [ ] **Windows resetting position when docking a second window on the
      fresh profile — likely root cause found, not fixed.** Confirmed
      NOT a recurrence of the previously-fixed Mudlet 4.21/4.22
      "suspicious shrinkage" bug (checked the actual running AppImage:
      still 4.20.1). Confirmed NOT the previously-fixed auto-reflow-on-
      resize bug either (`MyDSL_LayoutEngine.lua`'s own header comment
      documents that fix — no `sysWindowResizeEvent` handler exists
      anywhere in the current codebase, verified via grep). Real
      difference for a genuinely fresh profile: Mudlet's own native
      window-geometry cache (`windowLayoutGeometry.dat`/`windowLayout.dat`)
      lives at `~/.config/mudlet/` directly — confirmed via `find` —
      **shared across every profile on the machine, not per-profile**.
      Every UserWindow gets `restoreLayout=true` (`patchUserWindowConstructor()`,
      `MyDSL_WindowRegistry.lua`), which (confirmed by reading Mudlet's
      own bundled `GeyserUserWindow.lua` via the mounted AppImage) tells
      Mudlet's native engine to look up cached geometry by window name in
      that shared file. Since the fresh "MyDSL" profile uses identically-
      named windows to the original DSL2 profile, its windows are likely
      inheriting stale dock-state cached from the original profile's own
      layout history. Not touched — this exact class of file already
      caused a real regression once before in this project (TODO.md's
      own DECISIONS RECORDED: resetting it made the whole panel layout
      collapse, not fix anything) — needs discussion, not a blind fix.

---

## LOW PRIORITY — script wiring
- [ ] ChatWrapper tab active/inactive CSS still hardcoded — no ThemeEngine
      hookup. Real design pass, not a mechanical fix.
- [x] ~~`MyDSL_creaturelore.lua` (lowercase, profile root) is stale DSL1
      carry-over data~~ — **already gone, confirmed 2026-08-23.** Steven
      said delete it; turned out there was nothing left to delete — the
      lowercase file doesn't exist on disk or in the current git index at
      all anymore (`git log --all` shows it was tracked once, then
      disappeared from history at some point without a clean rename
      record — likely superseded in-place by the properly-cased
      `MyDSL_CreatureLore.lua`, the real active module). This TODO note
      was simply stale.
- [ ] `MyDSL.Windows.setTitle` doesn't exist anywhere in
      `MyDSL_WindowRegistry.lua` — found during the 2026-07-16 full
      codebase review. One call site (`MyDSL_AffectsView.lua:952`,
      `A.setTitle()`) is both existence-guarded and `pcall`-wrapped, so
      it's a silent permanent no-op, not a crash risk — but it means
      renaming the Affects window's title never actually notifies
      WindowRegistry, per that code's own comment about avoiding a
      "spam" feedback loop. Not fixed — unclear whether
      `Windows.setTitle` was removed deliberately or just never built;
      needs a decision, not a blind guess at what it should do.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or emulation — none of this
is closed until Steven confirms it in-game. Full technical detail for any
item: `git log --oneline` + `docs/CHANGELOG.md`.

- [ ] **`MyDSL_DataLayer.lua` room-capture: 3 more fixture-line gaps + a
      real NPC-verb gap, found via a full-codebase audit 2026-07-21,
      needs live confirmation.** Per Steven's "would it improve if we
      used a newer ai agent?" question, ran a systematic re-check of
      every bug class with a real fix-history entry in `docs/CHANGELOG.md`
      instead of waiting for the next live bug report. Found and fixed 4
      more real, corpus-confirmed instances of the same "beginLook()
      catch-all falls through, silently ends capture" bug class (6th-9th
      overall): `"Sturdy barstools line the outside edge of the lengthy
      bar."`, `"(Glowing) High above the cityscape, a jagged rip mars the
      sky..."`, and `"Dark marble benches are set facing the statue..."`
      (added as new `isLookFixtureLine()` substrings), plus a genuinely
      separate gap in the same investigation: NPCs described as `"stands
      behind the bar/counter"`/`"sits behind the counter"` (bartenders,
      shopkeepers) never matched any of `parseLookHereLine()`'s verb
      patterns at all (only "stands/sits HERE", not "behind X") — added
      as 2 new recognized patterns, corpus-confirmed recurring (barmaids,
      a gentleman, a young lady, Grokk). Verified via 2 new test files
      replaying the exact real corpus lines, including one case that
      looked like a bug at first but turned out to be correct existing
      behavior (a mount "walks in" — confirmed via corpus this is a
      transient arrival announcement like "Someone walks in.", not room
      content, so correctly does NOT become a captured mob). **Open
      architectural question, deliberately not decided unilaterally**:
      this is now the 9th instance of the same bug class fixed via an
      ever-growing literal-substring/leading-word allowlist. A broader
      "default to keep capturing unless a recognized terminator" redesign
      was considered and rejected for now — checked the corpus and found
      real counterexamples (indented lines that ARE genuine mob-shaped
      presence lines, e.g. `"A very large bind stone is here."`), so a
      blanket flip isn't a safe drop-in replacement without more design
      work. Worth a real discussion with Steven if this keeps recurring.
      Also removed one confirmed-dead orphaned event
      (`MyDSL.Live.ExitsColoredUpdated`, zero listeners anywhere).
      **Process change adopted as part of this same audit** (see
      DECISIONS RECORDED): `scripts/check_known_patterns.py`, a small
      grep-based checker encoding every historical bug class as a rule,
      wired into a `PostToolUse` hook (`.claude/settings.json`, now
      tracked in git via a `.gitignore` exception) so a fresh instance of
      a KNOWN mistake gets caught the moment it's written, automatically,
      no prompting required — plus `--all` for an occasional full-repo
      sweep to catch what's already latent in untouched files (exactly
      what this audit did by hand; now repeatable). Needs Steven to
      confirm the DataLayer capture fixes don't regress anything live
      (`isLookFixtureLine()`/`parseLookHereLine()` are heavily depended
      on — RightHere, Scan, Leveling, CreatureLore all read from them).
- [ ] **`MyDSL_Leveling.lua` — leveling-assist addon, 10 real bugs found
      and fixed across live testing, first genuinely complete run
      confirmed 2026-07-25.** Per Steven's original ask (auto-navigate
      known hunting areas, auto-engage enabled mobs, easy area/mob
      maintenance) plus a same-day follow-up round (mapper-based
      navigate-to-area, pause/resume, the followers/line-spacing
      shared-risk dependency), redesigned 2026-07-20 after live testing
      surfaced real UX problems (failsafe timer removed entirely, flee
      made non-fatal, start flow collapsed to one command, PNP-style
      end-of-run report added, `mydsl leveling areas`/`area info` display
      cleaned up) — see the approved plan and this file's own header
      comment for full design. Ships as a **separate outside addon** (per
      the passive-observation exception recorded below), NOT part of
      `MyDSL_Full.mpackage` — needs its own manual `dofile()` wiring.

      **2026-07-25: first real end-to-end success.** A full Olyndros
      leveling session on `philosophy` completed a full lap and printed
      the report correctly — 17m11s, 8 killed, 1229 XP (4291/hr) — with
      two clean pause/resume cycles mid-run. This is the first time the
      whole start→resume→walk-fight-loop→report flow has actually worked
      live, after 8 prior rounds of bugs (window-blanking on load,
      cross-profile seed-import path, aura/charmed-tag mob matching, a
      failsafe that fired mid-fight then was removed entirely, a
      load-order race with `MyDSL_DataLayer.lua`, a silent
      `map.speedwalk()` failure with no fallback directions, 3 more
      `isLookFixtureLine()` capture gaps, and a separate "stands/sits
      behind X" NPC-verb gap — see `docs/CHANGELOG.md` 2026-07-19 through
      07-21 for each).

      **2 more items found from this same successful run's log +
      Steven's own MyDSL-profile notes — 9 turned out to be a false
      alarm, not a real bug:**
      9. **RESOLVED 2026-07-25, no bug — the "(NNN)" lines Steven was
         seeing on the main screen are our own round-summary recap,
         working exactly as designed, not leaked/uncaptured raw DSL
         text.** Steven's original note ("damage still appearing in main
         window and not being moved to combat eradicate, devastate,
         unspeakable etc.") triggered a long misdiagnosis: a regex
         anchor-hardening fix (2026-07-25, since reverted in spirit — the
         code change is harmless and can stay, it just wasn't the real
         fix for anything), then two rounds of live diagnostic triggers
         (`MyDSL_CombatDiag.lua`, temporary/not packaged) to prove
         whether Mudlet's trigger engine was even seeing this text. It
         wasn't — because it isn't incoming game text at all. Traced
         character-for-character to `MyDSL_DataLayer.lua:4584-4588`
         (`combatRoundFlush`, fires once per round on GMCP `char_data`):
         `battleFormat(cfg.summary_format or "%a%r %n %v %t (%d)", {... d
         = p.dam ...})` then `decho(str)` straight to the main console.
         `%d` is `p.dam`, OUR OWN accumulated total (sum of fixed
         `DAM_INFO` severity scores across every swing that round) — not
         a real DSL damage roll — and `%v` is `calcDamVerb(p.dam)`,
         which picks whichever tier-word's fixed score best fits that
         accumulated total. This is why the same word (e.g. OBLITERATE)
         showed different numbers every time (round totals vary) while
         some single-hit rounds showed an exact `DAM_INFO` score (e.g.
         MASSACRE `(50.5)`, exactly `DAM_INFO.MASSACRE.score`). The
         accompanying condition line (`"X has quite a few [50-74%]"`)
         is the same mechanism, `MyDSL_DataLayer.lua:3260`
         (`combat.pending_condition.screen`), decho'd right after.
         `decho()` output is local script output, never incoming game
         text, so no regex trigger — ours or a deliberately dumb
         diagnostic one — could ever have caught it; that's also why the
         diagnostic showed zero hits on these exact lines while catching
         everything else nearby. Individual swings were being parsed
         correctly the entire time (confirmed via
         `MyDSL/logs/combat/<Char>/<date>.log`, which only gets a line
         once a swing is actually parsed — thousands of correctly-tagged
         entries spanning the whole session). Steven confirmed
         2026-07-25 he wants this recap kept exactly as-is — no code
         change needed. `MyDSL_CombatDiag.lua` (repo root) is a leftover
         throwaway diagnostic, never part of `MyDSL_Full` — delete the
         file and its Script Editor entry, it has no further purpose.
      10. **Focus/TargetView never populated during a Leveling
          fight — fixed.** Steven's note: "target window not populating
          when im in combat, should become the target im fighting, have
          all the mob info etc." Confirmed against this exact session's
          log: zero Focus/TargetView activity the whole run. Root cause:
          Leveling tracks its own kill target independently
          (`L.session.pendingKillMobKey`) and never told the shared
          `MyDSL.Target` API about it. Fixed: `tryKill()` now calls
          `MyDSL.Target.set(mobDef.label, true, "leveling")` right when
          it sends a kill command — Focus's own existing auto-clear/
          advance-on-death logic (keyed off `MyDSL.combat.died`) should
          then handle the rest for free, no separate wiring needed.

      All fixes verified via structural tests: `test/test_leveling.lua`
      (37 assertions, up from 35), `test/test_leveling_load_order.lua` (8
      assertions), `test/test_datalayer_audit_fixture_lines.lua` (5),
      `test/test_datalayer_several_fixture_line.lua` (4),
      `test/test_windowregistry_merge.lua`, `test/test_combat_damage_regex.lua`
      (7). All 10 suites + a full known-bad-pattern sweep re-run clean.
      **Separately found, flagged, NOT fixed (unrelated, pre-existing, out
      of scope, Steven has since minimized it himself)**: a native
      "Charge" trigger errors on `dslpnp` being nil.

      Combat routing itself needs no further work (see item 9 above —
      resolved as a false alarm, not a bug). Remaining open item: confirm
      Focus now shows the current target during a Leveling fight
      (item 10's fix, not yet live-confirmed).
- [ ] **DSL Generic Mapper: real "air" terrain gap, plus dropped the
      spammy line-buffer dump from `dslroom raw` — fixed 2026-07-18,
      needs live confirmation.** Per Steven ("is there a terrain color
      for air? its not adding it to the mapper"). Confirmed via his own
      live log: DSL's real response to `terrain` while flying/airborne
      is `"There is no terrain, your in the air!!!"` -- a completely
      different message shape than every other terrain line (none of the
      other 11 start with "There is no terrain"), so it never matched
      any pattern and fell through `normalizeSector()`'s catch-all
      unrecognized, ungrouped, uncolored. Added the pattern to the DSL
      Terrain Capture trigger, taught `normalizeSector()` to recognize it
      as a new `air` sector, and gave it its own environment color (sky
      blue, ID 33 -- the sequence continues cleanly from the existing
      12 sector colors). Also removed the "Recent line buffer" dump from
      `dslroom raw` per Steven's separate note ("it spams the screen and
      isnt needed") -- the room-block dump in the separate "no room
      resolved yet" fallback branch is untouched, only this one. Verified
      the exact real log text normalizes correctly via a structural test.
- [ ] **DSL Generic Mapper fork brought into the repo, reviewed, and
      hardened — needs a manual install swap + live confirmation.** Per
      Steven ("its time to incorporate the mapper and make it for DSL not
      generic, too many small issues seem to be occurring"). This
      supersedes the 2026-07-17 "harden the mapper" investigation
      (`CHANGELOG.md`), which correctly found no bug in *stock*
      generic_mapper at the time -- Steven's ask this time is different:
      replace stock generic_mapper with a maintained DSL-specific fork,
      not fix a specific bug in the stock one. Found real prior art
      already sitting in `~/Downloads/` (`DSL_Generic_Mapper_
      Minimal_Hardening_Scope.md` + versions 0.1.0-0.2.2, dated
      2026-07-02/03, predating this repo's current workflow) -- a
      conservative-fork layer on top of unmodified Generic Mapper 2.1.8,
      never actually deployed (confirmed: the live MyDSL profile was
      still running stock generic_mapper). Reviewed 0.2.2 in full against
      its own scope doc: 7 of 8 required hardening items were already
      correctly implemented (description-matching default, DSL movement-
      fail/restricted-exit patterns fed into Generic's own onMoveFail
      handling rather than a parallel system, all 11 required door
      patterns, GMCP assist that explicitly never creates rooms directly,
      room-description capture matching our own `MyDSL_DataLayer.lua`
      technique, sector metadata with a GMCP-vs-terrain-command conflict
      flag, and a thoroughly-disabled self-updater -- traced every
      download-related code path to confirm none are reachable anymore).
      Found and fixed 3 real bugs before deployment: (1) the door-verb
      command parser used `cmd:match("^(open|close|lock|unlock|pick)...")`
      -- `|` is not an alternation operator in Lua patterns (that's a
      regex-only construct), so this could never match ANY real command;
      the entire door-verb capture was dead code in the shipped 0.2.2
      build. Fixed with a per-verb loop. (2) Once verb-matching actually
      worked, a second bug surfaced: "open backpack"/"close pouch"-style
      container actions (DSL's own help confirms `open <object|
      direction>` are both real syntax) got silently misattributed to
      the last movement direction instead of correctly resolving to no
      room exit at all -- fixed by clearing both pending door/move
      contexts on a non-directional action. (3) `last_door_command`/
      `last_move_command` recorded a timestamp that nothing ever checked
      -- added a 6-second freshness window so a stale context can't be
      replayed against a much later, unrelated message. All 3 verified
      via structural tests (`test_mapper_fork_fixes.lua`). Also
      cross-referenced all patterns in the English Failed Move (25),
      DSL Door State Capture (15), and DSL Terrain Capture (11) triggers
      against the full log corpus (DSL2 + MyDSL + PNP/DSL1 sibling
      profiles): the large majority confirmed real with direct quotes; a
      handful unconfirmed but harmless (likely valid for other MUDs
      Generic Mapper supports); one real gap found and fixed -- the
      "standing too close to the lock" door-block message was hardcoded
      to one specific NPC name ("A New Thalosian gate guard") when the
      real message is a generic template any NPC can trigger (confirmed
      via 4 different real NPCs producing the identical message in
      sibling logs) -- wildcarded to match any NPC. Brought into the repo
      as `DSL_Generic_Mapper.xml` (git-tracked source) +
      `docs/DSL_Generic_Mapper_Scope.md` (the controlling scope note).
      Packaged separately as `DSL_Generic_Mapper.mpackage` -- this is a
      **replacement** for stock `generic_mapper`, not additive; installing
      it requires uninstalling the stock package first (same class of
      manual step as disabling the native `(autowhere)` alias).
      **Correction 2026-08-23: the install itself is confirmed done, not
      "not yet live-tested."** A full native-content inventory of the live
      MyDSL profile (prompted by Steven: "check all the changes i made in
      game to triggers and scripts... before losing them") found the
      installed top-level `DSL_Generic_Mapper` Trigger/Alias/Script groups
      byte-identical to this repo's own tracked `DSL_Generic_Mapper.xml`
      across all 81 objects -- confirmed programmatically (extract both,
      diff by name+content), not assumed. This TODO note was simply
      stale; the earlier "needs Steven to actually install it" framing
      predates an install that already happened and was never reported
      back. Still genuinely open: whether the fork's *behavior* holds up
      over real play (the room-weight/coloring/`dslroom raw` items right
      below this one) -- that's a different question from "is it
      installed," which is now closed.
- [ ] **DSL Generic Mapper: room weight from real movement-point cost +
      terrain-based room coloring — built 2026-07-18, needs live
      confirmation.** Per Steven ("hook up all the features we can... the
      terrain and room weights"), researched Mudlet's own Manual:Mapper
      Functions wiki page for `setRoomWeight`/`getRoomWeight`/`setRoomEnv`/
      `setCustomEnvColor` semantics before building anything (confirmed:
      every room defaults to weight 1, higher = less desirable to
      pathfind through; environment IDs 1-16 and 257-272 are reserved by
      Mudlet). First implementation used a hand-picked sector-to-weight
      table -- Steven caught this immediately ("dont make up weights, the
      room weight should be added as a player walks through and uses
      movement points to determine") and it was replaced before shipping.
      Real mechanism: `map.dsl.captureMovePoints()` records
      `gmcp.char_data.move` (the same real GMCP field
      `MyDSL_DataLayer.lua` already reads) the instant a movement command
      is sent; `map.dsl.applyMoveCost()` reads it again once the
      destination room resolves and stores the delta as that room's
      observed entry cost, averaged across repeat visits
      (`dsl.move_cost_samples`/`dsl.move_cost_total` room userdata) so one
      visit landing on a natural regen tick can't permanently skew the
      weight. Guards: cost outside a plausible 1-20 single-step range is
      discarded rather than corrupting the average; a room the player
      manually re-weighted via the native `rw` alias is never touched
      again (that alias now stamps `dsl.weight_source="manual"`). Room
      coloring is a separate, purely cosmetic feature (not a data claim
      the way weight is) -- `map.dsl.applySectorColor()` maps the
      already-confirmed-real sector categories to custom environment
      colors via `setCustomEnvColor()`/`setRoomEnv()`, registered once at
      install. No manual-override guard exists for color specifically --
      Mudlet's native map-UI right-click recolor calls `setRoomEnv()`
      directly with no script hook to intercept, so a manual UI recolor
      could get reverted on that room's next auto-color pass; accepted as
      a cosmetic-only tradeoff. Verified via a dedicated structural test
      harness (`test_move_cost_weight.lua`): a real cost becomes the room
      weight, a regen-tick (negative-cost) reading is correctly ignored,
      repeat visits average into a stable weight, and a manually-set
      weight is never overwritten. Not yet live-tested.
- [ ] **DSL Generic Mapper: `dslroom raw` is now a one-stop room-info
      command — built 2026-07-18, needs live confirmation.** Per Steven
      ("can i view room info in this package? like description name
      weights terrain features etc"). Turned out most of this already
      existed natively -- `rl`/`room look` (stock Generic Mapper) already
      shows name, area, coordinates, weight, environment color,
      description, exits with their weights, special exits, and per-room
      map features. `dslroom raw` now calls `map.roomLook()` first (reused
      directly, not re-implemented) and appends only the DSL-specific
      fields it doesn't know about: GMCP/terrain-command sector, sector
      conflict flag, and weight source with real movement-sample count +
      average cost. One command instead of two scattered ones. Not yet
      live-tested.
- [ ] **DSL Generic Mapper: `dslroom raw` showed blank fields instead of
      "not set yet" — fixed 2026-07-18, confirmed against Steven's real
      log output.** Steven's own live test surfaced `Room weight: 1
      (source=, samples=, avg cost=0.0)` -- checked the actual log
      (`MyDSL/log/2026-07-18#14-04-19.html`) and confirmed the real root
      cause: `getRoomUserData()` returns an EMPTY STRING for an unset
      key, not `nil` -- so plain `tostring(getRoomUserData(...))` silently
      printed a blank instead of a clear placeholder. New
      `map.dsl.dsl_ud(rid, key, placeholder)` helper wraps every display
      read in `roomRaw()`/`dslroom raw` so this can't recur field-by-field;
      confirmed the underlying weighting/coloring *logic* was never
      affected by this (it already compared against a specific non-empty
      string like `"manual"`, or explicitly checked for `""` itself where
      it mattered) -- purely a display bug. Also confirmed via the same
      log why that specific room showed 0 movement samples: the
      character was flying the entire time (`MV` stayed at 140/140
      across every prompt line in the log, never dropping), and DSL
      appears not to charge movement points for flying -- the
      real-cost-based weight system can only ever learn from movement
      that actually costs MV, so a flying character will rarely
      accumulate real weight data. Not a bug, a real limitation of this
      specific data source; noted for Steven, not silently assumed.
      Verified via a dedicated structural test
      (`test_dsl_ud_display_fix.lua`) replaying the exact blank-output
      scenario. Not yet re-tested live.
- [ ] **PlayersNear font size not surviving a reload — fixed 2026-07-18,
      needs live confirmation.** `MyDSL_RouteHelper.lua`'s `FONT_SIZE_OVERRIDES`
      seed table only ever read `MyDSL_History`'s size back from disk at
      file load; `MyDSL_PlayersNear`'s font command (added 2026-07-16)
      never got a matching seed entry, so every reload silently reverted
      to the hardcoded default regardless of what was actually persisted.
      Fixed by seeding both. Checked every other window's font
      persistence for the same class of bug — everyone else reads
      `MyDSL.Windows.getFontSize()` fresh inside their own render
      function rather than caching it at load time, so this was specific
      to RouteHelper's two routed windows.
- [ ] **2026-07-16 "what's left" build pass — cleared several buildable
      backlog items, checked out several more that turned out to
      already be resolved or unconfirmable.** Built:
      - TargetView Consider: added the remaining 4 of 6 real difficulty
        tiers (was only 2) — "The perfect match!", "<mob> says 'Do you
        feel lucky, punk?'.", "<mob> laughs at you mercilessly.", "Death
        will thank you for your gift." — confirmed via the PNP sibling
        profile's own log corpus (DSL2's own corpus had zero examples of
        these rarer tiers). `captureConsider()` just stores the raw line
        verbatim, so the two nameless tiers needed no special handling.
      - Item Reference had no `LayoutEngine` default position at all
        (fell back to a generic corner-ish default, which is why it
        landed tabbed alongside the much larger Scan/Combat/Bestiary
        group). Added a real compact default near Portrait/Location, per
        Steven's "compact... top left corner" ask — **only takes effect
        after `mydsl layout reset` or a manual drag+`mydsl layout save`**,
        LayoutEngine can't move an already natively-docked window.
      - Help window auto-showing on load — root cause confirmed: not a
        code bug, leftover `visible=true` saved state on Kien/Qinrathaz/
        Vaelis's window-state files from testing the Help window earlier
        the same session. Corrected directly to `false`, matching the
        registry's own intended default (Vrokt's file already had it
        right, confirming the default logic itself was always correct).
      - Wired `MyDSL.resolveGroundItem()` (built last pass, never
        connected to anything) into an actual hover on ground items seen
        via `look`, same `selectString()`+`setLink()` technique as the
        equipment hover — only attaches when a real resolution exists,
        no hover for the fraction of items with no reliable match. Added
        the "manual map option" Steven asked for: `item map <ground
        text> = <inventory/equipment name>`, added as a branch inside
        the existing `item <name>` dispatcher (not a separate alias —
        a standalone one would have collided with that dispatcher's own
        catch-all and sent `identify map ...` to the server as a real
        game command, caught before it shipped). Verified via a
        structural test: clean matches get a hover, declined matches
        don't, a manual override both resolves correctly and gets a
        hover on the next sighting.
      Checked and found already resolved (no longer open, TODO note was
      stale): `detect magic`'s onset text and "heart blight" were both
      already fixed in `docs/CapturedPatterns_Reference.txt`, just not
      flagged done; "heart blight" moved from a trailing annotation into
      the main alphabetized table. CreatureLore's `lore <name>` gap was
      based on a misunderstanding (see DECISIONS RECORDED).
      Investigated and deliberately NOT built (real reasons, not just
      time): TargetView aura-based auto-targeting — explicitly marked
      "not yet scoped" (unlike Consider/debuffs which were marked
      ready), and building it would require restructuring
      `parseScanLine()`/`parseLookHereLine()` to preserve aura-tag data
      they currently discard entirely, plus it changes combat-target
      selection automatically, which has real correctness stakes if
      wrong — needs a scoping discussion, not a blind build. TargetView
      "show debuffs on target" (weaken/slow) — TODO claimed this was
      "confirmed and ready to build," but a fresh corpus search (DSL2 +
      the PNP sibling profile) found zero real third-person/observer-
      side text for either debuff landing on someone else, only
      self-referential "You feel..." text for when it lands on you. The
      "confirmed" claim doesn't hold up; not building off an unconfirmed
      pattern. Quest-tracking (DEFERRED item) — checked the corpus for
      real quest start/expire/complete message text, found only helpfile
      prose about how quests work, no actual game echoes; still nothing
      to build against.
      All syntax-checked; Consider triggers, ground-item hover, and the
      manual-map override all verified via structural test harnesses.
      None of this is visually confirmed live yet.

- [ ] **Location/Portrait "ran smoother before the Mudlet update" —
      partially investigated, root cause NOT found, needs more specifics
      from Steven.** Checked: Portrait's own code hasn't changed since
      2026-07-12 (git log), and a fresh screenshot (`Screenshot_20260716_
      174348.png`) shows Portrait rendering correctly. Location's panel
      in that same screenshot was fully blank — no image AND no "No room
      picture" caption text either, which shouldn't happen if `M.render()`
      reached its normal missing-picture path (that path, and the
      `M.clear()` bug just above, are real but don't fully explain a
      totally blank window with no caption). Need: which Mudlet version
      is currently running (Help > About), and whether this is
      specifically about Location, Portrait, or both — "ran smoother"
      could mean scaling/quality, timing/flicker, or something else
      entirely; a plain description or a fresh screenshot showing the
      actual visual problem (not just a room with no picture assigned)
      would narrow this down a lot faster than more static code reading.
- [ ] CharacterAssist: rearm (weapon+shield) — spellup/setspell and the
      blind-vision check are confirmed working (2026-07-15); rearm itself
      hasn't been separately confirmed yet.
- [ ] **New: `MyDSL_AutoWhere.lua`, built 2026-07-16, both manual wiring
      steps confirmed done, needs live confirmation.** Per Steven ("roll
      autowhere into mydsl but improve it so it pays attention to states
      like sleeping, fighting, blind etc (any time it doesnt work)").
      Replaces Steven's native "(autowhere) AutoWhere" alias (plain
      `send("where")` on a fixed 20s timer, no state awareness) — new
      version skips a tick while `MyDSL.State.char.posn == "Sleeping"`,
      `is_fighting == true`, or `MyDSL.CharacterAssist.checkVision() ~=
      "can see"` (reused directly from `MyDSL_CharacterAssist.lua`'s own
      confirmed vision check, exported for this — was `local`, now
      `CA.checkVision()`). Same command vocabulary as the native version
      (`autowhere on|off|status`), same class of user-toggled assistive
      automation as CharacterAssist's rearm/spellup (not a new exception
      to "never send automatic commands" — the player still explicitly
      turns it on). Syntax-checked via luajit. Both manual steps confirmed
      live in `current/2026-07-16#15-38-37.xml`: the `MyDSL_AutoWhere`
      Script entry is `isActive="yes"` (correctly after
      `MyDSL_WindowRegistry`/`MyDSL_ThemeEngine` in the load order), and
      the native "(autowhere) AutoWhere" alias is now `isActive="no"`.
      Ready to actually test in-game. Sleeping/fighting/blind skip
      conditions are per Steven's own direct in-game knowledge, not
      independently log-corpus-confirmed — flag if another state turns
      out to need a skip too.
- [ ] **Roller double-reject bug — fixed 2026-07-18, needs live
      confirmation.** The legacy native `roller` trigger was never
      disabled after the 2026-07-07 Lua port, so it kept independently
      sending "n" in parallel with the module — a roll that cleared goal
      and printed `[PAUSE]...Review manually!` could still get
      auto-rejected out from under the player. Now disables the native
      trigger on load; also fixed a stale-reject-timer race (roll-
      generation counter + `R.paused` flag) and anchored the stat-line
      regex to the start of the line. Syntax-checked via luajit; no
      structural test exists for this despite the original changelog
      entry's phrasing — see `docs/CHANGELOG.md`'s 2026-07-19 correction.
      Needs confirmation on the next reroll.
- [ ] **PVP performance pass — built 2026-07-19, needs live confirmation
      during an actual fight.** Code-audit-based (no per-line timestamps
      exist in any log): fixed `logWindow()`'s per-combat-line `mkdir -p`
      shell spawn, `MyDSL.save()`'s synchronous full-table disk write on
      every affect event (now debounced 1.5s + flushed on disconnect/
      exit), the raw-capture trigger matching every line even while off,
      the mapper's O(n) line-buffer shift on every line of game output,
      and unconditional `setRoomUserData()` rewrites on every room
      arrival. Full detail + what was deliberately not touched (combat-
      regex lookbehind, weather double-parse, etc.): `docs/CHANGELOG.md`
      (2026-07-19).
- [ ] **Data-loss incident: `MyDSL_Full.mpackage` reinstall wiped native
      triggers/keys — recovered 2026-07-19, package rebuild fixed going
      forward.** Reinstalling wiped ~247 hand-built native Triggers, all
      45 Keybindings, and 2 hand-placed Scripts that lived inside the
      same Mudlet package folder but weren't known to the build script.
      Recovered from a snapshot XML; the package build now splices those
      real native blocks in directly, so a reinstall is a genuinely
      complete replacement rather than a lossy one. **Still true going
      forward**: anything Steven adds to that native folder by hand is
      invisible to the next rebuild unless it's git-tracked or moved to a
      separately-named folder Mudlet won't touch on reinstall — not yet
      done, worth doing before the next hand-added native item. Full
      detail: `docs/CHANGELOG.md` (2026-07-19).
- [ ] **Mapper code-review — 7 of 10 findings fixed 2026-07-19, needs live
      confirmation.** Real correctness fixes: `onMoveFailCleanup()`'s
      unsound re-search removed, `search_on_look` no longer resets on
      every reload, zero-wait speedwalk door/move misattribution fixed via
      real FIFO queues, `applyMoveCost()`'s silent discard now has debug
      visibility, `name_search()` no longer wipes a good description, GMCP
      `room_data` staleness guard added. Swim/ocean/underwater terrain gap
      investigated, not guessed at (tracked in `docs/DSL_CommandRef.md`'s
      STILL NEEDED section). Full detail: `docs/CHANGELOG.md` (2026-07-19).
- [ ] **ItemLore: identify couldn't clear stale shatteredarchive-scraped
      fields — fixed 2026-07-19, needs live confirmation.** Per Steven
      ("when an item is identified in game, it doesnt replace the
      shattered archive info and persist. it reverts to shattered info
      not the identified info"). `IL.merge()` treated a confirmed-empty
      `identify` result (e.g. real "extra flags none") the same as
      `lore`'s genuine partiality, so a stale/wrong scrape-imported value
      in `extraFlags`/`weaponFlags`/`armorClass`/`affects`/`spellCharges`/
      `spellList`/`drinkLiquid`/size+condition+capacity+maxWeight+
      weightMultiplier could never get cleared by a real identify.
      Confirmed live via "badger claw"'s actual DB record. Fixed:
      identify captures now authoritatively clear these fields when
      absent; `lore`'s fill-gaps-only behavior is unaffected. Verified via
      a new real structural test (`test/test_itemlore_merge_fix.lua`, 9
      assertions, all passing). **Items already identified once before
      this fix still need a fresh in-game identify** to clear their own
      stale fields — no safe blanket auto-cleanup exists (no per-field
      provenance tracking to tell real data from scrape leftovers).

---

## TOP PRIORITY — Combat, needs live-fight testing
Per-swing main-console display, evasion triggers, both death-line forms,
weapon-flag proc attribution, and the PNP-faithful display rewrite are all
confirmed correct (code review + a real live fight, 2026-07-11) — see
`CHANGELOG.md`. Still open:
- [ ] **DEFERRED, per Steven ("we can wait a bit longer on")**: Algoron
      Combat League (AGL) / Coliseum combat module — new idea, not
      scoped. Coliseum/AGL combat should be captured separately, in a
      large window with 4 floating sub-windows at the cardinal positions
      matching the Coliseum's wall echoes. Groundwork (bracket-prefix
      format, applicable procs) already gathered — see CHANGELOG.
- [ ] **Fight-summary conclusiveness — checked 2026-07-16, per Steven
      ("stat block is fine as long as it reports all combat actions and
      spells/skills used with landing %, just want to be sure its
      conclusive").** Real, evidence-based picture, not a guess:
      - **Confirmed captured, no gap**: any skill/attack whose DSL text
        uses the same "attacker's `<noun>` `<intensity-verb>`s target"
        grammar as regular weapon swings is already captured by the one
        unified `combatDamage` trigger, with the skill name simply
        appearing as the noun — confirmed via real corpus text
        (`log/clog1`): "Coenin's backstab maims Zecnys!" matches this
        shape exactly, so backstab damage already flows into
        `renderSummary()`'s hit/miss/landing-% table today, no special
        handling needed.
      - **Confirmed NOT captured, and genuinely can't be from text
        alone**: skills whose effect isn't a damage line at all (bash's
        knockdown, trip, riot's rage buff, dirt-kick's blindness) —
        checked their real native-XML flavor text, none of it has a
        per-hit damage number in DSL's own output to begin with, so
        there's nothing for a "landing %" to attach to for these.
      - **Genuinely unconfirmed, the one real gap**: whether direct-
        damage offensive spells use this same grammar or something else
        entirely — searched the full `log/` corpus for every attack-spell
        name in this game (shock bolt, firebolt, lightning bolt, magic
        missile, etc.) and found zero real combat-damage examples, only
        inventory/practice-list mentions. Can't confirm this is captured
        OR that it's missing — needs an actual live fight where a damage
        spell gets cast and logged, then a check of whether it shows up
        in the summary afterward. Steven's call to keep the current
        stat-block format stands; this is the one loose end on
        "conclusive," not a redesign question.
- [ ] **Double condition-line echo in combat — fixed 2026-07-16, needs
      live confirmation.** Per Steven ("if its just a duplicate line lets
      not duplicate it," after the item 7 explanation). Confirmed exactly
      why: in condensed mode (the default), `parseCombatConditionLine()`'s
      gag formula (`MyDSL_DataLayer.lua`) never deleted the raw DSL
      condition line specifically BECAUSE `summarize_damage=true` was
      excluded from the delete condition — the assumption being something
      else would hide it, but nothing did, so the round-flush handler's
      own `decho()`'d recap showed up right alongside the untouched
      original. Confirmed via PNP's own source (`DSL_PNP_Battle.lua`
      lines 315/414-415) this exact double-show has always been PNP's
      own original behavior too, not something introduced here — fixing
      it anyway per Steven's explicit call, diverging from PNP on this
      one point. Fix: added `summarize_damage` into the delete
      condition's OR clause, so the raw line is now deleted in condensed
      mode too (only the recap shows). Raw mode is unaffected (nothing in
      its OR clause is true, so nothing gets deleted there — same single
      line as always); `show_condition=true` still overrides and forces
      the raw line to stay, unchanged. Syntax-checked via luajit.

---

## PAUSED — needs more captured log data before further progress
Per Steven: "lets pause the capture logs phase... we will return to them
when we have more data to scan." **2026-08-23: re-checked all 5 items
against a wider search** (every sibling profile, both `log/Archive.zip`
files, and a previously-unswept `~/Downloads/logs.zip`, 121 files) — 3 of
5 now have real evidence, 2 remain genuinely unconfirmed anywhere on this
machine.
- [x] **Quoted weapon names (`"Nadrik's Honor"`) — confirmed real AND
      confirmed already working, no bug.** Real line: `Tsacherus is
      knocked to the ground by "Nadrik's Honor".` (multiple independent
      sources). Directly tested `MyDSL_DataLayer.lua:4487`'s existing
      Stunning-proc regex (`^([\w\-\s,'"]+) is knocked to the ground by
      ([\w\-\s,'"]+)\.$`) against the real line — the character class
      already includes `'"`, so it captures `"Nadrik's Honor"` correctly
      as-is. No fix needed; closing this out rather than leaving it open
      on old uncertainty.
- [ ] `procUnholy`/`procManaSelf` — still zero occurrences anywhere on this
      machine after the wider 2026-08-23 search. Unchanged.
- [ ] `combatSense1/2` (sense-based evasion) — still zero occurrences
      anywhere. Needs a bard specifically playing/logging. Unchanged.
- [x] **`A.ids.triggers.song` (AffectsView "Song:" format) — confirmed
      real 2026-08-23**, this time independently in DSL2's own corpus, not
      just older pre-DSL2 data (`Song : song of war       : modifies
      damage roll by 2 for 12 cycles, (6 hours)`), matching the current
      trigger's regex exactly. **Real capture gap found alongside it**: a
      modifier-less variant (`Song : song of war` / `Spell: toughness`,
      no "modifies...by...for...cycles" clause) matches neither
      `A.ids.triggers.song` nor `A.ids.triggers.spell` — both regexes
      require that clause. Recorded in `docs/DSL_CommandRef.md`; ready to
      build (loosen both regexes to make the modifier clause optional)
      whenever picked up.
- [ ] **Mage-cast `poison` spell's onset text — re-characterized, still not
      confirmed as spell-specific.** `"...looks very ill."` now has 3
      independent real occurrences (up from 1), all immediately following
      a poison/venom-gas attack landing (a dragon-figurine item power, a
      warthog's venomous spit) — reasonably strong evidence this is DSL's
      generic poison-onset reaction text, but still zero occurrence of it
      following an actual `cast poison` line specifically. Could build
      against the generic pattern now if source-agnostic capture is
      acceptable; the mage-spell-specific claim stays unconfirmed.

---

## OPEN — Reported bugs, not yet fixed
- [ ] **Sibling-profile log scanning** — a targeted `grep -r` for a
      specific known phrase across every file in a sibling profile can
      still pay off even when the profile looks mostly like debug noise;
      sampling one large file isn't representative. Worth repeating for
      other specific phrases if this comes up again.
- [ ] **Fuzzy name-matching (mob ID + item ground-mapping) — built
      2026-07-16, needs live confirmation.** Ported the tolerant-matching
      technique found in the Shattered Archive client's own equipment
      code (`useEquipmentDeltas.ts`): normalize both sides (strip leading
      article, ground-sentence suffixes, punctuation), score exact=100 /
      substring-either-direction=50, and refuse to pick a winner on a tie
      — a false merge is worse than no match. Added as
      `normalizeForMatch()`/`bestFuzzyMatch()` in `MyDSL_DataLayer.lua`
      (right before `resolveMobName()`), shared by two callers:
      - **`resolveMobName()`** (mob ID in RightHere/CreatureLore) — used
        to be exact-key-only, so a generic/truncated `look` capture (e.g.
        "a gnome" from "A gnome is here using levers...") could never
        resolve to a fuller CreatureLore-known name ("gnome machinist")
        since those are different keys. Now tries the current room's own
        `scan.byName` capture first (small, same-room-visit, least
        collision risk — matches Steven's own example exactly), then
        falls back to the full CreatureLore DB.
      - **`MyDSL.resolveGroundItem(key)`** (new) — ItemLore's counterpart.
        Requires two new capture pipelines that didn't exist before this:
        ground-item storage (`MyDSL.captureGroundItem()`, wired into
        `beginLook()`'s fixture-line branch — these lines used to be
        skipped and discarded, never stored) and inventory capture
        (`MyDSL.beginInventory()`/`parseInventoryLine()`/`endInventory()`,
        triggered on `"You are carrying:"`, same begin/body/end shape as
        equip capture — inventory capture didn't exist at all before this).
        Checks ItemLore's own DB by exact key first, then fuzzy-matches
        against every known equipment slot + inventory item.
      Verified via a structural test harness (`test/mudlet_mock.lua` +
      the real functions): mob resolution correctly resolves "a gnome" to
      "a gnome machinist" via scan.byName; inventory capture correctly
      parses counts/flags/plain lines; ground-item capture correctly
      stores items previously only skipped; `resolveGroundItem()`
      correctly matches "a decanter of endless water" against the
      inventory candidate and correctly declines to match "a mallet used
      to shape metal" against "a shaping mallet" (no shared substring —
      the honest "best effort, not everything" behavior Steven asked
      for). Not yet wired into any display/hover UI — this is the
      resolver only. Syntax-checked.
- [ ] **RightHere silently dropping mobs listed after an uncovered
      item-flavor-text line — fixed 2026-07-16, needs live confirmation.**
      Found via a structural trace of a real room-look
      (`log/2026-07-16#17-23-54.html`), same recurring bug class fixed
      three times before (2026-07-08/09) for different sentence
      templates. `beginLook()`'s catch-all falls through
      `isLookFixtureLine()` -> `parseLookHereLine()` ->
      `isUnparsedPresenceLine()` -> (lowercase-start wrapped-continuation
      check) -> `endLook()`. A line like `"This studded mace looks
      particularly dangerous."` matches none of the first three (all
      require "A"/"An"/"The" or a lies/lying/left/floats keyword) and
      isn't lowercase either, so it hit `endLook()` and would have
      silently dropped everything listed after it in that room —
      confirmed via a structural test harness this would have included a
      war mage and 3 novice mages at the end of the same listing. Fixed
      the same way the last three rounds were: broadened
      `isUnparsedPresenceLine()` to also treat lines starting with "This "
      as a skippable presence line (mirrors the existing "A"/"An"/"The"
      check exactly). Verified via a harness feeding all 43 real lines
      from the log through the actual trigger chain — capture stays
      active start to finish, and both the war mage and all 3 novice
      mages land in the final `rightHere` table. Syntax-checked. (Note,
      not fixed, pre-existing and out of scope: several item-flavor lines
      that DO reach `parseLookHereLine()`'s broad fallback end up tagged
      `is_mob=true` since `isMobName()` only checks for a leading
      article — a known, already-documented trade-off in this code, not
      something new.)
- [ ] **Murder/Consider/Order-All → "They're not here" — fixed 2026-07-16
      (item 6 of Steven's "6/7 we can look into" → "proceed"), needs live
      confirmation.** Real cause: identical mobs in a room collapse into
      ONE RightHere entry with a `count` field (`parseLookHereLine()`,
      `MyDSL_DataLayer.lua`), and nothing ever decremented/cleared it when
      a mob in it died mid-fight — not room-change staleness (confirmed
      `beginLook()` already clears `scan.rightHere` fresh on every room
      redisplay), mid-fight staleness instead, persisting as long as the
      player hasn't re-looked since a kill. Found the exact hook already
      built for this: `parseCombatDeathLine()` already raises a dedicated
      `"MyDSL.combat.died"` event with `{key, name}`, added 2026-07-11 so
      Focus could auto-advance/clear its target on death — but RightHere
      itself never listened for it. Added a listener in
      `MyDSL_ScanView.lua`'s `SV.init()`: decrements `count` if >1, else
      clears the entry entirely, then re-renders. Doesn't disambiguate
      WHICH of several identical mobs died (RightHere has no per-instance
      tracking, only a count) — decrements whichever entry's key matches,
      which is the best available fix without a bigger redesign of how
      RightHere stores duplicates. Syntax-checked via luajit.
- [ ] "multiple mob health echoes in combat... one we create and one from
      the game" — see the "Double condition-line echo" item in the
      Combat section above; fixed 2026-07-16, same discussion.
- [ ] **Affects window: top row not clickable to recast — fixed
      2026-07-16, needs live confirmation.** Reported by Steven ("top 2
      affect lines not clickable, 2nd line and below work"). Root cause:
      `A.applyLinks()`'s window-scan loop (`MyDSL_AffectsView.lua`) started
      at `index = 1`, a value ported verbatim from PNP's own
      `make_links()` (`PNP files/DSL_PNP_Affects.lua`) — but PNP's
      renderer prints a leading blank line + header row before any real
      content (so PNP's row 0 is blank, `index=1` harmlessly starts on
      the header). MyDSL's `A.display()` has no such header — `clearWin()`
      is immediately followed by the first real affect row, so row 0 IS
      content. Starting at 1 skipped it; with the default 2-column layout
      that's the first two affects. Fixed: `index = 0`. Syntax-checked.
- [ ] **Bloodbath chat never routed — fixed 2026-07-16, needs live
      confirmation.** `MyDSL_ChatTriggers.lua`'s pattern required
      "Bloodbath:" to start the line (`^\a?Bloodbath: '`); real format
      (confirmed via log corpus) is always `<Name> Bloodbath: 'message'`
      or `(Imm) <Name> Bloodbath: 'message'` — name always precedes the
      verb, same shape as every other channel in this file. Fixed to
      `^\a?(?:\(Imm\) )?[^']+ Bloodbath:[^']*'`, matching the established
      style. Syntax-checked. Superseded 2026-07-17 by a project-wide fix
      to this same file (see the chat item above) -- every `[^']+` zone
      (including this one) now uses a name-character class that also
      tolerates an apostrophe mid-name, so a Bloodbath message from a
      character with an apostrophe in their name routes correctly too.
- [ ] **`setspell` bare-command gives no usage feedback — fixed
      2026-07-16, needs live confirmation.** Confirmed Steven's exact
      case (2026-07-16): bare `setspell`, no args. Added
      `CA._aliases.setSpellUsage` (`^setspell$`) calling
      `setSpellInfo()` with no args, which already has a real usage
      message (`ce("usage: setspell <bless|fireproof> <spell|wand|
      skill> [name]")`) for malformed input — just wasn't reachable for
      the zero-arg case before. Syntax-checked.
- [ ] **New, from MyDSL notes 2026-08-23: LocationView — manually assigning
      a room picture doesn't display.** Steven: "mydsl location set 'A
      Sloped Hall.png' ... it looks like it set it, but it is not
      displaying in locations window, couple examples in the logs." Not
      yet investigated — the referenced logs are in the live MyDSL profile,
      not yet cross-checked against `MyDSL_LocationView.lua`.
- [ ] **New, from MyDSL notes 2026-08-23: ItemLore may be capturing OTHER
      players' identify announcements and overwriting a shared item's
      record with their enchanted-variant stats.** Steven: "if someone
      posts an identified item, the item reference captures that for its
      info, but its enchanted and not the normal stats, need a way to
      seperate or just not replace the info unless self identified." A
      different angle from the 2026-07-19 stale-field fix (`IL.merge()`) —
      that fix was about a real self-identify not clearing old scraped
      data; this is about a THIRD PARTY's identify possibly being captured
      at all. Needs the capture trigger's source-scoping checked.
- [ ] **Re-check: identify persistence — Steven's 2026-08-23 note still
      describes the exact symptom the 2026-07-19 fix targeted** ("casting
      identify on an item doesnt persist, need to save the new info and
      source information when identified") — unclear whether this note
      predates that fix or is a fresh recurrence/gap the fix didn't fully
      close. Needs a fresh live identify + check before assuming either way.
- [ ] **Re-check: TargetView/Focus not populating in combat — Steven's
      2026-08-23 note repeats this exact symptom**, which is also
      `docs/TODO.md`'s still-open Leveling item 10 (fixed 2026-07-25, not
      yet live-confirmed). Unclear if this note predates that fix. Same
      live-confirmation gap, not a separate bug until proven otherwise.
- [ ] **New, from MyDSL notes 2026-08-23: fresh-install window docking
      reconfirmed as a live pain point** — "need a way to not have all the
      windows dock on the right side after a new install, maybe start with
      a default settings file." Same issue already tracked in PACKAGING
      (shared `windowLayoutGeometry.dat`/`windowLayout.dat` theory, not
      fixed) — this independent report raises its priority, not a new bug.
- [ ] **New, from MyDSL notes 2026-08-23: mapper terrain/room coloring
      re-applies on every room entry instead of once** — Steven: "mapper
      terrain should be set once, not everytime i walk in the room... or
      can we color the room box borders instead... how do we color the
      border, or is that already available." Needs checking against the
      real 2026-07-18 behavior (`map.dsl.applySectorColor()`) — may be
      working as designed (recomputing is cheap/idempotent) and this is
      really a border-color feature request, not a bug; needs clarifying
      what specifically Steven is observing before treating as either.
---

## OPEN — Design ideas, not yet scoped
- [ ] **TargetView: show debuffs cast on the current target.** weaken/slow
      confirmed and ready to build; blindness/poison/plague have zero
      confirmed on-target success text yet — needs a live catch of an
      actual successful cast.
- [ ] **TargetView: auto-populate target on aura detection** — when
      detect-good/detect-evil shows, auto-set to first opposing-alignment
      mob visible, else first mob not in your own group.
- [ ] **Skills/Spells → Combat window** — echo real skill/spell actions,
      reduce raw per-swing spam. Warrior/thief skills still have zero
      confirmed first-person text anywhere in the corpus.
- [ ] **Command vocabulary — more IC/human-speak, less `mydsl <module>
      <verb>`.** Design direction, not scoped.
- [ ] Census (from UI) interacting with the reference module — Layer 4
      (ItemLore/ItemReference) now exists (2026-07-16), so this is
      unblocked whenever picked up; not yet scoped otherwise.
- [ ] **DSL event/date reminder module** — Steven: "a DSL reminder that
      allows you to enter events and dates and have it come up as a
      reminder when logged in or playing that such and such event will
      start soon... I believe there are also events in the calendar or
      holidays of the DSL wiki. Some way to connect this to Discord would
      be optimal! There is a Mudlet calendar for Achaea on GitHub that
      might help." Not scoped — needs: what counts as an "event" (manually
      entered vs. scraped from the DSL wiki calendar/holidays), whether
      Discord integration is in scope for this pass or a separate ask
      (would be the first outbound-network integration in this project —
      worth a design discussion given the passive-observation-only
      philosophy has so far meant zero outbound calls), and whether the
      referenced Achaea Mudlet calendar package is worth checking for a
      reusable pattern before building fresh.
- [ ] State-scoped sound toggle — generic pattern for an alias to turn a
      sound on for a state and reliably turn it off when the state ends.
- [ ] **A whole quest-tracking mechanic (quest start/expire/timer
      messages) has zero coverage anywhere in DSL2** — matches the
      already-tracked "Data-driven notes/quest tracking" DEFERRED item
      below, not a new ask, confirms real message text exists to build
      against whenever that's picked up. (The other 3 gaps flagged
      alongside this one on 2026-07-15 are resolved as of 2026-07-16:
      Consider now wires up all 6 real difficulty tiers, not 2 —
      `MyDSL_TargetView.lua`; `detect magic`/`heart blight` were already
      fixed in `docs/CapturedPatterns_Reference.txt`, just not flagged
      done; CreatureLore's `lore <name>` gap turned out to be based on a
      misunderstanding — checked `DSL_Helpfiles/lore.txt` and
      `creaturelore.txt` directly: `lore` is a general item-only skill
      that auto-fires on look/examine, has nothing to do with creatures;
      `creaturelore <target>` is DSL's one real creature-info command,
      and DSL2 already captures it correctly.)
- [ ] **New ideas from MyDSL notes, 2026-08-23 — raw, unscoped, none
      started.** Per this project's own rule, nothing here is built
      without picking it up explicitly first:
      - Alterform: warning + sound before it falls off (countdown from the
        last 5 ticks, warning at 10 ticks left).
      - Mapper: toggleable button bar for map-editing commands (shift,
        area add, rename, etc).
      - Mapper: alternate/angled exit lines (Z-shaped, not just straight)
        — "discuss this."
      - Mapper: labels reportedly don't move anymore since a Mudlet
        version change — needs comparing current behavior against the
        original/older Generic Mapper behavior. Bigger research item, per
        Steven's own "big research discussion for this."
      - Mapper: highlight other players' rooms (from the `where` command)
        on the map, colored by kingdom/org if possible; multiple
        possibilities highlighted when room names are ambiguous.
      - Leveling: an "order all kill" option instead of direct attack, for
        classes where that's the right opener.
      - DslColor/Census: track a player's kingdom/clan membership changes
        over time, not just current state.
      - DslColor: "last seen" should reflect real in-game physical
        location, not just presence on the `who` list.
      - DslColor: emerald dragon color palette; audit that titles/
        palettes/terms are all consistently colored; check Thax/Thaxanos
        kingdom coloring specifically against real logs.
      - AffectsView: recast/spellup that can use a potion or skill, not
        just the spell itself — "think this is in PNP if we havent
        implemented it," check PNP source first per this project's reuse
        rule.
      - TargetView: auto-populate from a room's `scan` output, not only
        once combat starts, to cut down on manual clicking.
      - Player-profile fields: alignment, god, notes, hp, mana, etc. —
        explicitly "brainstorm this," not scoped.
      - Roller: pull more comparison stats (racial/class baselines) from
        Shattered/the local knowledge base; investigate whether a
        reconnect-without-full-reload is possible to survive the server's
        roll time limit — "this will require planning."
      - UI: toggleable window titles / minimal borders, to maximize
        window space.
      - Restrings: an in-character-flavored guide/workflow for writing
        them — references Steven's own Obsidian notes (Piknim, the
        Gnomish Blunderbuss), outside this repo.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **Shatteredarchive.com maps** — Steven's original bestiary-import
      request also mentioned "there are items on the website and maps as
      well." The bestiary half is done and confirmed. Explicitly deferred
      by Steven 2026-07-15. Needs its own scoping pass when picked back
      up (what format, whether it's per-area images like
      `MyDSL_LocationView.lua`'s room pictures or something else).
- [ ] **Cross-profile master function/feature inventory** — walk every
      `.lua` file across every Mudlet profile on this machine, build one
      consolidated list. Large, multi-session scope, its own future
      session.
- [ ] **Layer 4: Reference library** — items done (`MyDSL_ItemLore.lua`/
      `MyDSL_ItemReference.lua`, confirmed live 2026-07-18) and mobs/lore
      done (`MyDSL_CreatureLore.lua`/Bestiary, confirmed earlier). Whatever
      remains under this heading (areas/zones/general lore, if that was
      ever the intent) not scoped — check
      `~/Downloads/Shattered-Archive-release-dev.zip` before building
      from scratch if picked up.
- [ ] **Inventory hover scope expansion (hover on carried-not-worn items)
      + ground-vs-inventory name mapping** — explicitly deferred by
      Steven 2026-07-18 ("not sure we need"), not a live bug. Equipment
      hover already works; this was extending it to plain inventory
      items. The name-mapping half was already answered empirically
      2026-07-16 (real corpus check found ~2/3 of items have a clean
      substring match between their ground and inventory text, but a
      real fraction don't — `"a bag of holding"` -> `"A strange bag lays
      here..."` — so any mapping would need to be best-effort with a
      manual-override path, not assumed complete). Revisit only if Steven
      asks again.
- [ ] **Data-driven notes/quest tracking** — streamline `notes_utf8.txt`'s
      in-game feature/quest items via data files instead of manual notes.
- [ ] **Consolidate all native Mudlet objects into one package** — per
      Steven: "this is why i want to pull all mudlet objects into one
      package so we can troubleshoot cleaner." Currently scattered across
      `gui-drop`/`mpkg`/`DslColors_v1_0.../`/`generic_mapper`/`EMCOChat`/
      `MyDSL_Full` plus loose top-level items. Large, structural,
      GUI-driven undertaking, its own future session.

---

## Native Mudlet objects with no MyDSL equivalent yet
Scale (confirmed against `current/autosave.xml`, 28,606 lines): 142
TriggerGroups, 613 Triggers, 43 Scripts, 66 Keys, 25 top-level Aliases, 0
Timers. Real candidates for future integration, none urgent:
- **Random Affects** (11 stat-fluctuation flavor messages), **Spells**
  category notifications, **Weather Conditions** (more granular than our
  keyword regex), **Atmosphere**/AGL/Sailing sub-groups — cosmetic/niche,
  low value.
- **66 native Keys** (movement/scan/look bindings) — raw keybindings, not
  something MyDSL needs to mirror.
- **~20 misc aliases** (`(inv)`, attire-swap sets, etc.) — fine as native
  aliases unless one becomes relevant to a window. `(autowhere)` moved out
  of this list 2026-07-16 — replaced by `MyDSL_AutoWhere.lua`, see NEEDS
  LIVE CONFIRMATION.

---

## DECISIONS RECORDED
- **Adopted a project-local known-bad-pattern checker + Claude Code hook
  — 2026-07-21, per Steven ("we seem to be regressing to errors we
  fixed... would it improve if we used a newer ai agent?").** Researched
  first rather than guessing: a newer model wouldn't meaningfully help
  (the gap is that fixing a bug in one file never propagated a check to
  every other file with the same latent mistake — not a capability
  problem), and `luacheck` (the standard Lua linter) turns out to be the
  wrong tool for this specific failure mode (it parses Lua syntax, not
  the *contents* of strings, and the triggering bug — `</cyan>` instead
  of `<reset>` — lives entirely inside a cecho string). What actually
  fits: `scripts/check_known_patterns.py`, a small script encoding real
  historical bugs from `docs/CHANGELOG.md` as grep rules, wired into a
  `PostToolUse` hook (`.claude/settings.json`) that runs automatically
  against every file `Edit`/`Write` touches — catches a fresh instance of
  a known mistake the same session, no prompting required. `.gitignore`
  updated with a narrow exception (`!.claude/settings.json`) so the hook
  itself survives across sessions/machines instead of living only
  locally — `.claude/settings.local.json` and everything else under
  `.claude/` stays ignored as before. Run `python3 scripts/
  check_known_patterns.py --all` periodically for a full-repo sweep
  (catches mistakes already latent in untouched files — a hook only ever
  checks the one file just edited). When a new bug class is fixed and
  might exist elsewhere too, add a rule instead of a one-off grep so the
  check becomes permanent. Full detail: `docs/CHANGELOG.md` (2026-07-21).
- **"Passive observation only, never send automatic game commands" is
  suspended for leveling/questing automation addons — confirmed
  2026-07-19, per Steven ("the no automation is suspended for thes
  modules, they will be outside addons for the ui, for the specific
  task of automating these features").** Scope of the exception is
  narrow and explicit, not a blanket policy change: it applies only to
  a leveling-assist module (auto-navigate known hunting grounds,
  auto-engage mobs) and a questing-assist module (auto-run `pquest`
  flow), both sourced from real community Mudlet scripts found on the
  DSL forums (forum ID 111, "Mudlet Scripts") via the
  `~/Documents/DSL/dsl-knowledge-base` project. These ship as **separate
  outside addons**, not part of the core MyDSL passive-observation UI
  stack — the rest of DSL2 (Location, Combat, TargetView, etc.) keeps
  the original passive-only rule unchanged; this exception doesn't
  generalize to any other module without a similarly explicit ask. See
  `docs/CHANGELOG.md` (2026-07-19) for the source-validation work and
  whatever gets built from it.
- **Mapper: `start mapping` stays a manual gate, not auto-persisted —
  confirmed 2026-07-18, per Steven.** Root cause of "new mapper doesn't
  recognize existing rooms" / "position stuck on the previous room" is
  fully understood: `map.mapping` is one of Generic Mapper's own
  in-memory-only "protected" fields, so it always resets to `nil` on a
  script reload — every reinstall silently turns mapping off until
  `start mapping` is run again. An auto-persist/auto-restore fix was
  built, then reverted same day: the manual gate is intentional
  (deliberate control over when new rooms get created), not a bug.
  Steven manually re-running `start mapping` after every reinstall is
  expected, not tracked as an open item. Full trace: `docs/CHANGELOG.md`
  (2026-07-18).
- **CreatureLore's `lore <name>` "gap" — confirmed a non-issue,
  2026-07-16.** The 2026-07-15 note worried DSL2 might only parse
  `look`/`scan` mob text, not a `lore <name>` command's own per-field
  creature output. Checked `DSL_Helpfiles/lore.txt` and
  `creaturelore.txt` directly: `lore` is a general item-only skill
  (works automatically on look/examine, nothing to do with creatures at
  all); `creaturelore <target>` is DSL's one real creature-info command,
  and `beginCreatureLore()`/`loreStart` (`MyDSL_DataLayer.lua`) already
  captures it correctly. The "sibling profile's CreatureDB parses lore
  output directly" claim that prompted this couldn't be independently
  verified against the actual sibling profile files on this machine.
- **LiveView's "age" field — confirmed correct as-is, 2026-07-16.**
  Steven: "if the age in live is how many ingame months/years have past
  since creation, that is a good." No relabel/replace needed — the
  displayed figure (elapsed real-world time since character creation,
  converted via `ageText()`'s empirical ratio) is exactly what he wants
  shown there, distinct from DSL's own separate roleplay age stat
  (`practice age`/score's `YEARS:` line), which stays uncaptured/
  undisplayed by design.
- **Itemstat trigger retirement — sequencing confirmed 2026-07-16, per
  Steven: "itemstat will retire when we have made the item identification
  db and module."** Not proactively tracked as a live risk in the
  meantime ("close, we will deal with it if it arises" — 2026-07-16) —
  itemstat decorates `eq`/`in` output client-side and hasn't been proven
  to actually break any combat trigger. Retires naturally once Layer 4
  (the item reference library) replaces the equipment parser's current
  dependency on itemstat for stat data — no separate decision needed
  before then.
- **"Prompt Line 1" parsing — dropped, confirmed 2026-07-16.** Per
  Steven ("prompts are gaged even with quiet now") the scenario this was
  meant to cover (needing to parse flags out of a leaking, un-gagged
  prompt line) doesn't occur — prompt gagging already works correctly
  with quiet mode active. Not pursuing this.
- **Staying on Mudlet 4.20.1, not 4.21/4.22** — confirmed 2026-07-12 real
  upstream bug: `TMainConsole::getUserWindowSize()` (added by PR #9334)
  rejects a docked `UserWindow`'s real size as "suspicious shrinkage"
  once it's shrunk enough from a previously-cached larger size, and
  returns the stale larger size instead — every percentage-positioned
  child (Tick's bars, Focus's button grid) then gets placed against
  that wrong number. Confirmed this survives a full Mudlet restart
  (Mudlet's own `windowLayout.dat`/`windowLayoutGeometry.dat`, outside
  any profile folder, re-poison it on every launch) and that resetting
  those files doesn't cleanly fix it (made the whole panel layout
  collapse instead). Reverting to 4.20.1 fixed everything immediately.
  **Don't re-investigate Tick/Focus/other-docked-window sizing bugs as
  a MyDSL problem without first checking the installed Mudlet version**
  — if a future upgrade is considered, check whether this shrinkage
  guard has been revised upstream first.
- Most settings (theme, visibility, chat, fonts, TargetView/AffectsView)
  are character-bound. **Window layout is the one deliberate exception**:
  layout is per-profile (single shared `MyDSL_layout.lua` + native Qt
  `saveWindowLayout()`), not per-character — after repeated fights with a
  custom per-character percentage-save system, simplicity won out.
- Themes: user-creatable named presets, shared across all characters
  (intentionally not character-bound).
- Creaturelore DB (`MyDSL_CreatureLore.lua`): shared across characters,
  not character-bound — objective game data, same reasoning as themes.
- `MyDSL_Mapper` removed from WindowRegistry — minimap via
  `map.configs.map_window` only, not a Geyser.UserWindow.
- CharPic compatibility code removed from PortraitView (no DSL1 triggers
  call any `CharPic.*` function).
- RouteHelper `routeMap` removed — shorthand helpers (`Route.history()`
  etc.) are the only API.
- Prompt: toggleable pretty prompt, default ON.
- Day/Night derived from `time` command, not prompt capture.
- Alignment from score only, persists until next score run, no auto-send.
- **Window docking/positioning:** every `Geyser.UserWindow` gets
  `restoreLayout=true` + `autoDock=true` via a single global constructor
  patch (`patchUserWindowConstructor()` in `MyDSL_WindowRegistry.lua`).
  Startup order: `patchUserWindowConstructor()` → `Windows.loadState()` →
  `Windows.ensureAll()` → `loadWindowLayout()`, called exactly once, no
  timers. To persist a layout: `mydsl layout save`; to reset: `mydsl
  layout reset` (doesn't auto-persist).
- `DSL_PNP_Highlighter.lua`/`.custom.lua`, `DSL_PNP_People.lua`,
  `DSL_PNP_Statusbar.*`, and ~20 PNP-client-infrastructure files are
  explicitly out of scope — superseded by the live `DslColors_Core_v1_0`
  native script, GMCP-first PromptView, or Geyser/WindowRegistry/
  LayoutEngine/ThemeEngine already.
- `colors.xml` (profile root) is a stale, unloaded pre-v1.0 DslColors
  snapshot — confirmed safe to leave alone, not worth reviving.

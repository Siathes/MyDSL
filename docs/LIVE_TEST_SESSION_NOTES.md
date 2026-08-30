# Live test session notes — MyDSL Test profile, 2026-08-29

Running scratch notes from live-testing `DSL_Mapper_Addon`/`MyDSL_Full` in
a fresh Mudlet 5.0 profile. Deliberately not fixed one at a time — small
UI/UX polish items pile up fast during a real play session and each is a
context-switch; batched here for one larger pass afterward instead.
**Once triaged into real fixes, prune this file** (same discipline as
`docs/TODO.md`) — this is a working scratchpad, not a permanent record.

Steven's own plan (from `notes.json` in the test profile): make these
fixes, then delete the profile and do a fresh install to see how it feels
after the changes, rinse and repeat until it feels right. Combat testing
saved for last.

---

## Fixed this pass (from the 2026-08-29 22:29 gameplay notes)

- **"Players Near" / "Right Here" windows duplicated their own title as
  content.** Both windows already show their name in the title bar, but
  also wrote a redundant header line into the content itself ("Players
  near you:" / "Right Here:"). Fixed: `MyDSL.beginPlayersNear()`
  (`MyDSL_DataLayer_ScanLook.lua`) now gags the header line instead of
  routing it; `SV.renderRightHere()` (`MyDSL_ScanView.lua`) no longer
  writes the "Right Here:" text. `test/test_datalayer_playersnear_parse.lua`
  still passes clean.
- **`affects command <name> <cmd>` gave no feedback when the affect
  wasn't tracked.** Root cause of Steven's own uncertainty ("not
  intuitive, don't think I did it correctly") — `mydsl affects command`
  (sets recast command) and `mydsl affects track` (adds to the
  tracked/displayed list) are two independent settings; he'd set a
  command for "sneak" but never tracked it, so it silently didn't show
  up anywhere. `A.setCommand()` (`MyDSL_AffectsView.lua`) now prints a
  hint pointing at `mydsl affects track <name>` when this happens.
  Separately: "sneak" is already in `A.skills` (line 120), so
  `commandFor()` already resolves it to the bare `sneak` command
  automatically — his manual `customCommands["sneak"]="sneak"` entry in
  the live profile is redundant but harmless, no action needed there.

## Confirmed clean / working (no action needed)

- DslColors noticeably faster.
- Mapper working end-to-end: DSL2's old map imported successfully,
  room labels rendering again.
- Both packages still install/load without errors — `errors.txt` has no
  actual error lines (only routine map-load audit reports).
- "Login autofill: not configured" message is **expected, not a bug** —
  `MyDSL_login_credentials.lua` lives per-profile
  (`getMudletHomeDir()`-relative), so a fresh "MyDSL Test" profile has no
  credentials file of its own even though DSL2's does. Only relevant if
  Steven wants autofill in this specific test profile too — he'd need to
  create that file there (see `MyDSL_Login.lua`'s header for the exact
  format).
- One native `(mapper): (error): Room not found in map database` line
  after `map me`, right before the room actually resolves — this is
  Mudlet's own stock mapper output (not MyDSL's), looked transient
  (immediately followed by a correct `look`). Not actioned; flag only if
  it recurs persistently or blocks mapping.

## Round 2 (Steven's answers) — resolved

1. **"Visual settings/window locations/text size need to be defaults."**
   Window layout/position: turned out to already be solved a different
   way than assumed — `saveWindowLayout()`/`loadWindowLayout()` (the
   existing `mydsl layout save`) persist to `windowLayout.dat`/
   `windowLayoutGeometry.dat` in the shared Mudlet config directory
   beside `profiles/`, NOT per-profile as this project's docs previously
   assumed (corrected in `MyDSL_LayoutEngine.lua`/`MyDSL_WindowRegistry.lua`/
   `docs/MyDSL_MudletWindowManagement.md`/`docs/TODO.md`). Since dock
   widget names are profile-name-scoped, a delete+reinstall of "MyDSL
   Test" under that same name already inherits the saved layout — nothing
   to build, just confirm it in the next test. Settings: checked every
   saved-settings file against its module's code defaults —
   Affects `timerMode` (cycles→both) and Live `infoFont` (13→9) were the
   only two real mismatches, both fixed; Tick/Alterform/Live's other
   fonts already matched. `DEFAULT_TRACKED` (the Affects module's
   starter spell list) deliberately NOT overwritten with Kien's live
   subset — it's already a broad, class-spanning list and the project's
   own "never hardcode a character/class" rule means one character's
   current loadout shouldn't narrow the universal default.
2. **Layout-save-on-move.** Confirmed: no native per-move hook exists, so
   this stays manual — but `mydsl layout save` already existed and is
   already documented (`MyDSL_Help.lua`), so there's nothing new to
   build here either. Just a reminder: run it after rearranging.
3. **DslColors: bake manually-added items into defaults (e.g.
   "professor").** Found it — `DSL_COLOR_DB.titles["Professor"] =
   "title_scholarly"` was a real, per-profile learned entry (confirmed
   real via a live "who" sighting on Xenoyr). Promoted into
   `DSL_TITLE_ALIASES` (the built-in vocabulary) in the git-tracked
   `DslColors_Core_v1_0.xml`, tested clean. **Not fully shipped yet**:
   the actual native Script content that gets packaged comes from the
   live "MyDSL" profile's own Script editor copy, not this git file —
   Mudlet was running against a profile when this was found, so editing
   its loaded XML on disk directly was skipped as too risky. Needs the
   same one-line addition made through Mudlet's own Script editor in the
   "MyDSL" profile (Scripts → DslColors_Core_v1_0 → add
   `["Professor"] = "scholarly", ["professor"] = "scholarly",` to
   `DSL_TITLE_ALIASES`) before a rebuilt package actually carries it.

## Still open

- **DslColors' bigger Census/titles/palette work** (emerald dragon
  palette, Thax/Thaxanos consistency audit, alignment/god/hp fields) —
  unrelated to the "professor" promotion above, already tracked as its
  own large item under `docs/TODO.md` TOP PRIORITY, not touched here.
- **Sound/RoomPic first-time-load prompt / `mydsl assets fetch`.**
  Design fully researched (`docs/TODO.md`), the alias code itself is
  buildable now, but the actual GitHub Release (zipping
  Sounds/RoomPics/Portraits and uploading them as release assets) is a
  real, visible, hard-to-reverse action only Steven can authorize/do the
  account side of — asked him directly rather than building against a
  guessed URL.

## Open items carried over, not yet actioned

- [ ] **Clean up module-load console messages** (Login autofill status,
      WindowRegistry font sizes, TargetView loadConfig, CreatureLore DB,
      Movement sounds, ItemLore DB, DslColors loaded). Real and accurate,
      just noisy for a first-time player. Scope: which should go
      silent-by-default (only shown via `status`/`debug`) vs. worth a
      one-time confirmation on fresh install.

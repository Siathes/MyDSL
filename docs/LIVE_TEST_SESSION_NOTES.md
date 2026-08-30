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

## Needs Steven's decision, not fixed blind

- **"Current layout should be default install layout" / "all current
  settings need to become defaults."** Doable, but changes what a fresh
  install looks like for every future profile/character, so it's a real
  decision, not a mechanical fix. Two separate questions to settle:
  1. Layout: capture the current arranged window positions/sizes as the
     new packaged defaults, replacing `MyDSL_LayoutEngine.lua`'s
     `MyDSL.Layout.defaults` table — straightforward once you confirm the
     current MyDSL Test arrangement is the one to freeze.
  2. Settings: which specific saved-settings files count as "current
     settings" to bake in as defaults (theme? font sizes? tracked
     affects list? window visibility?) — needs a concrete list since
     "all" spans several independent files.
- **Layout doesn't save on window move.** Confirmed why: Mudlet's own
  dockable-window layout persistence (`saveWindowLayout()`/
  `saveProfile()`) has no per-move callback exposed to Lua — there's no
  native "window moved" event to hook, so an automatic save-on-move isn't
  actually the "simple fix" it might look like. A periodic autosave
  timer (e.g. call `saveWindowLayout()` every few minutes while
  connected) is a real, simple alternative if losing an occasional
  rearrangement on crash/close is the actual concern — flagging as an
  option rather than building it, since it's a behavior change (extra
  disk writes, autosave timing) worth your sign-off first.
- **"Update all manually added titles and other items to DSL from this
  and DSL2 files."** Not clear yet what specific data this refers to
  (room titles? character-specific overrides? something in DSL2's own
  profile vs. this MyDSL Test one?) — need a concrete pointer to what to
  sync before this can be scoped.
- **Sound/RoomPic first-time-load prompt.** Already tracked in
  `docs/TODO.md` (asset-distribution plan, opt-in `mydsl assets fetch` —
  researched, not yet built). Steven's note here ("maybe should be first
  time load option") is consistent with the existing plan (opt-in, not
  default-on) — no new decision needed, just still open work.

## Open items carried over, not yet actioned

- [ ] **Clean up module-load console messages** (Login autofill status,
      WindowRegistry font sizes, TargetView loadConfig, CreatureLore DB,
      Movement sounds, ItemLore DB, DslColors loaded). Real and accurate,
      just noisy for a first-time player. Scope: which should go
      silent-by-default (only shown via `status`/`debug`) vs. worth a
      one-time confirmation on fresh install.

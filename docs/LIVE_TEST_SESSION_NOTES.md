# Live test session notes — MyDSL Test profile, 2026-08-29

Running scratch notes from live-testing `DSL_Mapper_Addon`/`MyDSL_Full` in
a fresh Mudlet 5.0 profile. Deliberately not fixed one at a time — small
UI/UX polish items pile up fast during a real play session and each is a
context-switch; batched here for one larger pass afterward instead.
**Once triaged into real fixes, prune this file** (same discipline as
`docs/TODO.md`) — this is a working scratchpad, not a permanent record.

---

## Open items, not yet actioned

- [ ] **Clean up module-load console messages.** First install showed a
      stack of `[MyDSL] ...` boot-status lines in the main console
      (Login autofill not configured, WindowRegistry font sizes loaded,
      TargetView loadConfig no saved file yet, CreatureLore DB loaded,
      Movement sounds loaded, ItemLore DB loaded, DslColors loaded).
      Real and accurate, just noisy for a first-time player. Scope this
      pass: which of these should be silent-by-default (only shown via
      an explicit `status`/`debug` command) vs. genuinely worth a
      one-time confirmation on fresh install.
- [ ] **`MyDSL_MapperMenu.lua` proper distribution path.** Test-profile
      shortcut in place (a local `dofile()` Script pointing at the DSL2
      repo path, same-machine only). Real fix: add a native dofile
      Script for it in DSL2's own profile so
      `build_mydsl_package.py`'s dofile-list discovery picks it up, then
      rebuild `MyDSL_Full.mpackage` for real. Not done yet.

## Confirmed clean (no action needed)

- Both packages installed without errors — `errors.txt` empty, log shows
  clean module init for both `DSL_Mapper_Addon` and `MyDSL_Full`.
- `[DSL Mapper Addon] Installed.` welcome message fired correctly on
  real install — first live-Mudlet confirmation of the
  `sysInstallPackage` hook working (previously only tested in `luajit`
  mocks).
- Initial window layout renders correctly, all panels showing expected
  empty/placeholder state for a character with no game data yet.

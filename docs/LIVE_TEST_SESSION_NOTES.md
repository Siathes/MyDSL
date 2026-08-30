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
## Confirmed clean (no action needed)

- **`MyDSL_MapperMenu.lua`'s distribution path — resolved differently
  than first planned.** Steven's call: stop requiring a native dofile
  Script anywhere before a module gets bundled at all.
  `build_mydsl_package.py` now auto-bundles every git-tracked
  `MyDSL_*.lua` file not yet in the discovered dofile list. Real
  package rebuilt with it included — the test-profile local-`dofile()`
  shortcut from earlier can be removed once you reinstall the new
  `MyDSL_Full.mpackage`.
- **Bonus find from the same change: `MyDSL_Leveling.lua` (real,
  1,026-line, actively-maintained automation module) had never been in
  any built package either**, same root cause. Now bundled too — worth
  actually testing the Leveling automation for the first time in an
  installed package, not just from the dev profile.
- Caught and fixed before it shipped: the same discovery change first
  auto-picked-up `MyDSL_theme_settings.lua`/`MyDSL_windowfonts.lua`
  (Steven's personal saved settings, not real modules) — excluded, and
  a real `.gitignore` gap that let them get git-tracked in the first
  place is now fixed too.

- Both packages installed without errors — `errors.txt` empty, log shows
  clean module init for both `DSL_Mapper_Addon` and `MyDSL_Full`.
- `[DSL Mapper Addon] Installed.` welcome message fired correctly on
  real install — first live-Mudlet confirmation of the
  `sysInstallPackage` hook working (previously only tested in `luajit`
  mocks).
- Initial window layout renders correctly, all panels showing expected
  empty/placeholder state for a character with no game data yet.

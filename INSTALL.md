# Installing MyDSL_Full

This covers the full MyDSL suite (`MyDSL_Full.mpackage`) — combat/group/
target/chat windows, the mapper, item/creature reference, character
assist, theming, and more. If you only want the standalone mapper, see
the main [README](README.md) instead; it's a separate, lighter package.

**Status: early testing build.** Works and is actively played on, but this
is the first release anyone other than the developer has installed from
scratch — see `docs/TODO.md`'s "`MyDSL_Full.mpackage` — real
from-scratch install test" entry for what's confirmed vs. still
unverified. [Open an issue](https://github.com/Siathes/MyDSL/issues) if
something doesn't work as documented here.

**[Download MyDSL Full v1.0.0 (Testing) →](https://github.com/Siathes/MyDSL/releases/tag/mydsl-full-v1.0.0-testing)**

## Requirements

- Mudlet 4.20 or newer (tested on 4.20.1 and 5.0.0)
- Mudlet's own built-in **Generic Mapper** already active in your
  profile — open the Map widget once (`Ctrl+M` or the compass icon in
  the toolbar) if you've never used it in this profile before. MyDSL's
  mapper layer builds on top of Mudlet's own, it doesn't replace it.
- A Dark and Shattered Lands character

## Install

1. **If you have an older copy installed, uninstall it first**:
   Toolbar → Packages → MyDSL → Uninstall. Installing over an existing
   copy without uninstalling can silently nest content inside itself —
   do this every time, not just when something looks wrong.
2. Download `MyDSL_Full.mpackage`.
3. **Toolbar → Packages → Install Package** → select the file you
   downloaded.
4. If Mudlet warns the Generic Mapper isn't loaded yet, open the Map
   widget once, then reinstall.

## What's in the box vs. what's opt-in

Everything text/window/tracking-related installs and runs immediately —
nothing needs a separate step to start working.

Two things are deliberately **not** bundled and need an explicit command
after install:

- **Sounds and room pictures** — real files, large (Sounds ~10MB,
  room pictures ~350MB), fetched from this repo's GitHub Release assets
  on request, never automatically:
  ```
  mydsl assets fetch sounds
  mydsl assets fetch roompics
  mydsl assets fetch all
  mydsl assets status
  ```
- **Autologin** — currently held out of the package entirely (a real
  bug in its password-capture flow was found and fixed in source, but
  it's not shipping until it's had more live testing). If you want it,
  ask — the module still exists in the git repo.

## Known unverified areas (this is what a from-scratch test is for)

- Whether anything in this package actually requires DSL's PNP client
  package to be separately installed first, or whether everything
  needed from it was fully ported into MyDSL's own code. Untested
  end-to-end — if something doesn't work and PNP isn't installed,
  that's the first thing to check.
- Chat window self-containment on a totally fresh profile (no prior
  EMCO/chat state at all).
- The mapper starts with **no map data** on a fresh profile — this is
  expected and correct (a real new player wouldn't have one either);
  walk around to build it, same as vanilla Mudlet mapping.

## After installing

- `mydsl help` — full command list
- `theme list` / `theme next` / `theme prev` — cycle through visual
  themes; `theme reset` restores Mudlet's own native look
- Most windows are individually toggleable — `mydsl help` documents the
  show/hide command for each one

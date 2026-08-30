# MyDSL

A Mudlet addon suite for **Dark and Shattered Lands** (dsl-mud.org) — passive observation windows (combat, group, target, chat, prompt/vitals), a mapper layer, item/creature reference, and more, all built to sit alongside the game's own text without hiding or replacing it.

## Try the DSL Mapper Addon

The mapper is the piece most useful on its own, so it ships as a **standalone package** — no dependency on the rest of MyDSL, no bundled copy of Mudlet's own mapper, just an add-on layer on top of it.

**[Download the latest release →](https://github.com/Siathes/MyDSL/releases/latest)**

### Requirements
- Mudlet 4.20 or newer (tested on 4.20.1 and 5.0.0)
- Mudlet's own built-in **Generic Mapper** already active in your profile — open the Map widget once (`Ctrl+M` or the compass icon in the toolbar) if you've never used it in this profile before. This addon doesn't include or replace it.
- A Dark and Shattered Lands character

### Install
1. If you have an older copy installed, uninstall it first: **Toolbar → Packages → DSL Mapper Addon → Uninstall.** (Installing over an existing copy without uninstalling can nest content inside itself.)
2. Download `DSL_Mapper_Addon.mpackage` from the [latest release](https://github.com/Siathes/MyDSL/releases/latest).
3. **Toolbar → Packages → Install Package** → select the file you downloaded.
4. If it tells you Mudlet's own Generic Mapper isn't loaded yet, open the Map widget once, then reinstall.

### What it adds
- Door-state tracking (open/closed/locked) read straight from DSL's own room text
- Terrain/sector room coloring, from GMCP room data
- Room movement-cost ("weight") learned from real observed move-point spend, not guessed
- GMCP-assisted room name/exit resolution
- Highlights other players' rooms on the map from the `where` command
- A **Safe Delete** option on the map's right-click menu

Full details and known issues are in each release's own notes.

## Try the full MyDSL suite (testing build)

Combat/group/target/chat windows, a prompt/vitals overlay, item and creature reference lookups, character-assist helpers, theming, and more — built as a set of independent, toggleable modules rather than one monolithic thing.

**This is an early testing build, not a finished 1.0.** It works and is actively played on, but hasn't yet been installed from scratch by anyone other than its own developer. Expect rough edges — [open an issue](https://github.com/Siathes/MyDSL/issues) if you hit one.

**[Download the latest testing build →](https://github.com/Siathes/MyDSL/releases)** (look for the prerelease tagged `mydsl-full-*`)

See [INSTALL.md](INSTALL.md) for setup steps, including the optional sound/room-picture asset download.

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md) — free to use, copy, modify, and redistribute (including modified/derivative versions) for any noncommercial purpose, which explicitly covers personal/hobby use. Commercial use isn't permitted.

## Source / issues

Report bugs or ask questions via [Issues](https://github.com/Siathes/MyDSL/issues). Contributions/forks welcome.

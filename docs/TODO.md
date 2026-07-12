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

## LOW PRIORITY — script wiring
- [ ] ChatWrapper tab active/inactive CSS still hardcoded — no ThemeEngine
      hookup. Real design pass, not a mechanical fix.
- [ ] `MyDSL_creaturelore.lua` (lowercase, profile root) is stale DSL1
      carry-over data, not a module — superseded by
      `MyDSL/creaturelore_db.lua`. Tracked in git, unused. Confirm with
      Steven before deleting.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or emulation — none of this
is closed until Steven confirms it in-game. Full technical detail for any
item: `git log --oneline` + `docs/CHANGELOG.md`.

- [ ] **LiveView Pos'n now updates in real time, needs live confirmation.**
      Per Steven ("liveview pos'n doesnt update on changing without
      score, it should update with the gmcp... check sibling profiles
      and other liveview scripts, this was active once before"). Found
      the prior real implementation in
      `../Dark & Shattered Lands - PNP/PNP/DSL_PNP_Statusbar.posn.lua`:
      real-time text triggers on DSL's own first-person confirmation
      lines, not GMCP polling. Confirmed GMCP's `char_data` (full raw
      payload checked directly against a live dump) has **no**
      Standing/Sitting/Resting/Sleeping field at all — only
      `is_flying`/`is_riding`/`is_fighting`/`is_afk`/`is_quiet` booleans
      — so a GMCP-only approach can't represent those 3 states; Steven
      confirmed keeping the hybrid design after seeing this. Built:
      `MyDSL_DataLayer.lua` gets a new `setPosn()` + 12 text triggers
      (`MyDSL.State.char.posn`), rebuilt from real corpus-confirmed
      sentences rather than porting PNP's own pattern verbatim — PNP's
      unanchored `stand` match would have false-positived constantly here
      (confirmed several DSL2 room descriptions independently open with
      "You stand on/in the...", including after a plain `look`). Per
      Steven's explicit direction, `setPosn()` itself checks GMCP's
      `is_flying` as the authoritative cross-check before committing any
      trigger's text-implied value, so a stray match can never downgrade
      a character GMCP still confirms is flying.
      `MyDSL_DataBridge.lua`'s `MyDSL.DB.score.posn` now prefers
      `char.posn` over the stale `score.position` text field (GMCP-first,
      same fallback pattern already used for gold/silver/weight). `"You
      stop resting."` kept from PNP but not corpus-confirmed for DSL2
      specifically — low collision risk, flagged like the CharacterAssist
      disarm patterns.
- [ ] **Wimpy now updates in real time, needs live confirmation.** Per
      Steven ("wimpy should update when its changed as well and gmcp, or
      how it collects info. but also with the manual wimpy command").
      `MyDSL.DB.score.wimpy`'s GMCP-vs-text priority was already correct
      (`char.wimpy` wins, matching the same pattern just built for
      Pos'n) — the actual gap was that nothing fed `char.wimpy` in real
      time; it only refreshed whenever an unrelated `gmcp.char_data`
      packet happened to arrive. Added a text trigger on DSL's exact
      confirmation line (corpus-confirmed, fires for both a bare `wimpy`
      query and `wimpy <n>` to set it): `"Wimpy set to N hit points."` —
      `MyDSL_DataLayer.lua`. Captures the number directly from the line,
      no GMCP cross-check needed (unlike Pos'n, no ambiguous states here).
- [ ] **LiveView READY/FIGHTING badge — real bug fixed 2026-07-12, needs
      live confirmation.** Per Steven ("the ready flag does not update
      when fighting"). `L.data()` read `fighting`/`riding`/`flying` from
      `live` (`MyDSL.DB.live`), which only ever has
      hp/maxhp/mana/maxmana/move/maxmove/name/level — those 3 fields only
      exist on `score` (`MyDSL.DB.score`, correctly GMCP-sourced from
      `char.is_fighting`/`is_riding`/`is_flying`). `identityLine()`'s
      badge reads `d.fighting` directly, so it was permanently nil — the
      badge could never show FIGHTING regardless of actual combat state.
      Fixed by reading all 3 from `score` instead. `riding`/`flying`
      aren't consumed by any renderer currently (confirmed via grep) —
      fixed for correctness, not a second visible bug.
- [ ] **History adaptive word wrap — added 2026-07-12, needs live
      confirmation.** Per Steven ("history needs adaptive word wrap, so
      it text wraps with the size of the window"). Real Mudlet API,
      confirmed via its own bundled `GeyserMiniConsole.lua`:
      `enableAutoWrap()` computes wrap width from the console's current
      pixel width/font width, and `MiniConsole:reposition()` (called
      automatically on resize) already recalculates it — no extra resize
      wiring needed. Applied to History only (`MyDSL_RouteHelper.lua`),
      not the other routed windows.
- [ ] **Window edge padding — reverted 2026-07-12, needs Steven's call on
      the real tradeoff.** Both the right-inset and the corrected
      left-inset (`MyDSL_RouteHelper.lua`'s shared console, x/width
      shift) moved the whole console widget rather than adding true
      text margin — since the console paints its own solid background
      via `setColor()`, separate from the panel behind it, shifting its
      position exposed the panel's background as a visible seam that
      read as a second border moving, not padding. Steven confirmed
      that's not what he wanted. Checked for a clean fix: no,
      `Geyser.MiniConsole` doesn't support `setStyleSheet()`/CSS padding
      (same finding as `MyDSL_LiveView.lua`'s `resizeExitsCon()`), and
      Mudlet's own console API has no native inner-margin primitive.
      True "text inset, same continuous background" would mean
      prepending real space characters to every routed line in
      `Route.to()` instead — feasible in principle (single shared
      function) but untested for the move-current-line path (`copy()` +
      `appendBuffer()`, which pastes the whole line as one unit — unclear
      whether a separately-echoed leading space would land inline on the
      same line or force its own line without live testing). Reverted to
      full-bleed (`x=0, width=100%`) pending Steven's decision: drop this
      ask, or try the text-prepending approach with his live testing to
      verify it behaves.
- [ ] **Alterform timer repositioned — added 2026-07-12, needs live
      confirmation.** Per Steven ("move the timer to a more visible
      location like bottom above the cycle counter"). Confirmed the
      exact target layout via AskUserQuestion before building: shrunk
      the tube (52% → 38% tall) to make room for the countdown as its
      own distinct text row, clear of the tube graphic, sitting directly
      above the cycle-count row. `MyDSL_AlterformView.lua`'s fill-percent
      math updated to match the tube's new dimensions.
- [ ] **Location image filenames standardized — added 2026-07-12, needs
      live confirmation.** Per Steven ("id like to be able to match the
      room name and file without appending _ for spaces, then rename all
      the files to match"). `M.fileForRoom()`
      (`MyDSL_LocationView.lua`) now uses the literal room name (spaces,
      apostrophes, capitalization preserved), only stripping genuinely
      filesystem-illegal characters — was underscore-joined +
      alphanumeric-only. `candidatePathsForRoom()`'s lookup order flipped
      to match (new convention tried first, old underscore convention
      kept only as a fallback). Renamed all 248 files in
      `MyDSL/roompics/` down to 215: 117 straight underscore→space
      renames, 32 exact-duplicate pairs deduped (byte-identical content,
      kept the space-named one), and 3 pairs needed a real decision —
      Steven's rule ("if renaming with duplicates, take the latest file
      and overwrite") resolved all 3: 2 were identical-content
      case-only duplicates (`east_mystic_crystal_fields.png` /
      `East_Mystic_Crystal_Fields.png` and `extreme_cases.png` /
      `Extreme_Cases.png`), 1 (`The_wing_of_the_Stone_Dragon.png` /
      `The_Wing_of_the_Stone_Dragon.png`) was genuinely different
      content, ~6 days apart — kept the later (2026-07-03) capture per
      the rule. Image files themselves are gitignored (runtime data),
      only the code change is tracked.
- [ ] **LiveView in-game age display — added 2026-07-12, needs live
      confirmation.** Per Steven ("looks at score creation date and uses
      in-game time to tell you when your ingame birthday is and ingame
      age"), confirmed via AskUserQuestion to build the "in-game
      calendar math" version specifically (approximate is fine — day/
      month *names* aren't continuous across resets). DSL's real-time-to
      -game-time ratio isn't documented anywhere — empirically derived
      from the full `log/` archive: exactly 10 distinct month names ever
      appear across the whole corpus (10 months/year), day numbers run
      1–35 before rolling over (35 days/month), and ~35 real minutes = 1
      in-game day (trimmed mean of 64 clean single-day-step samples
      timestamped against real log mtimes). Parses `score`'s `Created:`
      line (both the current full-date format and an older bare-numeric
      form seen in some captures) in `MyDSL_DataLayer.lua`, bridges the
      timestamp through `MyDSL_DataBridge.lua`, computes the age fresh
      on every render in `MyDSL_LiveView.lua` (`ageText()`, same
      store-the-anchor pattern as `improveLiveText()`). Added to the
      identity row per Steven's placement choice — which also meant
      fixing a real space problem he flagged: the `Religion:` (god)
      field was capturing the full trailing title text
      (`"Cliath -=- the God of Creation -=-"`) instead of just the name,
      overflowing the row. Fixed to capture just the name (every real
      god name confirmed single-word, cross-checked against
      `DSL_Helpfiles`), freeing the space age now uses. Font size fixed
      same day (was the small badge size, now matches the rest of the
      row).
- [ ] **MoonWeather weather line — added 2026-07-12, needs live
      confirmation.** Per Steven ("across all the logs do we have enough
      weather info to add it to the top of the moonweather window above
      the moon images... need suggestions"). Data side already existed —
      `MyDSL_DataLayer.lua`'s `parseWeatherLine()` has captured
      `MyDSL.State.weather.description` from the real `weather` command
      for a while, and MoonWeather already listened for
      `MyDSL.weather.updated` to re-render — it just never read the text
      anywhere. Confirmed real taxonomy via corpus grep across 101
      captured `weather` outputs: Clear/Scattered clouds/
      Lightning-Storm/Rain/Sleet/Snow, each with day and night wording.
      Presented 3 display options via AskUserQuestion; Steven picked
      symbol + short label. Added `buildWeatherText()`
      (`MyDSL_MoonWeather.lua`), a new row above the moon circles,
      row-height proportions rebalanced (was 50/20/30, now
      12/44/18/26) to fit it. **Icon fix, same day**: Steven reported
      "no icons" live — root cause was 🌧/🌨 (Unicode's newer
      "Supplemental Symbols and Pictographs" block, 2014) not having
      guaranteed font coverage on Linux; switched the whole set to the
      much older, near-universal "Miscellaneous Symbols"/"Dingbats"
      blocks (1993–1999) — same family as ⚡/❄/☀/⛅/☁, which were already
      confirmed working. Sleet now reuses the snow symbol (text label
      disambiguates); clear-night switched ✨→☆ for the same font-age
      reason. **Wind added, same day**, per Steven ("wind should be
      captured. clouds, clear, rain, gold [cold] breeze, temperate wind,
      etc"). Confirmed complete taxonomy via corpus grep — 96 real
      samples across the full `log/` archive (193 files): temperature
      {cold, temperate, warm}, strength {gentle, moderate}, direction
      {north, south, east, west}, plus a calm/no-wind form — no other
      values found anywhere. New `MyDSL.extractWindClause()`
      (`MyDSL_DataLayer.lua`) pulls the wind portion out of the same
      sentence `parseWeatherLine()` already captures (covers the
      standard comma-joined form, confirmed 53/53 real samples); a
      narrow second trigger catches the rare period-joined continuation
      case (0 historical occurrences, but confirmed real live) without
      overwriting the precipitation description already captured.
      `MoonWeather`'s `windLabel()` renders it as a compact 2-word label
      (e.g. `Cold Breeze`) appended after the precipitation icon+label.
      Live-confirmed working — screenshot showed `Cloudy • Cold Breeze`
      with the wind label exactly right, but caught a second icon-font
      miss: ⛅ (Cloudy/day) showed no glyph at all, same failure mode as
      the earlier 🌧. Traced the actual cause this time instead of
      re-guessing: ⛅ (U+26C5) is Unicode 5.2 (2009), wrongly grouped
      earlier with the genuinely old (1993) ☀/☁/❄/☂/☆ — verified all 5 of
      those individually via compart.com this time, all real Unicode 1.1.
      Fixed by using plain ☁ for both day and night Cloudy (no old-block
      day-specific sun+cloud glyph exists). ⚡ (Storm) is Unicode 4.0
      (2003) — probably fine, but genuinely not yet live-tested (no storm
      weather hit during testing) — flagged, not swapped preemptively.
- [ ] **LiveView vitals-bar font bumped 8→9, needs live confirmation.** Per
      Steven ("would like the vitals bar text on either side to be larger
      (font 9?). HP/Mana/Move and hp/hpmax, mana/manamax, move,movemax. im
      only changing font size nothing else in there"). `barFont` already
      had a live-adjustable control (`mydsl live barfont <n>`, clamped
      6-14) — this is the same value that alias sets, so "font 9" was
      taken to mean that control's raw value. Changed the default
      (`MyDSL_LiveView.lua`) from 8→9 and the already-persisted value in
      `MyDSL/live_settings.lua` (which would otherwise have overridden the
      new default on next load) from 8→9. No other styling touched, per
      Steven's explicit scope limit.
- [ ] **RightHere Known/Seen/Unknown mob tagging + name accuracy — added
      2026-07-12, needs live confirmation.** Per Steven ("as we identify
      mobs, it should create a table to look up and find more accurate
      tags for targets... mob names are the most important... if we need
      to use an identifier alias, where we look then creaturelore, that
      could be an option"). Corpus research first: extracted 30 real
      `look`-vs-`scan` mob text pairs, confirmed the common case (plain
      unnamed mobs) already matches word-for-word after normalization, and
      that DSL's own target keyword matching only uses the *last word* of
      whatever name is sent (`commandArg()`, `MyDSL_TargetView.lua`) — so
      most surface-level wording differences don't actually change the
      command sent. Real divergence is narrower: named NPCs (deprioritized
      per Steven — "shopkeepers are not important") and generic/truncated
      `look` descriptions for mobs DSL never names specifically in room
      text (e.g. "A gnome is here using levers..." never says which gnome
      type). Found and adapted a prior *working* implementation for
      exactly this from the `DSL1` sibling profile's
      `MyDSL.CreatureDB`/`MyDSL.TargetCompact` (embedded in its
      `current/*.xml`): a single table classifies each mob as "known" (has
      real lore data), "seen" (sighted via look/scan, never lored), or
      "unknown" (no record) — derived from field presence, not a separate
      flag. Reused our own already-existing, already-persistent, already-
      shared `MyDSL_CreatureLore.lua` DB for this instead of building a
      second table: added `CL.hasLore()`/`CL.knownState()`/`CL.markSeen()`.
      `MyDSL_DataLayer.lua`'s `parseLookHereLine()`/`parseScanLine()` now
      call `markSeen()` for every mob capture, and resolve to
      CreatureLore's stored name (`resolveMobName()`) whenever that mob is
      "known" — this is what actually improves targeting accuracy, since a
      known name came from a real successful `lore` cast. Never guesses
      between multiple possible matches for a generic/truncated name (per
      Steven: "if we are unable to guess then a generic is better than
      none") — falls back to the captured text unchanged whenever there's
      no confirmed "known" match. `MyDSL_ScanView.lua`'s RightHere render
      now shows a colored `[Known]`/`[Seen]`/`[Unknown]` badge per mob,
      same color scheme as the DSL1 reference (green/cyan/yellow).
- [ ] **PortraitView: real "contain" (shrink-to-fit) renderer, fixed
      2026-07-12, needs live confirmation.** Per Steven ("the portrait is
      supposed to shrink kien's .png to fit the window") after screenshots
      showed a tiny, blown-up corner of the character art instead of the
      whole picture shrunk down. Root cause: `imageStyleFill()`'s
      `border-image: url(...)` CSS paints into the *border* area (a
      9-slice UI-frame technique), not the label's content area — without
      matching `border-image-slice`/width values it never actually scaled
      the whole picture to fit, regardless of Mudlet version. That
      renderer existed as a deliberate workaround for a real Mudlet
      4.20.1 issue (`Label:setBackgroundImage()` not reliably repainting
      inside a docked UserWindow) — but "contain" was being silently
      coerced to the same broken renderer either way. Built a real
      contain-fit renderer (`containImageHTML()`) using two genuine
      Mudlet/Geyser APIs: `getImageSize(path)` (native pixel dimensions
      of the file) and `label:get_width()/get_height()` (the label's
      actual live rendered pixel size) to compute a proper aspect-
      preserving scale, then draws it via an `<img>` tag through
      `label:echo()` — the same mechanism `MyDSL_MoonWeather.lua` already
      uses successfully for its moon icons, a completely different
      Mudlet pathway from `setBackgroundImage()`, so unaffected by that
      original workaround's reasoning. Default `fit` changed from
      `"cover"` to `"contain"` (both the in-code default and the already-
      persisted `MyDSL/portraits/portrait_profiles.lua`, which would
      otherwise have kept overriding the new default). `cover`/`stretch`
      still use the old, confirmed-unreliable border-image renderer —
      not redesigned this pass, since Steven only asked about the
      shrink-to-fit case specifically.
- [ ] **LocationView: same border-image bug as PortraitView, fixed
      2026-07-12, needs live confirmation.** Per Steven ("should prob
      check location after targetview, since it has images too") after
      the Portrait fix above. Confirmed via grep: `MyDSL_LocationView.lua`
      literally copied "the proven PortraitView/old CharPic render path"
      (its own header comment), so it inherited the identical bug —
      room pictures were never actually being scaled into the window
      either. Applied the same fix: `containImageHTML()` using
      `getImageSize()`/`label:get_width()/get_height()`, drawn via an
      `<img>` tag through `label:echo()`. Default `fit` changed from
      `"cover"` to `"contain"` in the in-code default, the
      `loadProfiles()` fallback, and the already-persisted
      `MyDSL/roompics/location_profiles.lua`. `cover`/`stretch` still use
      the old renderer, unchanged.
- [ ] CharacterAssist: rearm (weapon+shield), spellup/setspell,
      blind-vision check.

---

## TOP PRIORITY — Combat, needs live-fight testing
Per-swing main-console display, evasion triggers, both death-line forms,
weapon-flag proc attribution, and the PNP-faithful display rewrite are all
confirmed correct (code review + a real live fight, 2026-07-11) — see
`CHANGELOG.md`. Still open:
- [ ] Itemstat interference with `$`-anchored combat regex — real,
      native-XML system, confirmed decorating `eq`/`in` output client-side.
      Not proven to break combat triggers yet. Sequencing risk to
      remember when Layer 4 (reference library) is picked up, since our
      equipment parser currently depends on itemstats for stat data.
- [ ] **DEFERRED: Algoron Combat League (AGL) / Coliseum combat module** —
      new idea, not scoped. Coliseum/AGL combat should be captured
      separately, in a large window with 4 floating sub-windows at the
      cardinal positions matching the Coliseum's wall echoes. Groundwork
      (bracket-prefix format, applicable procs) already gathered from this
      session's investigation — see CHANGELOG.
- [ ] Discuss once combat is fully confirmed (deliberately deferred, per
      Steven: "make it work like PNP, then discuss the additions"):
      whether `renderSummary()`'s persistent "Fight summary" block (our
      own addition, no PNP equivalent) should match PNP's sentence style.

---

## PAUSED — needs more captured log data before further progress
Per Steven: "lets pause the capture logs phase... we will return to them
when we have more data to scan." Every available log source on this
machine (DSL2's own corpus, 3 PNP sibling profiles, DSL1,
Qinrathaz-Vaelis, `log/Archive.zip`, 24 AGL tournament transcripts) has
been searched with zero real occurrences of the needed text — not
guessing at patterns with zero corpus evidence.
- [ ] Quoted weapon names (`"Nadrik's Honor"`) in damage lines — plausible
      latent capture-group bug, zero confirmed real examples of a quoted
      weapon name specifically.
- [ ] `procUnholy`/`procManaSelf` — zero occurrences anywhere; 2 near-misses
      found and ruled out (not force-fit).
- [ ] `combatSense1/2` (sense-based evasion) — real ability (bard-only per
      helpfiles), exact echo wording unconfirmed anywhere. Needs a bard
      specifically playing/logging.
- [ ] `A.ids.triggers.song` (AffectsView "Song:" format) — prior
      "confirmed" matches turned out to be pre-DSL2 log data.
- [ ] Mage-cast `poison` spell's onset text — one unconfirmed candidate
      line spotted (`"...looks very ill."`), not enough occurrences to
      confirm vs. coincidence.

---

## OPEN — Reported bugs, not yet fixed
- [ ] **Sibling-profile log scanning** — a targeted `grep -r` for a
      specific known phrase across every file in a sibling profile can
      still pay off even when the profile looks mostly like debug noise;
      sampling one large file isn't representative. Worth repeating for
      other specific phrases if this comes up again.
- [ ] `autowhere` fires while sleeping — Steven's own alias, not ours; low
      priority for us specifically.
- [ ] **"None" leaking into main console every ~20s, fixed 2026-07-12,
      needs live confirmation.** Steven: "something broke the autowhere
      alias and it now displays none instead of gaging it." Not actually
      an autowhere break, and not room-specific despite how it first
      looked — confirmed via a log-corpus grep
      (`log/2026-07-12#09-01-16.html`) that DSL's `where` command has a
      second response shape: a bare standalone `"None"` line with no
      `"Players near you:"` header at all when nobody else is nearby
      (vs. the header + name/room lines when someone is). The existing
      capture trigger only matches the header, so the empty case fell
      straight through into the main console untouched on every
      `autowhere` tick. Added a second trigger matching `^None$` (whole
      line only, to minimize collision risk with any other real DSL text
      that might legitimately be the standalone word "None" in an
      unrelated context) that moves it into `MyDSL_PlayersNear` the same
      way the header case already does — `MyDSL_DataLayer.lua`. Watch for
      any other context where a bare "None" line legitimately means
      something else and gets wrongly swallowed by this.
- [ ] Murder/Consider/Order-All → "They're not here" on look-populated
      wildlife targets — investigated, likely a genuine race (mob wanders
      off between `look` populating RightHere and the command reaching
      the server), not a TargetView name-matching bug. Not fully ruled
      out.
- [ ] "multiple mob health echoes in combat... one we create and one from
      the game" — likely the same already-tracked discussion as the
      `renderSummary()` "Fight summary" item above (TOP PRIORITY Combat),
      not independently confirmed as a separate issue.

---

## OPEN — Needs Steven's decision before building
- [ ] Itemstat trigger retirement timing — see the Combat section note
      above; just needs sequencing against Layer 4, not a decision now.
- [ ] "Prompt Line 1" parsing — not scoped, low priority, likely fully
      redundant with GMCP (`char_data.stance`/`language`/`is_flying`).
      Only worth it if a flag turns up that GMCP doesn't cover.

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
- [ ] Item-clickable reference module — depends on Layer 4.
- [ ] Census (from UI) interacting with the reference module — depends on
      Layer 4.
- [ ] State-scoped sound toggle — generic pattern for an alias to turn a
      sound on for a state and reliably turn it off when the state ends.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **`MyDSL_PromptSetup.lua`** — built 2026-07-09, put down for later.
      One-click DSL prompt setup for brand-new characters. Code exists,
      committed, but has no `dofile()` entry. Full design writeup:
      `docs/CHANGELOG.md`, commit `2ec4fb0`.
- [ ] **Cross-profile master function/feature inventory** — walk every
      `.lua` file across every Mudlet profile on this machine, build one
      consolidated list. Large, multi-session scope, its own future
      session.
- [ ] **Layer 4: Reference library** (items, mobs, lore) — not started.
      Check `~/Downloads/Shattered-Archive-release-dev.zip` before
      building from scratch.
- [ ] **Mapper hardening/MyDSL integration** — deferred until current UI
      workload finishes.
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
- **~20 misc aliases** (`(inv)`, `(autowhere)`, attire-swap sets, etc.) —
  fine as native aliases unless one becomes relevant to a window.

---

## DECISIONS RECORDED
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

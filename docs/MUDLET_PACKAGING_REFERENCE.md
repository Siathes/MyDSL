# Mudlet Packaging — Confirmed Behavior & Required Procedure

**Read this before every `build_mydsl_package.py` run and every package
delivery to Steven.** Added 2026-08-26 after a real, confirmed bug: the
live MyDSL profile's Key Bindings had accumulated **16 nested
`MyDSL_Full` KeyGroup wrappers**, one inside the next, discovered live
via a screenshot of Mudlet's Key editor. Root-caused directly against
Mudlet's own C++ source (`Mudlet/Mudlet` on GitHub, `development`
branch — not assumed, not guessed from forum posts, which 403'd on
every fetch attempted), not left as "huh, weird."

## Confirmed mechanism (read directly from Mudlet's source)

- `XMLimport.cpp`'s `readScript()`/`readKey()` **always construct a
  brand-new object on import, with zero name/packageName
  deduplication** — reimporting a package whose content already
  exists does not replace or merge anything; it adds a fresh copy as
  a *child* of whatever's already there if the importer is fed content
  nested under an existing same-named folder.
- `Host::installPackage()`, for a plain **Package** (not a Module),
  actually *refuses* to install if `mInstalledPackages` (an in-memory,
  session-only list) already contains that package name — it does
  **not** silently reinstall on top. That check is bypassed the moment
  Mudlet restarts (the in-memory list resets), which is exactly what
  "quit Mudlet, relaunch, install the new build" (the normal workflow
  this project uses) does every time.
- `Host::uninstallPackage()` calls `mKeyUnit.uninstall(packageName)`
  symmetrically with `mScriptUnit`/`mTriggerUnit`/etc. Each unit's
  `uninstall()` matches **root-level** nodes by `mPackageName ==
  packageName`, then `_uninstall()` recursively queues **every
  descendant of a matched root, unconditionally** (no per-descendant
  packageName check) for deletion. So a real `uninstallPackage()` call
  — if it actually runs before the next install — removes an entire
  matching subtree in one shot, nested or not.
- **The practical conclusion, confirmed by direct measurement in the
  live profile** (`current/autosave.xml`, 2026-08-26): Scripts (max
  nesting depth 1) and Triggers (max depth 5) had **not** accumulated
  this way; Keys had (depth 16, exactly one level per past
  install/relaunch cycle). The exact reason only Keys show this at
  scale wasn't traced further than the general finding above — not
  worth more C++ archaeology than this once the fix is the same either
  way. Treat "reinstalling without uninstalling first can nest content
  for any object type" as the operating assumption, not just Keys.

## The one rule that prevents this

**Every time a new `MyDSL_Full.mpackage` build is delivered, uninstall
the old one first, then install the new one — never install straight
over an existing install.** This project already knew this pattern was
correct (see `CLAUDE.md`'s note on EMCO's own `emco update` alias doing
exactly `uninstallPackage()` + reinstall) but never applied it to our
*own* package deliveries — that gap is the actual root cause of this
incident, not a Mudlet bug we can't work around.

In Mudlet:
- **UI**: Package Manager (Games menu, or `Toolbox > Package Manager`)
  → select `MyDSL_Full` → Uninstall → then install the new
  `.mpackage` file.
- **Lua** (equivalent, scriptable): `uninstallPackage("MyDSL_Full")`
  then `installPackage("/path/to/MyDSL_Full.mpackage")`.

State this explicitly every time a package is handed to Steven for
install — don't just say "install this," say "uninstall the old
MyDSL_Full first, then install this one."

## Build-script defense (belt and suspenders)

`build_mydsl_package.py`'s `get_native_key_group()` (and the analogous
script/trigger extraction) must not blindly re-embed whatever nested
mess currently exists in the live snapshot — see the function's own
comment for the flattening logic added 2026-08-26. This makes a future
build self-healing (it emits one clean `MyDSL_Full` KeyGroup regardless
of how corrupted the live snapshot is) even if the uninstall-first rule
above is ever skipped by mistake.

## Checklist before every package delivery

1. Run `build_mydsl_package.py`, confirm the printed script/trigger/key
   counts look sane (roughly stable from the last build, not wildly
   different).
2. If anything about the counts looks off, inspect the native source
   snapshot directly (`python3 -c "import xml.etree.ElementTree as ET;
   ..."`, walk the KeyPackage/TriggerPackage/ScriptPackage depth) before
   shipping — don't assume it's fine.
3. Tell Steven explicitly: **uninstall the old `MyDSL_Full` package
   first, then install the new one.** Every time, not just when
   something looks wrong.
4. If Steven reports something visually strange in ANY native editor
   (Triggers, Aliases, Keys, Scripts) after an install, check for this
   exact nesting pattern before assuming it's a code bug in the addon
   itself.

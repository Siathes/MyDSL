# Testing MyDSL modules outside Mudlet

`mudlet_mock.lua` is a minimal stand-in for Mudlet's global Lua API
(`tempRegexTrigger`, `tempAlias`, `send`, `echo`, `Geyser`, `gmcp`, `table.save`/
`table.load`, etc.) — just enough that a real `MyDSL_*.lua` file can be
`dofile()`'d outside Mudlet entirely, so its real functions can be called
directly with real captured game text and checked for runtime errors,
without needing a live Mudlet session.

This isn't a full emulator. It doesn't run a fake MUD or fake GMCP traffic —
it only avoids load-time errors so the file's real logic becomes callable.
You still drive it by hand: set up whatever state the function you're
testing needs, call it, and check what happened (what got `send()`, what's
in a config table, etc.).

Run with `luajit` (already used throughout this project for syntax checks).
Layer 3 view modules (Combat/Target/Group/Scan/...) all call
`MyDSL.Windows.ensure(...)` during their own `init()`, so they need a
one-line stub for that too — `MyDSL.Windows` is one of our own modules
(`MyDSL_WindowRegistry.lua`), not part of the Mudlet API the mock covers:

```
luajit -e "
dofile('test/mudlet_mock.lua')
MyDSL = { Windows = { ensure = function() return {} end } }
dofile('MyDSL_CombatView.lua')
-- now call real functions, e.g.:
MyDSL.CombatView.setFont(6)
print(MyDSL.CombatView.config.fontSize)
"
```

## Overriding a mock function per test

Some tests need a specific fake behavior instead of the mock's generic
no-op — e.g. `table.save`/`table.load` real disk round-trips, or
`registerAnonymousEventHandler` recording handlers so you can fire them
manually to simulate `raiseEvent()`. Override after loading the mock, before
loading the module under test:

```lua
dofile('test/mudlet_mock.lua')

local handlers = {}
function registerAnonymousEventHandler(name, fn)
  handlers[name] = handlers[name] or {}
  table.insert(handlers[name], fn)
  return #handlers
end

function table.save(path, tbl)
  local f = io.open(path, 'w')
  f:write('return { fontSize = ' .. tostring(tbl.fontSize) .. ' }\n')
  f:close()
  return true
end
function table.load(path)
  local chunk = loadfile(path)
  if not chunk then return nil end
  return chunk()
end

dofile('MyDSL_CombatView.lua')

-- simulate raiseEvent("MyDSL.character.identified") manually:
for _, fn in ipairs(handlers['MyDSL.character.identified'] or {}) do fn() end
```

## What this has already caught

This approach (not the specific mock file, which only exists now — it was
rebuilt ad hoc in scratch every session before 2026-07-07) has directly
found real bugs in this project: an order-of-definition bug where a local
helper function was referenced before its own definition (silent nil-call
at runtime, invisible to `luajit -e "assert(loadfile(...))"`  since that
only checks syntax, not execution), a `MyDSL._aliases` fresh-start crash
that only a genuinely fresh Lua state could reproduce, and the
`MyDSL.character.identified` event actually reloading the right
character's settings end-to-end. Prefer this over "it loads without a
syntax error" whenever a fix depends on *execution order* or *runtime
values*, not just syntax.

## Real limitation: regex verification isn't regex EXECUTION

This mock does not touch Mudlet's actual regex engine at all — `mudlet_mock.lua`
stubs `tempRegexTrigger`/`tempAlias` to just record a pattern, it never
compiles or runs one. When a test needs to confirm a regex genuinely
matches a real captured line, that check has to happen outside the mock,
and this project's own convention (see `test_combat_damage_regex.lua`'s
header) is Python's `re` module as a PCRE stand-in — explicitly described
there as "near-identical... for the constructs used here," not identical.
That caveat is load-bearing: **this exact project has hit real PCRE-vs-
Lua-pattern bugs three separate times** (the group-header `%'` bug, the
`%s`/`\S` alias sweep, the door-verb `|`-in-a-Lua-pattern bug in the
mapper fork) — precisely the class of mismatch a near-equivalent engine
can paper over.

**Recommended, not yet standard practice**: for any regex fix where the
PCRE-specific behavior actually matters (alternation, lookaround, PCRE-only
escapes — not just "does this literal text match"), cross-check against
real PCRE with `perl -e`, not just Python `re`. This was done once
(2026-07-25 CHANGELOG entry, for exactly this reason: "Python's re isn't a
perfect PCRE clone and Mudlet's own regex engine is genuinely PCRE-based")
but never written down as the standard — confirmed 2026-08-23 that `perl`
is present on this machine. Quick pattern:
```
perl -e '
my $line = "the real captured game text";
if ($line =~ /your_pcre_pattern_here/) { print "MATCH: $1 / $2\n" }
else { print "NO MATCH\n" }
'
```
Python `re` alone remains fine for a quick sanity check or a pattern with
no PCRE-specific constructs; reach for `perl` whenever the fix is
specifically about a PCRE-vs-Lua-pattern distinction, since that's the
exact blind spot a "near-identical" engine can't be trusted to catch.

## If `luajit` isn't available in your environment

An external review pass (Claude Desktop, connected via this repo's
GitHub connector, 2026-08-23) hit this directly — no `luajit` in that
environment, so it couldn't independently run this test suite at all.
Worked around it by building LuaJIT from source (both `gcc`/`make` were
present): clone `https://github.com/LuaJIT/LuaJIT`, `make` in the
checkout, then use the resulting `src/luajit` binary in place of a
system `luajit`. Worth doing rather than skipping test verification
entirely — "I couldn't check" and "it's confirmed clean" are different
claims, and `docs/CHANGELOG.md` has been asserting the latter after
every fix. (Correction: this note originally credited a separate
Claude.ai pass, which hit the same missing-`luajit` wall independently
but didn't solve it — the from-source workaround was Claude Desktop's,
caught and corrected by Claude Desktop itself after independently
verifying this file.)

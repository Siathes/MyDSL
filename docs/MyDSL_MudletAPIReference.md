# MyDSL Mudlet API Reference
**Confirmed rules from Mudlet wiki + live in-game testing**
*Written 2026-07-03 — authoritative, do not re-derive from inference*

---

## CONFIRMED: tempRegexTrigger / tempAlias use pure PCRE — no Lua-pattern translation

**Source:** Mudlet wiki Manual:Technical Manual, Manual:Trigger Engine, Manual:Alias Engine (checked 2026-07-03).
**Live confirmation:** scan sw/scan ne in Dragon Valley — directional peek text printed to main console
but the Scan window never updated, proving scanDir's `%a+%.` pattern never matched.

`tempRegexTrigger()` and `tempAlias()` both take **Perl-compatible regex (PCRE)** patterns, full stop.
There is **no character-class translation layer**. Lua-pattern tokens (`%a`, `%s`, `%d`, `%w`, `%'`, `%.`)
are not converted to their PCRE equivalents. A `%` in a trigger/alias pattern is a literal percent
character — if none appears in the actual game text, the trigger silently never fires.

---

## Two contexts, two different rules

| Context | Engine | Character class syntax |
|---|---|---|
| `tempRegexTrigger(pattern, ...)` | **PCRE** | `\d`, `\w`, `\s`, `[a-zA-Z]`, `\.`, plain `'` |
| `tempAlias(pattern, ...)` | **PCRE** | `\d`, `\w`, `\s`, `[a-zA-Z]`, `\.`, plain `'` |
| `string.match(str, pattern)` | **Lua patterns** | `%d`, `%w`, `%s`, `%a`, `%.`, `%'` |
| `str:match(pattern)` | **Lua patterns** | same as above |

Lua patterns are only relevant inside the **body** of a trigger/alias (in `string.match()` calls),
never in the pattern field itself.

---

## In Lua string literals, PCRE backslash-escapes need doubling

Because `\` is the Lua string escape character, PCRE tokens that use `\` must be written with `\\`
in the Lua string literal so the single `\` reaches the PCRE engine:

| Intended PCRE token | Lua string literal to write |
|---|---|
| `\s` (whitespace) | `"\\s"` |
| `\S` (non-whitespace) | `"\\S"` |
| `\d` (digit) | `"\\d"` |
| `\w` (word char) | `"\\w"` |
| `\.` (literal period) | `"\\."` |
| `[a-zA-Z]+` (letters) | `"[a-zA-Z]+"` (no backslash needed) |
| `[^.]+` (not period) | `"[^.]+"` (dot is literal inside `[]`) |

---

## Bugs fixed from this confusion (all 2026-07-03)

| Trigger/Alias | Pattern as written | Problem | Fixed to |
|---|---|---|---|
| DataLayer `groupStart` | `"^.+%'s group:$"` | `%'` → PCRE literal `%'`, never matched `"Kien's group:"` | `"^.+'s group:$"` |
| DataLayer `scanDir` | `"^You peer intently (%a+)%.$"` | `%a` = literal `%a`, `%.` = `%` + any char | `"^You peer intently ([a-zA-Z]+)\\.$"` |
| DataLayer `sunrise` | `"^The sun rises in the east%.$"` | `%.` = `%` + any char, not literal `.` | `"^The sun rises in the east\\.$"` |
| DataLayer `sunset` | `"^The night has begun%.$"` | same | `"^The night has begun\\.$"` |
| DataLayer `weather` | `"^[A-Z][^%.]+%.$"` | `[^%.]` excludes `%` unnecessarily; `%.` wrong | `"^[A-Z][^.]+\\.$"` |
| DataLayer `loreStart` | `"^Creature:%s"` | `%s` = literal `%s`, not whitespace | `"^Creature:\\s"` |
| ScanView `gagDir` | `"^You peer intently %a+%.$"` | same as `scanDir` | `"^You peer intently [a-zA-Z]+\\.$"` |
| TargetView `considerLine2` | `"^%.%.%. "` | `%.` = `%` + any char, not `.` | `"^\\.\\.\\.  "` → `"^\\.\\.\\. "` |
| TargetView `targetMobset` | `"^mydsl target mobset%s+(%S+)..."` | `%s`/`%S` = literal | `"^mydsl target mobset\\s+(\\S+)..."` |
| TargetView `targetPlayerset` | `"^mydsl target playerset%s+(%S+)..."` | same | `"^mydsl target playerset\\s+(\\S+)..."` |
| GroupView `quickset` | `"^mydsl group quickset%s+(%S+)%s+(%S+)$"` | same | `"^mydsl group quickset\\s+(\\S+)\\s+(\\S+)$"` |

---

## Rule of thumb

Before writing any `tempRegexTrigger`/`tempAlias` pattern, write it as if you're in a PCRE tester
(regex101.com, Perl mode). Never reach for a `%` shortcut from Lua muscle memory.

If a body script needs to parse the matched line further (e.g. extract the direction from
"You peer intently northeast."), use `getCurrentLine():match(lua_pattern)` with proper Lua `%`
escapes — that call goes through `string.match()` which is Lua, not PCRE.

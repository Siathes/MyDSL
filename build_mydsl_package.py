#!/usr/bin/env python3
"""
Build MyDSL_Full.mpackage from the current repo + a native-content reference.

Why this exists: the original version of this script was written into a
session-scoped scratchpad directory (not this repo) and disappeared between
sessions -- a real rebuild was needed on 2026-07-19 and it was gone. This is
a from-scratch rewrite, informed by directly comparing a hand-patched
package against the live MyDSL profile's actual installed content (see
docs/CHANGELOG.md, 2026-07-19 entries) so the two content sources below are
exactly what's really needed, not guessed at.

MyDSL_Full bundles two genuinely different kinds of content:

  1. The git-tracked .lua "dofiles" -- rewritten constantly, always rebuilt
     fresh from disk. The list + load order is read directly from THIS
     repo's own reference current/*.xml (DSL2's dev profile, where each
     Script's body really is just `dofile("/path/to/Foo.lua")`) rather than
     hardcoded here, so adding/removing/reordering a dofile in the Script
     Editor is automatically picked up on the next build with no edit to
     this file.

  2. Native-only content that has NO git-tracked source: 2 hand-placed
     Scripts (MyDSL_MovementSounds, DslColors_Core_v1_0), the
     MyDSL_GameplayTriggers + DslColors_v1_0 Triggers, and the "Movement"
     native Keys. This changes rarely and isn't backed by any file in this
     repo, so it's pulled from a live/native reference snapshot instead --
     by default the newest current/*.xml in the LIVE MyDSL profile (the
     play/test profile, not this dev one -- that's where Steven's real,
     currently-installed native content lives). Per this project's own
     established gotcha, the newest file by mtime is used, never a fixed
     filename like autosave.xml.

Sanity checks throughout FAIL LOUDLY (raise, not warn-and-continue) if the
reference snapshot's content doesn't match what's expected -- e.g. if the
set of "extra" native-only scripts isn't exactly the 2 known ones. The
2026-07-19 data-loss incident happened because a build script silently
didn't know about content it should have included; this one refuses to
guess quietly instead of repeating that.

Usage:
    python3 build_mydsl_package.py
    python3 build_mydsl_package.py --dofile-source current/2026-07-18#10-13-31.xml \\
                                    --native-source /path/to/MyDSL/current/whatever.xml \\
                                    --out MyDSL_Full.mpackage

Verification after building (always do both before shipping):
    python3 -c "import xml.etree.ElementTree as ET; ET.parse('MyDSL_Full.xml')"
    for each embedded Script's un-escaped content: luajit -e "loadfile(...)"
"""

import argparse
import datetime
import glob
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))

# The native-only scripts known (as of 2026-07-19) to genuinely have no
# git-tracked .lua source at all -- see docs/CHANGELOG.md's 2026-07-19
# data-loss-incident entry for how these were originally identified.
# MyDSL_MovementSounds turned out to already have a real tracked .lua file
# (just not dofile-wired in DSL2's own reference profile -- see the
# recovered_dofiles handling below), so it's read fresh from disk instead
# and is NOT in this set. If the native reference ever shows a leftover
# script that ISN'T DslColors_Core_v1_0 AND doesn't match a real file in
# this repo either, that's genuine drift worth a human's attention, not
# something to silently absorb.
EXPECTED_NATIVE_ONLY_SCRIPTS = {"DslColors_Core_v1_0"}

# Scripts deliberately removed from this project (git-tracked source
# deleted, dofile() entry removed from DSL2's own reference profile) but
# that will keep showing up in the LIVE MyDSL profile's own native
# snapshot until Steven actually uninstalls the old MyDSL_Full package
# and installs a freshly-built one (see docs/MUDLET_PACKAGING_REFERENCE.md).
# Explicitly excluded here rather than silently re-bundled or added to
# EXPECTED_NATIVE_ONLY_SCRIPTS (which would wrongly imply this is expected,
# permanent content, not a retired leftover).
RETIRED_SCRIPTS = {
    "MyDSL_RawCapture",  # removed 2026-08-27, per Steven -- zero dependents
}

# Native Trigger/Key package names known to belong to MyDSL_Full.
NATIVE_TRIGGER_PACKAGE_NAMES = {"MyDSL_GameplayTriggers", "DslColors_v1_0"}
NATIVE_KEY_PACKAGE_NAME = "MyDSL_Full"


def newest_xml(pattern):
    matches = glob.glob(pattern)
    if not matches:
        raise SystemExit(f"No files matched {pattern!r} -- can't find a reference snapshot.")
    return max(matches, key=os.path.getmtime)


def xml_escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def find_child(elem, tag):
    for c in elem:
        if c.tag == tag:
            return c
    return None


def get_dofile_list(dofile_source):
    """Return [(name, path), ...] in load order, read from a DSL2-style
    reference XML whose Script bodies are literally dofile("...") calls.

    The packaged Script's name is derived from the dofile PATH's basename,
    not the Script's own <name> tag in DSL2's dev reference -- confirmed
    2026-07-19 that at least two of these have drifted from their real
    filename (e.g. a Script literally named "MyDsl_Alterform" that
    dofiles MyDSL_AlterformView.lua, and "MyDSL_Creaturelore" for
    MyDSL_CreatureLore.lua) -- the live/native profile's own copies are
    named after the real file, and matching by that is what actually
    lines up with the native-only-script detection below.
    """
    tree = ET.parse(dofile_source)
    sp = find_child(tree.getroot(), "ScriptPackage")
    if sp is None:
        raise SystemExit(f"{dofile_source}: no <ScriptPackage> found.")

    out = []
    for s in sp.iter("Script"):
        scr = s.find("script")
        if scr is None or not scr.text:
            continue
        m = re.search(r'dofile\("([^"]+)"\)', scr.text)
        if m:
            path = m.group(1)
            name = os.path.splitext(os.path.basename(path))[0]
            out.append((name, path))
    if not out:
        raise SystemExit(f"{dofile_source}: found <ScriptPackage> but zero dofile(...) scripts -- wrong file?")
    return out


def find_package_group(container, tag, packageName):
    """Find the direct child of `container` (a *Package element) whose
    <packageName> equals `packageName`, walking the whole subtree if the
    top-level groups don't match directly (native content's exact nesting
    has changed shape before -- see docs/CHANGELOG.md 2026-07-19)."""
    for top in container:
        pkg = find_child(top, "packageName")
        if pkg is not None and pkg.text == packageName:
            return top
    return None


def get_native_only_scripts(native_source):
    """Return {name: raw_script_text} for every Script under the
    native reference's MyDSL_Full-owned ScriptGroup that ISN'T one of the
    dofile scripts (i.e. has no git-tracked .lua counterpart)."""
    tree = ET.parse(native_source)
    sp = find_child(tree.getroot(), "ScriptPackage")
    if sp is None:
        raise SystemExit(f"{native_source}: no <ScriptPackage> found.")

    group = find_package_group(sp, "ScriptGroup", "MyDSL_Full")
    if group is None:
        raise SystemExit(
            f"{native_source}: no ScriptGroup with packageName=MyDSL_Full found -- "
            "is this really a snapshot with MyDSL_Full installed?"
        )

    out = {}
    for s in group.iter("Script"):
        nm = s.find("name")
        scr = s.find("script")
        if nm is None:
            continue
        out[nm.text] = scr.text if scr is not None and scr.text else ""

    return out


def get_native_trigger_groups(native_source):
    """Return the actual <TriggerGroup> elements for MyDSL_GameplayTriggers
    and DslColors_v1_0, wherever they sit in the tree (top-level siblings,
    or nested under a MyDSL_Full wrapper -- both shapes have been observed
    live, see docs/CHANGELOG.md 2026-07-19)."""
    tree = ET.parse(native_source)
    tp = find_child(tree.getroot(), "TriggerPackage")
    if tp is None:
        raise SystemExit(f"{native_source}: no <TriggerPackage> found.")

    found = {}

    def walk(elem):
        pkg = find_child(elem, "packageName")
        if pkg is not None and pkg.text in NATIVE_TRIGGER_PACKAGE_NAMES:
            found[pkg.text] = elem
            return  # don't descend into an already-matched group
        for c in elem:
            if c.tag in ("TriggerGroup",):
                walk(c)

    for top in tp:
        walk(top)

    missing = NATIVE_TRIGGER_PACKAGE_NAMES - set(found)
    if missing:
        raise SystemExit(f"{native_source}: missing expected native trigger group(s): {missing}")

    return [found[name] for name in sorted(found)]


def flatten_self_nested_wrapper(elem, tag, name):
    """Real bug found live 2026-08-26 (see docs/MUDLET_PACKAGING_REFERENCE.md):
    repeatedly reinstalling MyDSL_Full.mpackage without uninstalling the old
    copy first causes Mudlet's own XML importer (confirmed directly against
    Mudlet's source, XMLimport.cpp -- it has zero name-based dedup on import)
    to nest a fresh same-named wrapper INSIDE the previous one every time.
    Found 16 levels deep for the KeyGroup specifically in the live profile.

    `elem` is the OUTERMOST matched group. If it has exactly one child, that
    child is itself a `tag` element named `name`, descend into it -- repeat
    until reaching a level that either has real content (0, 2+ children, or
    a child that isn't just another same-named wrapper) or genuinely has
    nothing left. Returns the innermost REAL group, so a build always emits
    exactly one clean wrapper regardless of how corrupted the live snapshot
    already is -- self-healing, not just a one-time manual cleanup."""
    # A real KeyGroup/ScriptGroup/TriggerGroup element always carries several
    # metadata child tags (name, packageName, script, command, keyCode,
    # keyModifier, eventHandlerList, ...) alongside its actual content --
    # only the content tags (the group tag itself, plus its matching leaf
    # item tag) count towards "how many real sub-items does this hold."
    leaf_tag = {"KeyGroup": "Key", "ScriptGroup": "Script", "TriggerGroup": "Trigger"}.get(tag)
    content_tags = {tag, leaf_tag} if leaf_tag else {tag}

    seen = 0
    while True:
        content_children = [c for c in elem if c.tag in content_tags]
        if len(content_children) != 1:
            return elem
        only = content_children[0]
        if only.tag != tag:
            return elem
        nm = find_child(only, "name")
        if nm is None or nm.text != name:
            return elem
        elem = only
        seen += 1
        if seen > 100:
            # Sanity backstop -- a real profile should never nest this deep;
            # something else is wrong if this trips, don't loop forever.
            raise SystemExit(
                f"flatten_self_nested_wrapper(): unwrapped {seen} levels of "
                f"'{name}' {tag} without finding real content -- stopping "
                "rather than looping forever. Inspect the native source by hand."
            )


def unwrap_own_package_name_layer(elem, tag, leaf_tag, name):
    """Real packaging-format bug found live 2026-08-26 (see
    docs/MUDLET_PACKAGING_REFERENCE.md), confirmed directly against Mudlet's
    own source (XMLimport::importPackage()): on EVERY install, Mudlet wraps
    a package's top-level content in its OWN synthetic folder named after
    the package (the archive's filename, sanitized -- "MyDSL_Full" for us).
    That happens unconditionally, every single install, for every object
    type (Key/Script/Trigger/Alias/Timer/Action alike).

    Our own build was ALSO wrapping its exported content in an outer group
    literally named "MyDSL_Full" -- so every install stacked a second,
    redundant same-named layer on top of Mudlet's own. Given `elem` (the
    outer, already content-flattened wrapper named `name`), return its real
    children directly so Mudlet's synthetic wrapper is the ONLY "MyDSL_Full"
    folder that ever exists, however many times this gets reinstalled."""
    nm = find_child(elem, "name")
    if nm is None or nm.text != name:
        raise SystemExit(
            f"unwrap_own_package_name_layer(): expected a '{name}' {tag} wrapper, "
            f"got '{nm.text if nm is not None else None}' -- inspect by hand."
        )
    content_tags = {tag, leaf_tag} if leaf_tag else {tag}
    children = [c for c in elem if c.tag in content_tags]
    if not children:
        raise SystemExit(
            f"unwrap_own_package_name_layer(): '{name}' {tag} has no real "
            "content children -- inspect by hand."
        )
    return children


def get_native_key_groups(native_source):
    tree = ET.parse(native_source)
    kp = find_child(tree.getroot(), "KeyPackage")
    if kp is None:
        raise SystemExit(f"{native_source}: no <KeyPackage> found.")

    group = find_package_group(kp, "KeyGroup", NATIVE_KEY_PACKAGE_NAME)
    if group is None:
        raise SystemExit(
            f"{native_source}: no KeyGroup with packageName={NATIVE_KEY_PACKAGE_NAME} found."
        )
    flattened = flatten_self_nested_wrapper(group, "KeyGroup", NATIVE_KEY_PACKAGE_NAME)
    if flattened is not group:
        print(f"NOTE: flattened a self-nested '{NATIVE_KEY_PACKAGE_NAME}' KeyGroup "
              "wrapper down to its real content -- see docs/MUDLET_PACKAGING_REFERENCE.md.")
    return unwrap_own_package_name_layer(flattened, "KeyGroup", "Key", NATIVE_KEY_PACKAGE_NAME)


def build_script_element_xml(name, raw_lua_text):
    return (
        "      <Script isActive=\"yes\" isFolder=\"no\">\n"
        f"        <name>{name}</name>\n"
        "        <packageName></packageName>\n"
        f"        <script>{xml_escape(raw_lua_text)}</script>\n"
        "        <eventHandlerList></eventHandlerList>\n"
        "      </Script>\n"
    )


def elem_to_xml(elem, indent="  "):
    """Serialize an ElementTree element back to Mudlet-style XML text.
    ET.tostring() is used directly -- Mudlet's own export doesn't
    pretty-print consistently either, and re-indenting risks corrupting
    embedded <script> text that itself starts with whitespace-sensitive
    Lua comments."""
    return ET.tostring(elem, encoding="unicode")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dofile-source", default=None,
                     help="DSL2 reference current/*.xml to read the dofile list from "
                          "(default: newest current/*.xml in this repo)")
    ap.add_argument("--native-source", default=None,
                     help="Live MyDSL profile current/*.xml to pull native-only "
                          "Scripts/Triggers/Keys from (default: newest current/*.xml "
                          "in the sibling MyDSL profile, if found)")
    ap.add_argument("--out", default=os.path.join(REPO_ROOT, "MyDSL_Full.mpackage"))
    args = ap.parse_args()

    dofile_source = args.dofile_source or newest_xml(os.path.join(REPO_ROOT, "current", "*.xml"))

    native_source = args.native_source
    if not native_source:
        candidates = glob.glob(
            os.path.join(os.path.dirname(REPO_ROOT), "MyDSL", "current", "*.xml")
        )
        if not candidates:
            raise SystemExit(
                "Can't find a native-content reference snapshot. Pass --native-source "
                "explicitly (a current/*.xml from the live MyDSL profile)."
            )
        native_source = max(candidates, key=os.path.getmtime)

    print(f"dofile source:  {dofile_source}")
    print(f"native source:  {native_source}")

    dofiles = get_dofile_list(dofile_source)
    print(f"{len(dofiles)} dofile scripts found")

    native_only = get_native_only_scripts(native_source)
    dofile_names = {name for name, _ in dofiles}
    extra_names = set(native_only) - dofile_names

    retired_found = extra_names & RETIRED_SCRIPTS
    if retired_found:
        print(f"NOTE: skipping retired script(s), not bundling: {sorted(retired_found)} "
              "-- see RETIRED_SCRIPTS at the top of this file.")
        extra_names -= RETIRED_SCRIPTS

    # An "extra" name that turns out to match a real git-tracked .lua file
    # in this repo isn't native-only at all -- it's a dofile that just
    # isn't wired into DSL2's own reference profile yet (same class of gap
    # as the 2026-07-15 MyDSL_PromptSetup miss). Read it fresh from disk,
    # like every other dofile, instead of trusting a frozen snapshot copy
    # -- and say so loudly, since the real fix is adding the dofile()
    # entry in DSL2's Script Editor, not this workaround.
    recovered_dofiles = []
    for name in sorted(extra_names):
        candidate = os.path.join(REPO_ROOT, name + ".lua")
        if os.path.isfile(candidate):
            print(
                f"WARNING: '{name}' has no dofile() entry in {dofile_source}, but "
                f"{candidate} exists and is git-tracked -- reading it fresh from disk "
                "instead of the frozen native snapshot. Add a dofile() entry for this "
                "in DSL2's Script Editor so it doesn't depend on this workaround."
            )
            recovered_dofiles.append((name, candidate))
    for name, _ in recovered_dofiles:
        extra_names.discard(name)
    dofiles = dofiles + recovered_dofiles

    if extra_names != EXPECTED_NATIVE_ONLY_SCRIPTS:
        raise SystemExit(
            "Native-only script set doesn't match what's expected -- real drift, "
            "not safe to guess past this.\n"
            f"  expected: {sorted(EXPECTED_NATIVE_ONLY_SCRIPTS)}\n"
            f"  found:    {sorted(extra_names)}\n"
            "Update EXPECTED_NATIVE_ONLY_SCRIPTS at the top of this file once you've "
            "confirmed by hand what changed and why."
        )
    print(f"native-only scripts confirmed: {sorted(extra_names)}")

    trigger_groups = get_native_trigger_groups(native_source)
    key_groups = get_native_key_groups(native_source)
    print(f"native trigger groups found: {[find_child(g, 'name').text for g in trigger_groups]}")
    print(f"native key groups found: {[find_child(g, 'name').text for g in key_groups]}")

    # ---- Assemble ScriptPackage --------------------------------------
    # A dofile() entry whose target file no longer exists is a stale
    # pointer in DSL2's own Script Editor (found 2026-07-19: "MyDsl_
    # Alterform" -- really MyDSL_ChatWrapper.lua's dofile -- points at a
    # file that was deleted when it got merged into MyDSL_Chat.lua, but
    # the old Script entry was never removed). Skip it loudly rather than
    # crash the whole build over one leftover entry -- but this should get
    # cleaned up by hand in DSL2's Script Editor, not permanently
    # tolerated here.
    script_blocks = []
    for name, path in dofiles:
        if not os.path.isfile(path):
            print(
                f"WARNING: dofile target missing on disk, skipping: {name} -> {path} "
                "-- this is a stale Script Editor entry (deleted/renamed file); "
                "clean it up in DSL2's Script Editor."
            )
            continue
        with open(path, "r", encoding="utf-8") as f:
            script_blocks.append(build_script_element_xml(name, f.read()))
    for name in sorted(extra_names):
        script_blocks.append(build_script_element_xml(name, native_only[name]))

    # No outer "MyDSL_Full"-named ScriptGroup wrapper -- see
    # docs/MUDLET_PACKAGING_REFERENCE.md. Mudlet's own importer already
    # wraps top-level package content in a synthetic folder named after the
    # package on every install; wrapping it again here in a group of the
    # SAME name is exactly what stacked a second "MyDSL_Full" layer on
    # every single install. Bare top-level <Script> elements are a real,
    # importer-accepted shape (confirmed in XMLimport::readScriptPackage()).
    script_package_xml = (
        "  <ScriptPackage>\n"
        + "".join(script_blocks) +
        "  </ScriptPackage>\n"
    )

    # ---- Assemble TriggerPackage --------------------------------------
    # Same fix as ScriptPackage above -- no outer "MyDSL_Full"-named
    # TriggerGroup wrapper. The real native trigger groups (DslColors v1.0
    # Triggers, MyDSL_GameplayTriggers) go in directly as top-level content.
    trigger_inner = "".join(elem_to_xml(g) for g in trigger_groups)
    trigger_package_xml = (
        "  <TriggerPackage>\n"
        + trigger_inner +
        "  </TriggerPackage>\n"
    )

    # ---- Assemble KeyPackage --------------------------------------
    # Same fix again -- no outer "MyDSL_Full"-named KeyGroup wrapper. The
    # real native key groups (Movement, Open Doors, ...) go in directly.
    key_inner = "".join(elem_to_xml(g) for g in key_groups)
    key_package_xml = "  <KeyPackage>\n" + key_inner + "  </KeyPackage>\n"

    full_xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<MudletPackage version=\"1.001\">\n"
        + script_package_xml
        + trigger_package_xml
        + key_package_xml
        + "</MudletPackage>\n"
    )

    tmp_xml_path = os.path.join(REPO_ROOT, "MyDSL_Full.xml")
    with open(tmp_xml_path, "w", encoding="utf-8") as f:
        f.write(full_xml)

    # Verify well-formed before zipping.
    ET.parse(tmp_xml_path)
    print("XML well-formed: OK")

    # config.lua manifest. Originally just `mpackage` (Host::installPackage()
    # falls back to sanitizePackageName(fileName) when it's absent, which
    # already resolves to "MyDSL_Full" for us) -- extended 2026-08-29 with
    # the full metadata field set, confirmed directly against Mudlet's own
    # real source (Mudlet-5.0.0 tag: Host::getPackageConfig(),
    # dlgPackageManager.cpp, and dlgPackageExporter.cpp -- the code behind
    # Mudlet's own official "Export as package" dialog, the strongest
    # confirmation available for what a well-formed config.lua should
    # contain) while building DSL_Mapper_Addon.mpackage -- see
    # docs/MUDLET_PACKAGING_REFERENCE.md's "Package metadata (config.lua)"
    # section for the full writeup, this is the same field set applied here.
    # `key = [[value]]` (Lua long-string, not `"..."`) matches
    # dlgPackageExporter.cpp's own appendToDetails() exactly.
    package_icon = os.path.join(REPO_ROOT, "DSL_Mapper_Addon_Icon.png")
    package_icon_name = os.path.basename(package_icon)
    package_created = datetime.date.today().isoformat()
    package_description = (
        "The full MyDSL suite: a modular passive-observation UI for "
        "Dark and Shattered Lands (DSL). Combat tracking, group/target "
        "windows, chat, mapper, creature/item reference, character "
        "assist, and more -- all Mudlet native content plus this "
        "project's own Lua modules, bundled into one package.\n\n"
        "Part of the MyDSL project."
    )

    def lua_field(key, value):
        return f"{key} = [[{value}]]\n" if value else ""

    config_lua = (
        lua_field("mpackage", "MyDSL_Full")
        + lua_field("author", "Siathes")
        + lua_field("icon", package_icon_name)
        + lua_field("title", "MyDSL")
        + lua_field("description", package_description)
        + lua_field("version", "1.0.0")
        + lua_field("helpURL", "https://github.com/Siathes/MyDSL")
        + lua_field("created", package_created)
    )

    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(tmp_xml_path, arcname="MyDSL_Full.xml")
        zf.writestr("config.lua", config_lua)
        if os.path.exists(package_icon):
            zf.write(package_icon, arcname=f".mudlet/Icon/{package_icon_name}")
        else:
            print(f"WARNING: {package_icon} not found -- package built with no icon")
    os.remove(tmp_xml_path)

    print(f"Wrote {args.out}")
    print(f"  scripts:  {len(script_blocks)}")


if __name__ == "__main__":
    main()

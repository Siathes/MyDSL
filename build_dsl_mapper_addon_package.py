#!/usr/bin/env python3
"""Build DSL_Mapper_Addon.mpackage from DSL_Mapper_Addon.xml.

Much simpler than build_mydsl_package.py: DSL_Mapper_Addon.xml is
hand-authored source, not spliced from a live native profile snapshot,
so there's no flattening/unwrap step needed -- it already matches the
confirmed-safe format from docs/MUDLET_PACKAGING_REFERENCE.md (a single
top-level <Script>, no redundant package-named wrapper group, so
Mudlet's own synthetic per-type folder is the only nesting that ever
exists, however many times this gets rebuilt).

Read docs/MUDLET_PACKAGING_REFERENCE.md before every run of this script,
same as build_mydsl_package.py -- see that doc for why.

config.lua fields and the .mudlet/Icon/<file> bundling convention below
are confirmed directly against Mudlet's own real source (2026-08-29,
Mudlet-5.0.0 tag): Host::getPackageConfig() (src/Host.cpp) captures
every string global set in config.lua into mPackageInfo, not just
`mpackage`; dlgPackageManager.cpp reads `title`/`icon`/`description`/
`helpURL`/`version` from it to populate the Package Manager UI;
dlgPackageExporter.cpp -- Mudlet's OWN official package-export dialog --
confirms the full canonical field set (mpackage, author, icon, title,
description, version, helpURL, dependencies, created) and the exact
`key = [[value]]` Lua long-string format used here, plus the
`.mudlet/Icon/<filename>` bundling path (relative to the zip root).

Usage: python3 build_dsl_mapper_addon_package.py [--out PATH]
"""
import argparse
import datetime
import os
import xml.etree.ElementTree as ET
import zipfile

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCE_XML = os.path.join(REPO_ROOT, "DSL_Mapper_Addon.xml")
ICON_FILE = os.path.join(REPO_ROOT, "DSL_Mapper_Addon_Icon.png")

DESCRIPTION = """Adds Dark and Shattered Lands (DSL)-specific mapping on top of \
Mudlet's own built-in Generic Mapper: door-verb parsing, terrain/sector \
coloring, movement-cost tracking, GMCP room data, and a **Safe Delete** \
option on the map's right-click menu.

Does **not** bundle a copy of Generic Mapper -- it expects your own \
Mudlet install to already have it (Mudlet ships it built in for most \
games; open the Mapper once if you've never used it in this profile).

Part of the MyDSL project. Free for any noncommercial use (PolyForm \
Noncommercial 1.0.0) -- see the repo's LICENSE.md."""


def lua_field(key, value):
    if not value:
        return ""
    return f"{key} = [[{value}]]\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO_ROOT, "DSL_Mapper_Addon.mpackage"))
    ap.add_argument("--version", default="0.2.7", help="Should track map.dsl.version in DSL_Mapper_Addon.xml")
    args = ap.parse_args()

    if not os.path.exists(SOURCE_XML):
        raise SystemExit(f"ERROR: {SOURCE_XML} not found")
    if not os.path.exists(ICON_FILE):
        raise SystemExit(f"ERROR: {ICON_FILE} not found")

    # Verify well-formed before zipping -- same check build_mydsl_package.py does.
    ET.parse(SOURCE_XML)
    print("XML well-formed: OK")

    icon_filename = os.path.basename(ICON_FILE)
    created = datetime.date.today().isoformat()

    config_lua = (
        lua_field("mpackage", "DSL_Mapper_Addon")
        + lua_field("author", "Siathes")
        + lua_field("icon", icon_filename)
        + lua_field("title", "DSL Mapper Addon")
        + lua_field("description", DESCRIPTION)
        + lua_field("version", args.version)
        + lua_field("helpURL", "https://github.com/Siathes/MyDSL")
        + lua_field("dependencies", "generic_mapper")
        + lua_field("created", created)
    )

    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(SOURCE_XML, arcname="DSL_Mapper_Addon.xml")
        zf.writestr("config.lua", config_lua)
        zf.write(ICON_FILE, arcname=f".mudlet/Icon/{icon_filename}")

    print(f"Wrote {args.out}")
    print(f"  version: {args.version}")
    print(f"  icon:    {icon_filename}")


if __name__ == "__main__":
    main()

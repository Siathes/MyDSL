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

Usage: python3 build_dsl_mapper_addon_package.py [--out PATH]
"""
import argparse
import os
import xml.etree.ElementTree as ET
import zipfile

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCE_XML = os.path.join(REPO_ROOT, "DSL_Mapper_Addon.xml")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO_ROOT, "DSL_Mapper_Addon.mpackage"))
    args = ap.parse_args()

    if not os.path.exists(SOURCE_XML):
        raise SystemExit(f"ERROR: {SOURCE_XML} not found")

    # Verify well-formed before zipping -- same check build_mydsl_package.py does.
    ET.parse(SOURCE_XML)
    print("XML well-formed: OK")

    # config.lua manifest -- per docs/MUDLET_PACKAGING_REFERENCE.md,
    # confirmed against Host::getPackageConfig(): a sandboxed Lua chunk
    # exposing one global, `mpackage`, overriding the name that would
    # otherwise come from the archive's own filename.
    config_lua = 'mpackage = "DSL_Mapper_Addon"\n'

    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(SOURCE_XML, arcname="DSL_Mapper_Addon.xml")
        zf.writestr("config.lua", config_lua)

    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()

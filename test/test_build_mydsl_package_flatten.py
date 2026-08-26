#!/usr/bin/env python3
"""
Real bug found live 2026-08-26 (see docs/MUDLET_PACKAGING_REFERENCE.md):
Steven's live MyDSL profile's KeyGroup ended up nested many levels deep in
"MyDSL_Full" wrapper copies -- confirmed directly against a screenshot of
Mudlet's own Key editor, then measured precisely against the live profile's
current/autosave.xml. First diagnosed as a reinstall-without-uninstall
accumulation; the REAL root cause (confirmed directly against Mudlet's own
XMLimport.cpp source the same day, after the first fix alone didn't stop a
fresh nesting from appearing) is that Mudlet's own importer ALWAYS wraps a
package's top-level content in a synthetic folder named after the package
on every single install -- so a package whose OWN exported XML also wraps
its content in a group of that SAME name doubles up on every install,
reinstalled-cleanly-or-not.

Tests both fixes against synthetic fixtures (not the live profile itself,
which Steven may clean up by hand -- a test that depended on the corrupted
state still existing would break the moment it's fixed):
  - flatten_self_nested_wrapper() -- the real corrupted shape, an
    uncorrupted single wrapper (no-op), a wrapper with genuinely multiple
    real children (no-op).
  - unwrap_own_package_name_layer() -- strips the outer same-named wrapper
    down to its real content children, the actual packaging-format fix.

Run: python3 test/test_build_mydsl_package_flatten.py
"""

import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_mydsl_package as b

failures = 0


def check(name, cond):
    global failures
    if cond:
        print("PASS: " + name)
    else:
        print("FAIL: " + name)
        failures += 1


def make_key_group(name, package_name, children_xml=""):
    return (
        f'<KeyGroup isActive="yes" isFolder="yes">'
        f'<name>{name}</name><packageName>{package_name}</packageName>'
        f'<script></script><command></command><keyCode>0</keyCode>'
        f'<keyModifier>0</keyModifier>{children_xml}</KeyGroup>'
    )


def make_leaf_key(name):
    return f'<Key isActive="yes" isFolder="no"><name>{name}</name><packageName>MyDSL_Full</packageName></Key>'


# ---- Case 1: the real corrupted shape -- N levels of self-nesting -------

real_content = make_key_group("Movement", "MyDSL_Full", make_leaf_key("move north"))
corrupted = real_content
for _ in range(15):
    corrupted = make_key_group("MyDSL_Full", "MyDSL_Full", corrupted)
corrupted = make_key_group("MyDSL_Full", "MyDSL_Full", corrupted)  # 16 total wrapper levels

elem = ET.fromstring(corrupted)
flattened = b.flatten_self_nested_wrapper(elem, "KeyGroup", "MyDSL_Full")
content_children = [c for c in flattened if c.tag == "KeyGroup"]
check("flattens 16 levels of self-nesting down to the real content",
      len(content_children) == 1 and b.find_child(content_children[0], "name").text == "Movement")
check("the flattened result is still a real MyDSL_Full KeyGroup (not the content itself)",
      b.find_child(flattened, "name").text == "MyDSL_Full")

# ---- Case 2: an already-clean single wrapper -- must be a no-op ----------

clean = make_key_group("MyDSL_Full", "MyDSL_Full", make_key_group("Movement", "MyDSL_Full", make_leaf_key("move north")))
elem2 = ET.fromstring(clean)
flattened2 = b.flatten_self_nested_wrapper(elem2, "KeyGroup", "MyDSL_Full")
check("an already-clean single wrapper is returned unchanged (identity, not just equal)",
      flattened2 is elem2)

# ---- Case 3: multiple real top-level groups -- must NOT be flattened away -

multi = make_key_group(
    "MyDSL_Full", "MyDSL_Full",
    make_key_group("Movement", "MyDSL_Full", make_leaf_key("move north"))
    + make_key_group("Open Doors", "MyDSL_Full", make_leaf_key("open north"))
)
elem3 = ET.fromstring(multi)
flattened3 = b.flatten_self_nested_wrapper(elem3, "KeyGroup", "MyDSL_Full")
check("a wrapper with genuinely multiple real children is left alone",
      flattened3 is elem3)
content_children3 = [c for c in flattened3 if c.tag == "KeyGroup"]
check("both real children survive untouched",
      len(content_children3) == 2)

# ---- unwrap_own_package_name_layer(): the actual packaging-format fix ----

wrapper_with_one_real_child = make_key_group(
    "MyDSL_Full", "MyDSL_Full",
    make_key_group("Movement", "MyDSL_Full", make_leaf_key("move north"))
)
elem4 = ET.fromstring(wrapper_with_one_real_child)
unwrapped = b.unwrap_own_package_name_layer(elem4, "KeyGroup", "Key", "MyDSL_Full")
check("unwraps a single-real-child wrapper down to that child directly",
      len(unwrapped) == 1 and b.find_child(unwrapped[0], "name").text == "Movement")

elem5 = ET.fromstring(multi)
unwrapped5 = b.unwrap_own_package_name_layer(elem5, "KeyGroup", "Key", "MyDSL_Full")
check("unwraps a multi-real-child wrapper down to all its children, in order",
      [b.find_child(c, "name").text for c in unwrapped5] == ["Movement", "Open Doors"])

try:
    b.unwrap_own_package_name_layer(elem5, "KeyGroup", "Key", "SomeOtherName")
    check("raises if the wrapper's own name doesn't match what was asked for", False)
except SystemExit:
    check("raises if the wrapper's own name doesn't match what was asked for", True)

empty_wrapper = ET.fromstring(make_key_group("MyDSL_Full", "MyDSL_Full"))
try:
    b.unwrap_own_package_name_layer(empty_wrapper, "KeyGroup", "Key", "MyDSL_Full")
    check("raises rather than silently emitting an empty package for a childless wrapper", False)
except SystemExit:
    check("raises rather than silently emitting an empty package for a childless wrapper", True)

if failures == 0:
    print("ALL PASS")
    sys.exit(0)
else:
    print(f"{failures} FAILURE(S)")
    sys.exit(1)

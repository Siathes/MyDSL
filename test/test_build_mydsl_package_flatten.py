#!/usr/bin/env python3
"""
Real bug found live 2026-08-26 (see docs/MUDLET_PACKAGING_REFERENCE.md):
repeated MyDSL_Full.mpackage reinstalls without uninstalling the old copy
first left the live MyDSL profile's KeyGroup 16 levels deep in nested
"MyDSL_Full" wrapper copies -- confirmed directly against a screenshot of
Mudlet's own Key editor, then measured precisely (max depth 16) against
the live profile's current/autosave.xml.

Tests flatten_self_nested_wrapper() against synthetic fixtures (not the
live profile itself, which Steven may clean up by hand -- a test that
depended on the corrupted state still existing would break the moment
it's fixed) covering: the real corrupted shape, an uncorrupted single
wrapper (must be a no-op), and a wrapper with genuinely multiple real
children (must also be a no-op, since "more than one real child" is not
the corruption pattern).

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

if failures == 0:
    print("ALL PASS")
    sys.exit(0)
else:
    print(f"{failures} FAILURE(S)")
    sys.exit(1)

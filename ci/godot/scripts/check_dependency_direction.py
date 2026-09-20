#!/usr/bin/env python3
"""dip-direction, per AI_First_Development_Kit/principles/solid-mechanical.md (D).

Rule (per specs/05-presentation-and-hud.md): presentation/ may depend on sim/, never
the reverse, and sim/ (the high-level domain layer) must not depend on the engine's
scene-tree/rendering infrastructure directly.

Rewritten from the original check_dependency_direction.sh (preload/load/extends-path
scan only) to also catch a second violation shape spotted while reviewing
https://github.com/SSidey/Sweepminer's check_dip_direction.py: a sim/ file directly
`extends`-ing an engine Node-derived type. sim/ classes should only extend
RefCounted/Resource/Object, or another sim/-defined class - never Node/Node2D/Control/
etc., since that would make domain logic depend on the scene tree to even instantiate.

Honest limits (see ci/godot/README.md): textual scan only, no call-graph. Cannot see an
indirect dependency routed through a third file, doesn't understand dead/conditional
code paths, and the "is this base type a Node subtype" check is a fixed list of Godot's
own common Node-family base classes, not a lookup against the engine's actual class
hierarchy - an obscure Node-derived type not on the list would be missed.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
SIM_DIR = REPO_ROOT / "sim"

PRESENTATION_DEP_RE = re.compile(
    r'(preload|load)\(\s*"res://presentation/|extends\s+"res://presentation/'
)
EXTENDS_RE = re.compile(r"^extends\s+(\w+)")
CLASS_NAME_RE = re.compile(r"^class_name\s+(\w+)")

DOMAIN_SAFE_BASE_TYPES = {"RefCounted", "Resource", "Object"}
KNOWN_NODE_FAMILY_TYPES = {
    "Node", "Node2D", "Node3D", "CanvasItem", "Control", "Spatial",
    "Sprite2D", "Label", "Button", "Timer", "AnimationPlayer", "Area2D",
    "RigidBody2D", "CharacterBody2D", "StaticBody2D", "Camera2D", "Camera3D",
}


def gather_sim_class_names():
    names = set()
    if not SIM_DIR.exists():
        return names
    for gd_file in SIM_DIR.rglob("*.gd"):
        for line in gd_file.read_text(encoding="utf-8").splitlines():
            match = CLASS_NAME_RE.match(line)
            if match:
                names.add(match.group(1))
    return names


def main() -> int:
    if not SIM_DIR.exists():
        print("check_dependency_direction: no sim/ directory yet, nothing to check.")
        return 0

    allowed_base_types = DOMAIN_SAFE_BASE_TYPES | gather_sim_class_names()
    violations = []

    for gd_file in SIM_DIR.rglob("*.gd"):
        rel_path = gd_file.relative_to(REPO_ROOT)
        for line in gd_file.read_text(encoding="utf-8").splitlines():
            if PRESENTATION_DEP_RE.search(line):
                violations.append(f"{rel_path}: depends on presentation/ - {line.strip()}")

            extends_match = EXTENDS_RE.match(line)
            if extends_match:
                base_type = extends_match.group(1)
                if base_type in KNOWN_NODE_FAMILY_TYPES and base_type not in allowed_base_types:
                    violations.append(
                        f"{rel_path}: extends '{base_type}' - sim/ should only extend "
                        f"RefCounted/Resource/Object or another sim/ class, not an "
                        f"engine Node type"
                    )

    if violations:
        print("check_dependency_direction: DIP violations found:")
        for violation in violations:
            print(f"  {violation}")
        return 1

    print("check_dependency_direction: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

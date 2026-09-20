#!/usr/bin/env python3
"""naming-grep-discoverable, per
AI_First_Development_Kit/principles/ai-first-organisation.md (Principle 3) and
AI_First_Development_Kit/config/thresholds.yaml (ai_first_organisation.naming.*).

Flags declarations of the kit's example generic names (process, handle, util, helper,
common, base, manager, data) that are not underscore-prefixed engine virtuals (_process,
_ready, ... are Godot callbacks, not ours to rename) and that appear at or above the
configured grep-hit threshold across the repo.

Heuristic limits (see ci/godot/README.md): the kit's single-class-scope exception
("a method literally named `process` inside a class called `PaymentProcessor`, never
referenced by that short name outside the class" is acceptable) requires knowing
whether external callers use the short name specifically - this script can't
distinguish `some_processor.process()` (the allowed case) from a genuine cross-module
`process()` free function by grep alone. It flags every hit at/above threshold and
leaves the scoped-exception judgment to manual review, per the qualitative half of this
rubric rather than pretending the mechanical half is a full proof.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
THRESHOLDS_FILE = REPO_ROOT / "AI_First_Development_Kit" / "config" / "thresholds.yaml"
EXCLUDED_DIRS = {"addons", "AI_First_Development_Kit"}
BANNED_NAMES = ["process", "handle", "util", "helper", "common", "base", "manager", "data"]


def read_threshold(key: str, default: int) -> int:
    text = THRESHOLDS_FILE.read_text(encoding="utf-8")
    match = re.search(rf"^\s*{re.escape(key)}:\s*(\d+)\s*$", text, re.MULTILINE)
    return int(match.group(1)) if match else default


def iter_gd_files():
    for path in REPO_ROOT.rglob("*.gd"):
        relative = path.relative_to(REPO_ROOT)
        if relative.parts and relative.parts[0] in EXCLUDED_DIRS:
            continue
        yield path


def declared_generic_names(path: Path) -> set:
    found = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^(func|class_name|const|var)\s+(\w+)", line.strip())
        if match and match.group(2) in BANNED_NAMES:
            found.add(match.group(2))
    return found


def grep_hit_count(name: str) -> int:
    result = subprocess.run(
        ["git", "grep", "-l", "-w", name, "--", "*.gd"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    files = [f for f in result.stdout.splitlines() if not f.startswith("addons/")]
    return len(files)


def main() -> int:
    max_grep_hits = read_threshold("max_grep_hits", 10)

    names_declared = set()
    for path in iter_gd_files():
        names_declared |= declared_generic_names(path)

    violations = []
    for name in sorted(names_declared):
        hits = grep_hit_count(name)
        if hits >= max_grep_hits:
            violations.append(f"'{name}' declared and referenced across {hits} files (max {max_grep_hits - 1})")

    if violations:
        print("check_generic_naming: naming-grep-discoverable violations found:")
        for violation in violations:
            print(f"  {violation}")
        print("(Scoped, single-class exception per ai-first-organisation.md - review before treating as final.)")
        return 1

    print("check_generic_naming: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

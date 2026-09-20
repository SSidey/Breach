#!/usr/bin/env python3
"""no-cross-cutting-helper-violation, per
AI_First_Development_Kit/principles/ai-first-organisation.md (Principle 4).

Ported from https://github.com/SSidey/Sweepminer's dev_kit/ci/godot/scripts/
check_helper_promotion.py (same kit, same gap).

Catches the concrete failure mode the principle names explicitly: a promoted helper
dumped into a generic catch-all file instead of a precisely named module ("never into a
generic utils.*, helpers.*, or common.* file").

Honest limit: this only catches the catch-all-filename shape of the violation. It
cannot detect a helper that's below the promotion threshold (used by <3 callers) but
already incorrectly split into its own file, nor a genuinely shared helper duplicated
past the threshold instead of promoted - both need call-graph tooling this project
doesn't have.
"""
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
EXCLUDED_DIRS = {"addons", "AI_First_Development_Kit"}
FORBIDDEN_STEMS = {"utils", "util", "helpers", "helper", "common", "base", "manager", "data"}


def iter_gd_files():
    for path in REPO_ROOT.rglob("*.gd"):
        relative = path.relative_to(REPO_ROOT)
        if relative.parts and relative.parts[0] in EXCLUDED_DIRS:
            continue
        yield path


def main() -> int:
    violations = [
        str(path.relative_to(REPO_ROOT))
        for path in iter_gd_files()
        if path.stem.lower() in FORBIDDEN_STEMS
    ]

    if violations:
        print("check_helper_promotion: generic catch-all filename(s) found (rename to what the module actually does):")
        for violation in violations:
            print(f"  {violation}")
        return 1

    print("check_helper_promotion: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

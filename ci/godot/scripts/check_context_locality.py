#!/usr/bin/env python3
"""context-locality, per AI_First_Development_Kit/principles/ai-first-organisation.md
(Principle 2) and config/thresholds.yaml (ai_first_organisation.context_locality.max_files).

Ported per Decision 12 in the design spec, added after a direct self-audit found this
threshold was never being checked against any change - the check exists so a reviewer
has the number in front of them, not so a raw count can fail a build.

Deliberately informational, not a hard gate: the principle's own text calls this
"necessarily a judgement call" about co-location of a feature's definition, usage, and
supporting logic - not file count in general. A schema field (content/) plus the sim/
logic that consumes it plus both their tests is exactly one feature, cohesively
delivered, even though it routinely exceeds the configured default of 2 files. Decision
12 covers that specific pattern; this script surfaces the count for anything else so a
reviewer can judge whether a given diff is that same pattern or genuine scatter.

Counts touched (added + modified) source files under sim/, presentation/, content/,
core/ only - tests/ and specs/*.md are expected companions to a feature, not scatter,
and are excluded so they don't inflate the count past what a reviewer actually needs to
open to understand the change.

Only meaningful with a real base ref (a PR's merge-base), same reasoning as
check_ocp_shotgun_surgery.py - CI only, not the working-tree-only pre-commit gate.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
THRESHOLDS_FILE = REPO_ROOT / "AI_First_Development_Kit" / "config" / "thresholds.yaml"
SOURCE_PREFIXES = ("sim/", "presentation/", "content/", "core/")


def read_threshold(key: str, default: int) -> int:
    text = THRESHOLDS_FILE.read_text(encoding="utf-8")
    match = re.search(rf"^\s*{re.escape(key)}:\s*(\d+)\s*$", text, re.MULTILINE)
    return int(match.group(1)) if match else default


def touched_source_files(base_ref: str):
    merge_base = subprocess.run(
        ["git", "merge-base", base_ref, "HEAD"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    diff = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AM", merge_base, "HEAD", "--", "*.gd"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.splitlines()

    return [path for path in diff if path.startswith(SOURCE_PREFIXES)]


def main() -> int:
    base_ref = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    max_files = read_threshold("max_files", 2)

    try:
        touched = touched_source_files(base_ref)
    except subprocess.CalledProcessError as error:
        print(f"check_context_locality: could not diff against '{base_ref}': {error}")
        return 0

    if len(touched) > max_files:
        print(
            f"check_context_locality: {len(touched)} source files touched "
            f"(default budget: {max_files}). Informational, not a failure - "
            f"per Decision 12, a schema-plus-consumer change following that pattern "
            f"doesn't need a fresh Decision. If this diff is genuinely scattered "
            f"across unrelated parts of the codebase instead, that's worth a second "
            f"look:"
        )
        for path in touched:
            print(f"  {path}")
        return 0

    print(f"check_context_locality: {len(touched)} source files touched, within budget.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

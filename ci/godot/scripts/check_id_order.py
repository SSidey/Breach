#!/usr/bin/env python3
"""order-independent-simulation, per the Breach design ledger (Decision 97) and
AI_First_Development_Kit/principles/rules-over-cases.md (Principle 2).

An identifier names a thing; it never ranks it. Ids are handed out in spawn order, so a
simulation that compares, sorts or does arithmetic on them hands an edge to whichever
side was created first or last. Flags, in simulation code (`sim/`):
- an id compared with < or > (`a.id < b.id`);
- arithmetic on an id (`unit.id % 4096`);
- an id inside an array literal used as a key (`[distance, other.id]`), unless it is
  only salting a seeded random draw (`hash([...])`, `BattleRolls.`);
- sorting a list of ids (`ids.sort()`).
Using an id to name something - a lookup (`loose[unit.id]`), an equality test, a target,
an event's payload - is fine.

A line may be allowed with a trailing `# id-order-ok: <reason>` comment (or the same
comment on the line above) when the order provably changes nothing but a log; the
reason is required and reviewed.

Heuristic limits: a tie broken by list order (`if key < best_key` keeping the first of
equals, where the list is in spawn order) is the same fault in another form and cannot
be seen by grep. The design-check skill's swapped-spawn-order trial is the backstop.

Usage: check_id_order.py [files...]  (no files: every .gd under sim/)
"""
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
ALLOW = re.compile(r"#\s*id-order-ok:\s*\S")
COMPARE = re.compile(r"(\.id\s*[<>])|([<>]=?\s*[\w\[\]\.]*\.id\b)")
ARITHMETIC = re.compile(r"\.id\s*[%*/+-](?!=)|[%*/+-]\s*[\w\[\]\.]*\.id\b")
SORTED_IDS = re.compile(r"\bids\.sort(_custom)?\(")
SALT = re.compile(r"\bhash\(|BattleRolls\.")


def code_of(line: str) -> str:
    """The line without its comment (strings are not parsed: ids don't appear in them)."""
    return line.split("#", 1)[0]


def literal_key(code: str) -> bool:
    """True if `.id]` closes an array literal rather than an index."""
    for match in re.finditer(r"\.id\s*\]", code):
        depth = 0
        for index in range(match.start(), -1, -1):
            char = code[index]
            if char == "]":
                depth += 1
            elif char == "[":
                if depth == 0:
                    before = code[:index].rstrip()
                    if not before or not (before[-1].isalnum() or before[-1] in "_])"):
                        return True
                    break
                depth -= 1
    return False


def violations_in(text: str) -> list:
    found = []
    lines = text.splitlines()
    for number, line in enumerate(lines, start=1):
        if ALLOW.search(line) or (number > 1 and ALLOW.search(lines[number - 2])):
            continue
        code = code_of(line)
        if ".id" not in code and "ids" not in code:
            continue
        if COMPARE.search(code):
            found.append((number, "id compared by order"))
        elif ARITHMETIC.search(code):
            found.append((number, "arithmetic on an id"))
        elif SORTED_IDS.search(code):
            found.append((number, "ids sorted"))
        elif literal_key(code) and not SALT.search(code):
            found.append((number, "id in a key"))
    return found


def files_to_check(arguments: list) -> list:
    if arguments:
        return [REPO_ROOT / a for a in arguments if a.startswith("sim/") and a.endswith(".gd")]
    return sorted((REPO_ROOT / "sim").rglob("*.gd"))


def main(arguments: list) -> int:
    report = []
    for path in files_to_check(arguments):
        if not path.exists():
            continue
        for number, why in violations_in(path.read_text(encoding="utf-8")):
            report.append(f"  {path.relative_to(REPO_ROOT)}:{number}: {why}")
    if report:
        print("check_id_order: simulation ranks things by id (Decision 97):")
        print("\n".join(report))
        print("Rank by what the units are and where they stand, then a seeded draw.")
        return 1
    print("check_id_order: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

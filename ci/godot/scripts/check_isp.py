#!/usr/bin/env python3
"""isp-method-count / isp-stub-detection, per
AI_First_Development_Kit/principles/solid-mechanical.md (I) and
AI_First_Development_Kit/config/thresholds.yaml (solid_mechanical.isp.max_interface_methods).

Ported from https://github.com/SSidey/Sweepminer's dev_kit/ci/godot/scripts/check_isp.py
(same kit, same gap) and adapted to this repo's directory layout.

Honest limits (see ci/godot/README.md):
- Method-count is applied to every .gd file (GDScript's one-class-per-file convention
  makes each file a stand-in for "a class"), not only files that are genuinely acting as
  an interface/contract for multiple implementers - GDScript has no formal interface
  keyword to detect that distinction mechanically. A legitimately large concrete class
  (not forcing anything on an implementer) can trip this; treat a hit as a prompt to
  check which case it is, not an automatic violation.
- Stub-detection flags *any* function whose only statement is `pass`, a bare
  `push_error(...)`, or `assert(false, ...)` - not only true overrides of a base method
  with real behaviour, since no inheritance graph is built. A legitimate no-op virtual
  hook (e.g. an optional lifecycle callback) will false-positive here.
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

FUNC_RE = re.compile(r"^(\s*)(?:static\s+)?func\s+(\w+)\s*\([^)]*\)\s*(?:->\s*\S+)?\s*:\s*(.*)$")
STUB_BODY_RE = re.compile(r"^\s*(pass|push_error\(.*\)|assert\(\s*false\b.*\))\s*$")


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


def extract_functions(lines: list) -> list:
    """Return (function_name, body_lines) for each top-level function in the file."""
    functions = []
    current_name = None
    current_indent = None
    current_body = []
    for line in lines:
        match = FUNC_RE.match(line)
        if match:
            if current_name is not None:
                functions.append((current_name, current_body))
            inline_body = match.group(3).strip()
            if inline_body:
                functions.append((match.group(2), [inline_body]))
                current_name = None
                current_body = []
                continue
            current_indent = len(match.group(1))
            current_name = match.group(2)
            current_body = []
            continue
        if current_name is not None:
            is_body_line = line.strip() == "" or (
                len(line) - len(line.lstrip(" \t")) > current_indent
            )
            if is_body_line:
                if line.strip():
                    current_body.append(line.strip())
            else:
                functions.append((current_name, current_body))
                current_name = None
                current_body = []
    if current_name is not None:
        functions.append((current_name, current_body))
    return functions


def is_stub(body: list) -> bool:
    non_comment_lines = [line for line in body if not line.startswith("#")]
    if len(non_comment_lines) != 1:
        return False
    return bool(STUB_BODY_RE.match(non_comment_lines[0]))


def main() -> int:
    max_methods = read_threshold("max_interface_methods", 7)

    violations = []
    for path in iter_gd_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        functions = extract_functions(lines)
        rel_path = path.relative_to(REPO_ROOT)

        if len(functions) > max_methods:
            violations.append(
                f"{rel_path}: {len(functions)} methods (max {max_methods}) [isp-method-count]"
            )

        for name, body in functions:
            if is_stub(body):
                violations.append(
                    f"{rel_path}: {name}() body is a stub ({body[0]!r}) [isp-stub-detection]"
                )

    if violations:
        print("check_isp: violations found:")
        for violation in violations:
            print(f"  {violation}")
        return 1

    print("check_isp: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

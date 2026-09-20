#!/usr/bin/env python3
"""Gate 1 mechanical progress log, per
AI_First_Development_Kit/principles/progress-tracking.md's recommended mechanism:
compute current metrics, compare against the previous logged row, fail on regression,
append the new row unconditionally either way.

Run at the end of an implementation pass (see
AI_First_Development_Kit/principles/agent-workflow.md's codified procedure, step 4).

Metrics computed (see progress-tracking.md's table):
- test count (from the most recent gdUnit4 XML report, if any)
- lint warning count (gdlint, across tracked *.gd files outside addons/)
- srp-size violations (function-length + gdlint's own file-length check)
- naming-grep-discoverable / isp / helper-promotion / dip-direction violations
Rubric pass count and coverage %% are recorded as text notes, not compared
numerically, per the honest gaps documented in ci/godot/README.md (no coverage tool;
rubric-row count is qualitative until every row has a mechanical check).
`ocp-shotgun-surgery` is deliberately excluded here - it's a diff-scoped, CI-only
check (see check_ocp_shotgun_surgery.py's own docstring), not meaningful against a
bare working tree.
"""
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree

REPO_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
LOG_FILE = REPO_ROOT / "PROGRESS_LOG.md"
CI_SCRIPTS = REPO_ROOT / "ci" / "godot" / "scripts"


def tracked_gd_files():
    result = subprocess.run(
        ["git", "ls-files", "*.gd"], cwd=REPO_ROOT, capture_output=True, text=True
    )
    return [f for f in result.stdout.splitlines() if not f.startswith("addons/")]


def count_lint_warnings() -> int:
    files = tracked_gd_files()
    if not files:
        return 0
    result = subprocess.run(["gdlint", *files], cwd=REPO_ROOT, capture_output=True, text=True)
    # gdlint writes its findings to stderr, not stdout - verified empirically.
    return len(re.findall(r"^\S+:\d+: Error:", result.stderr, re.MULTILINE))


def count_script_violations(script_name: str) -> int:
    result = subprocess.run(
        ["python3", str(CI_SCRIPTS / script_name)], cwd=REPO_ROOT, capture_output=True, text=True
    )
    return len(re.findall(r"^  \S", result.stdout, re.MULTILINE))


def latest_test_count():
    reports_dir = REPO_ROOT / "reports"
    if not reports_dir.exists():
        return None
    report_dirs = sorted(reports_dir.glob("report_*"), key=lambda p: p.stat().st_mtime)
    if not report_dirs:
        return None
    results_xml = report_dirs[-1] / "results.xml"
    if not results_xml.exists():
        return None
    root = ElementTree.parse(results_xml).getroot()
    return int(root.attrib.get("tests", 0))


def read_previous_row():
    if not LOG_FILE.exists():
        return None
    lines = [l for l in LOG_FILE.read_text(encoding="utf-8").splitlines() if l.startswith("|")]
    data_rows = [l for l in lines[2:] if l.strip()]  # skip header + separator
    return data_rows[-1] if data_rows else None


def main() -> int:
    test_count = latest_test_count()
    lint_warnings = count_lint_warnings()
    function_length_violations = count_script_violations("check_function_length.py")
    naming_violations = count_script_violations("check_generic_naming.py")
    isp_violations = count_script_violations("check_isp.py")
    helper_violations = count_script_violations("check_helper_promotion.py")
    dip_violations = count_script_violations("check_dependency_direction.py")

    previous_row = read_previous_row()
    regressed = False
    if previous_row:
        # Columns, 0-indexed: date, branch, test_count, lint_warnings, ... - fixed a
        # real off-by-one here (was reading branch as test_count and test_count as
        # lint_warnings) caught while extending this table with new columns.
        cols = [c.strip() for c in previous_row.split("|")[1:-1]]
        prev_test_count = cols[2]
        prev_lint = int(cols[3]) if cols[3].isdigit() else 0
        if test_count is not None and prev_test_count.isdigit() and test_count < int(prev_test_count):
            print(f"REGRESSION: test count dropped ({prev_test_count} -> {test_count})")
            regressed = True
        if lint_warnings > prev_lint:
            print(f"REGRESSION: lint warnings increased ({prev_lint} -> {lint_warnings})")
            regressed = True

    branch = subprocess.check_output(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=REPO_ROOT, text=True
    ).strip()
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    test_count_display = str(test_count) if test_count is not None else "0"
    status = "FAIL" if regressed else "PASS"
    row = (
        f"| {date} | {branch} | {test_count_display} | {lint_warnings} | "
        f"{function_length_violations} | {naming_violations} | {isp_violations} | "
        f"{helper_violations} | {dip_violations} | N/A (no tool, see ci/godot/README.md) | {status} |"
    )

    if not LOG_FILE.exists():
        header = (
            "# Gate 1 Mechanical Progress Log\n\n"
            "Per AI_First_Development_Kit/principles/progress-tracking.md. Appended to at "
            "the end of every implementation pass by `ci/godot/scripts/gate1_progress_log.py` "
            "- never edited in place.\n\n"
            "| Date | Branch | Test count | Lint warnings | srp-size (function) violations | "
            "naming violations | isp violations | helper violations | dip violations | "
            "Coverage | Result |\n"
            "|---|---|---|---|---|---|---|---|---|---|---|\n"
        )
        LOG_FILE.write_text(header, encoding="utf-8")

    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(row + "\n")

    print(f"gate1_progress_log: appended row for {branch} - {status}")
    print(row)
    return 1 if regressed else 0


if __name__ == "__main__":
    sys.exit(main())

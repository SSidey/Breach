#!/usr/bin/env bash
# tests-red-then-green (the "green" half) / contract-tests-pass, per
# AI_First_Development_Kit/rubrics/run-baseline.rubrics.md.
#
# Thin wrapper around gdUnit4's own CI runner so both pre-commit and CI call one
# command. Requires GODOT_BIN to point at a Godot 4.7+ executable - see
# ci/godot/README.md's "Running the checks locally" section.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -z "${GODOT_BIN:-}" ]; then
	echo "run_tests: GODOT_BIN is not set. Export it to a Godot 4.7+ executable, e.g.:"
	echo "  export GODOT_BIN=/path/to/Godot_v4.7.2-stable_win64.exe"
	exit 1
fi

if [ ! -d tests ]; then
	echo "run_tests: no tests/ directory yet, nothing to run."
	exit 0
fi

bash addons/gdUnit4/runtest.sh --godot_binary "$GODOT_BIN" -a res://tests -c

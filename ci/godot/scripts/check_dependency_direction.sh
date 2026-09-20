#!/usr/bin/env bash
# DIP direction check (rubric row: dip-direction).
#
# Rule (per specs/05-presentation-and-hud.md): presentation/ may depend on sim/, never
# the reverse. sim/ is the high-level domain layer (simulation rules); presentation/ is
# the low-level, engine/rendering-facing layer. A sim/ file that references anything
# under presentation/ is a hard failure.
#
# Heuristic limits (see ci/godot/README.md): this is a textual scan for `preload(`,
# `load(`, and `extends` references to a res://presentation/... path. It cannot see an
# indirect dependency routed through a third file, and it does not understand
# conditionally-dead code paths - a match is always treated as a real violation.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ ! -d sim ]; then
	echo "check_dependency_direction: no sim/ directory yet, nothing to check."
	exit 0
fi

violations=$(grep -rnE '(preload|load)\(\s*"res://presentation/|extends\s+"res://presentation/' sim/ || true)

if [ -n "$violations" ]; then
	echo "check_dependency_direction: sim/ must not depend on presentation/ (DIP violation):"
	echo "$violations"
	exit 1
fi

echo "check_dependency_direction: OK - no sim/ -> presentation/ references found."

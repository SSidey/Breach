#!/usr/bin/env bash
# commit-message-conforms: Conventional Commits format, per
# AI_First_Development_Kit/templates/commit-message.md.
#
# Runs as a `commit-msg` stage pre-commit hook. $1 is the path pre-commit gives the
# in-progress commit message to.
#
# Heuristic limits (see ci/godot/README.md): the type-vs-diff cross-check below is a
# textual heuristic (added top-level `func`/`class_name`/`signal` lines => "this diff
# adds a capability"), not a semantic understanding of the change. It can be wrong in
# both directions (a `feat` that only adds a private helper function still trips the
# "looks like a fix/refactor/docs/chore that added a capability" warning; a genuine new
# public API added without a new top-level declaration - e.g. a new exported property -
# will not be caught). It fails the commit only on the format check; the type-vs-diff
# mismatch is reported as a warning, not a hard block, until a real diff-semantics tool
# is adopted.
set -euo pipefail

msg_file="$1"
subject="$(head -n1 "$msg_file")"

pattern='^(feat|fix|refactor|test|docs|chore|perf)(\([a-z0-9_-]+\))?!?: .+'

if ! [[ "$subject" =~ $pattern ]]; then
	echo "check_commit_message: subject line does not conform to Conventional Commits:"
	echo "  $subject"
	echo "Expected: <feat|fix|refactor|test|docs|chore|perf>[(scope)][!]: description"
	exit 1
fi

type="$(echo "$subject" | sed -E 's/^([a-z]+).*/\1/')"

if [[ "$type" =~ ^(fix|refactor|docs|chore)$ ]]; then
	added_capability=$(git diff --cached -U0 -- '*.gd' | grep -E '^\+(func |class_name |signal )' || true)
	if [ -n "$added_capability" ]; then
		echo "check_commit_message: WARNING - type '$type' but the diff adds what looks"
		echo "like a new capability (new func/class_name/signal). Confirm this should"
		echo "not be 'feat' instead, per templates/commit-message.md's type-vs-diff table."
	fi
fi

echo "check_commit_message: OK - '$subject'"

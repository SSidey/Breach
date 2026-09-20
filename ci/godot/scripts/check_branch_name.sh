#!/usr/bin/env bash
# branch-name-conforms: Conventional Branch (conventionalbranch.org), per
# AI_First_Development_Kit/principles/agent-workflow.md.
#
# Purpose-driven prefix, lowercase-kebab-case description. Runs as a pre-commit hook
# (stage: pre-commit) so it's checked on every commit, not just once per branch.
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

# main/master (trunk) never gets committed to directly in normal flow, but don't block
# the rare administrative commit (e.g. an initial bootstrap) with this check - the
# agent-workflow rule itself is what prevents trunk commits, not this regex.
if [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ "$branch" = "HEAD" ]; then
	exit 0
fi

pattern='^(feature|fix|bugfix|hotfix|release|chore)/[a-z0-9]+(-[a-z0-9]+)*$'

if ! [[ "$branch" =~ $pattern ]]; then
	echo "check_branch_name: '$branch' does not conform to Conventional Branch."
	echo "Expected: <feature|fix|bugfix|hotfix|release|chore>/lowercase-kebab-case-description"
	exit 1
fi

echo "check_branch_name: OK - '$branch'"

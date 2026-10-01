#!/usr/bin/env python3
"""The base ref that diff-scoped checks (ocp-shotgun-surgery, context-locality) compare
against - Decision 50.

In order of precedence:
1. an explicit argument (``check_ocp_shotgun_surgery.py origin/main``)
2. the ``BASE_REF`` environment variable: CI sets it to the pull request's base branch,
   because a PR checkout is a detached merge commit
3. the branch this one is stacked on: the remote branch, other than this branch's own,
   whose tip is an ancestor of HEAD with the fewest commits between it and HEAD (on a
   tie, ``origin/main``). For a PR stacked on another PR, that is the PR below it, so
   changes the lower PR already justified aren't counted again.
4. ``origin/main``
"""
import os
import subprocess

DEFAULT = "origin/main"


def _git(args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def stacked_base(cwd=None):
    """The closest remote branch HEAD is stacked on, or None if there isn't one."""
    current = _git(["rev-parse", "--abbrev-ref", "HEAD"], cwd).stdout.strip()
    listing = _git(["for-each-ref", "--format=%(refname:short)", "refs/remotes/origin"], cwd)
    best, best_count = None, None
    for ref in listing.stdout.split():
        if ref in ("origin", "origin/HEAD", f"origin/{current}"):
            continue
        if _git(["merge-base", "--is-ancestor", ref, "HEAD"], cwd).returncode != 0:
            continue
        count = int(_git(["rev-list", "--count", f"{ref}..HEAD"], cwd).stdout.strip() or 0)
        closer = best_count is None or count < best_count
        if closer or (count == best_count and ref == DEFAULT):
            best, best_count = ref, count
    return best


def resolve(argv, env=None, cwd=None):
    env = os.environ if env is None else env
    if len(argv) > 1:
        return argv[1]
    if env.get("BASE_REF"):
        return env["BASE_REF"]
    return stacked_base(cwd) or DEFAULT

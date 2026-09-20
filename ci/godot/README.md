# Godot Tooling Layer

Wires the stack-agnostic rubrics in `AI_First_Development_Kit/rubrics/` into actual
GDScript/Godot 4.7 tooling: gdUnit4 for tests, gdtoolkit for lint/format, and a handful
of small local scripts (`ci/godot/scripts/`) for the checks nothing off-the-shelf covers
yet. Every script here was run against a deliberately broken case before being trusted
— see each script's own docstring/comment for exactly what was verified and how.

## Rubric → tool mapping

| Rubric row | Tool | Where |
|---|---|---|
| `tests-red-then-green` | gdUnit4 v6.2.1 (`addons/gdUnit4`) via `ci/godot/scripts/run_tests.sh` | pre-commit (always-run) and CI |
| `lint-clean` | `gdlint` (gdtoolkit) | pre-commit, on changed `*.gd` files (excludes `addons/`) |
| formatting (not a named rubric row, but `commit-message-conforms`/PR review expects it) | `gdformat --check` | pre-commit |
| `srp-size` (file-length half) | gdlint's `max-file-lines` (`.gdlintrc`, set to 300 to match `config/thresholds.yaml`) | pre-commit |
| `srp-size` (function-length half) | `ci/godot/scripts/check_function_length.py` | pre-commit |
| `dip-direction` | `ci/godot/scripts/check_dependency_direction.sh` | pre-commit |
| `naming-grep-discoverable` | `ci/godot/scripts/check_generic_naming.py` | pre-commit |
| `branch-name-conforms` | `ci/godot/scripts/check_branch_name.sh` | pre-commit stage |
| `commit-message-conforms` (format half) | `ci/godot/scripts/check_commit_message.sh` | commit-msg stage |
| `commit-message-conforms` (type-vs-diff half) | same script, heuristic warning only — see Heuristic limits | commit-msg stage |
| `progress-trend` | `ci/godot/scripts/gate1_progress_log.py` | run manually at the end of an implementation pass; see `principles/progress-tracking.md` |

## Heuristic limits (stated plainly, not hidden)

- `check_dependency_direction.sh` — textual scan for `preload(`/`load(`/`extends`
  references from `sim/` into `presentation/`. Cannot see an indirect dependency routed
  through a third file, and does not understand dead/conditional code paths — every
  textual match is treated as a real violation.
- `check_function_length.py` — measures a top-level `func` to the next top-level
  declaration. A function nested inside an inner `class` block is not measured
  separately (known blind spot, not silently wrong — see the script's own docstring).
- `check_generic_naming.py` — flags the kit's example generic names
  (`process`/`handle`/`util`/`helper`/`common`/`base`/`manager`/`data`) at or above the
  grep-hit threshold. Cannot distinguish the kit's allowed "scoped to a single class,
  never called by the short name externally" exception from a genuine violation by grep
  alone — flags the hit count and leaves the scoped-exception judgment to manual review.
- `check_commit_message.sh`'s type-vs-diff cross-check — textual heuristic (new
  top-level `func`/`class_name`/`signal` lines ⇒ "looks like a capability was added").
  Both false positives (a `feat` adding only a private helper) and false negatives (a
  new public API added without a new top-level declaration, e.g. a new exported
  property) are possible. It's a warning, not a hard block, for exactly this reason.

## Procedural, not scripted

- `coverage-overall` / `coverage-changed-lines` — **no working GDScript coverage tool
  was found**, and this was verified empirically, not assumed from documentation. The
  most-starred candidate (`jamie-pate/godot-code-coverage`) was vendored and run against
  a trivial test on this project's actual Godot 4.7.2 install; it crashed with a real
  compile error (`NullCoverage` failing its own declared return type,
  `addons/coverage/coverage.gd:463`) — a genuine incompatibility with Godot 4.7's
  stricter static type checker, not a stale-docs mismatch. Until a working tool is
  found (or one is worth building from scratch, which is a larger investment than this
  slice justifies), coverage is reviewed procedurally: does every Given/When/Then
  scenario in the relevant `specs/*.md` file have a corresponding automated test,
  checked by a human/agent at spec-baseline review time rather than by a coverage
  percentage. Revisit this row if a maintained tool appears.
- `contract-tests-pass` — mechanically enforceable via gdUnit4 once a base
  contract/interface has 2+ implementations (per `solid-mechanical.md` criterion L,
  e.g. the Messenger/Hero Party Task Force contract in
  `specs/04-suspicion-and-response.md`), but none exist yet. No row to wire until
  Phase 3 introduces the first one — will be added then, against the real shape of that
  code, rather than guessed at now.
- `ocp-shotgun-surgery` — no static tool for GDScript is known to detect "a new case
  requires touching N pre-existing files" generically. Enforced procedurally today via
  each spec's own `ocp-extension-point` qualitative answer (see `specs/*.md`), reviewed
  at spec-authoring time rather than diff-scan time.
- `isp-method-count` / `isp-stub-detection` — mechanically checkable in principle, but
  no interface/contract-style base class exists in the codebase yet to check against
  (the first candidates — the Task Force contract, the capture-choice component — land
  in Phase 3). Building a heuristic against a code shape that doesn't exist yet would be
  guessing; wiring this is deferred to when the first real contract is introduced.
- `no-cross-cutting-helper-violation` — same reasoning as above: nothing has been
  promoted to a shared module yet (`helpers.promotion_threshold: 3` in
  `config/thresholds.yaml`), so there's nothing for a mechanical check to evaluate.
  Enforced procedurally via code review against `ai-first-organisation.md` Principle 4
  until a real promotion happens.
- `tests-red-then-green`'s *red* half — gdUnit4 confirms tests pass (green); that a
  test actually failed first, for the right reason, before implementation existed is a
  process fact captured in each Phase 3 branch's own red→green log (per
  `principles/tdd-bdd-workflow.md`), not something a single CI run can verify
  retroactively.

## Running the checks locally

```bash
# One-time setup
pip install pre-commit "gdtoolkit==4.*"
pre-commit install                       # wires .git/hooks/pre-commit and commit-msg
export GODOT_BIN=/path/to/Godot_v4.7.2-stable_win64.exe   # or add godot to PATH

# Before every commit (pre-commit runs this automatically once installed)
pre-commit run --all-files

# Test run only
bash ci/godot/scripts/run_tests.sh

# Gate 1 mechanical progress log (end of an implementation pass)
python3 ci/godot/scripts/gate1_progress_log.py
```

First-time Godot setup note (verified empirically while wiring this layer): a fresh
clone needs one `godot --headless --path . --import` pass before gdUnit4's classes
resolve — without it, gdUnit4 (and previously GUT) fails with an "not been imported"
class-name error. CI's workflow runs this automatically before tests.

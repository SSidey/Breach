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
| `isp-method-count` / `isp-stub-detection` | `ci/godot/scripts/check_isp.py` | pre-commit and CI |
| `no-cross-cutting-helper-violation` | `ci/godot/scripts/check_helper_promotion.py` | pre-commit and CI |
| `ocp-shotgun-surgery` | `ci/godot/scripts/check_ocp_shotgun_surgery.py <base-ref>` | CI only — needs a diff against a real base ref, not meaningful on a bare working tree |
| `branch-name-conforms` | `ci/godot/scripts/check_branch_name.sh` | pre-commit stage |
| `commit-message-conforms` (format half) | `ci/godot/scripts/check_commit_message.sh` | commit-msg stage |
| `commit-message-conforms` (type-vs-diff half) | same script, heuristic warning only — see Heuristic limits | commit-msg stage |
| `progress-trend` | `ci/godot/scripts/gate1_progress_log.py` | run manually at the end of an implementation pass; see `principles/progress-tracking.md` |

Four rows above (`isp-method-count`/`isp-stub-detection`, `no-cross-cutting-helper-violation`,
`ocp-shotgun-surgery`, and the `extends`-a-Node-type half of `dip-direction`) were ported
from [SSidey/Sweepminer](https://github.com/SSidey/Sweepminer)'s `dev_kit/ci/godot/`
layer — a sibling project built from the same `AI_First_Development_Kit`, which had
already solved these as real mechanical checks rather than leaving them procedural.
One claim from that project was checked and found stale, not ported: its README states
coverage is automated via a GdUnit4 "`-c` coverage flag" — `-c` is actually
`--continue` (run the full suite without failing fast, per gdUnit4's own `CmdOptions`),
not a coverage flag, and that project's own `run_tests.ps1`/`report_progress.py`
comments admit coverage is still manual. Confirms this repo's own coverage gap below is
real, not an oversight.

## Heuristic limits (stated plainly, not hidden)

- `check_dependency_direction.py` — textual scan for `preload(`/`load(`/`extends`
  references from `sim/` into `presentation/`, plus a fixed list of Godot's common
  Node-family base types to catch a `sim/` file directly `extends`-ing an engine scene
  type. Cannot see an indirect dependency routed through a third file, does not
  understand dead/conditional code paths, and the Node-family list is fixed, not a
  lookup against the engine's actual class hierarchy — an obscure Node-derived type not
  on the list would be missed.
- `check_function_length.py` — measures a top-level `func` to the next top-level
  declaration. A function nested inside an inner `class` block is not measured
  separately (known blind spot, not silently wrong — see the script's own docstring).
- `check_generic_naming.py` — flags the kit's example generic names
  (`process`/`handle`/`util`/`helper`/`common`/`base`/`manager`/`data`) at or above the
  grep-hit threshold. Cannot distinguish the kit's allowed "scoped to a single class,
  never called by the short name externally" exception from a genuine violation by grep
  alone — flags the hit count and leaves the scoped-exception judgment to manual review.
  (Considered broadening this to flag *every* identifier at/above the threshold,
  matching Sweepminer's literal reading of the rubric text — kept narrow instead, since
  that would flag legitimately specific, widely-used names as the codebase grows; a
  deliberate choice, not an oversight.)
- `check_isp.py` — scans production code only (`tests/` is excluded — a test suite's
  many `test_*` methods aren't an ISP concern; scanning it produced exactly that false
  positive, a 9-test suite flagged as "too fat," before the exclusion was added).
  Stub-detection flags *any* function whose only statement is
  `pass`/`push_error(...)`/`assert(false, ...)`, not only true overrides of a base
  method with real behaviour (no inheritance graph is built) — a legitimate no-op
  virtual hook will false-positive. Method-count is applied to every remaining `.gd`
  file, not only files genuinely acting as an interface for multiple implementers,
  since GDScript has no formal interface keyword to detect that distinction
  mechanically — treat a hit as a prompt to check which case it is.
- `check_ocp_shotgun_surgery.py` — counts pre-existing files modified in a diff; it
  cannot distinguish "one new case forced N files open" from any other reason N files
  changed together (e.g. a deliberate, justified refactor). Only meaningful with a real
  base ref (a PR's merge-base), so it only runs in CI, not the working-tree-only
  pre-commit gate.
- `check_helper_promotion.py` — only catches the catch-all-filename shape of the
  violation (`utils.gd`, `helpers.gd`, `common.gd`, `base.gd`, `manager.gd`, `data.gd`);
  it can't detect a helper duplicated past the promotion threshold without call-graph
  tooling.
- `check_commit_message.sh`'s type-vs-diff cross-check — textual heuristic (new
  top-level `func`/`class_name`/`signal` lines ⇒ "looks like a capability was added").
  Both false positives (a `feat` adding only a private helper) and false negatives (a
  new public API added without a new top-level declaration, e.g. a new exported
  property) are possible. It's a warning, not a hard block, for exactly this reason.

## Known environment gotchas

- **`gdtoolkit`'s grammar cache race (CI only).** Confirmed upstream bug —
  [Scony/godot-gdscript-toolkit#428](https://github.com/Scony/godot-gdscript-toolkit/issues/428).
  On a cold cache (every fresh CI runner), `gdlint`/`gdformat` can race to create the
  same grammar-cache directory via an unguarded `os.makedirs` — the loser raises
  `FileExistsError`, which gets misreported as `Cannot open file '<unrelated .gd
  file>': File exists`, naming whatever file happened to be mid-parse rather than the
  real cause. Hit this for real on this repo's own CI. `.github/workflows/ci.yml`
  pre-creates the cache directory before either tool runs, per the issue's documented
  workaround — a developer machine only ever races once (the directory persists after
  that), so this isn't needed locally.

## Procedural, not scripted

- `coverage-overall` / `coverage-changed-lines` — **permanently procedural, per
  Decision 10** in `Breach — Reverse Tower Defense Design Spec.md`, not an open TODO.
  **No working GDScript coverage tool was found**, verified empirically, not assumed
  from documentation. The most-starred candidate (`jamie-pate/godot-code-coverage`) was
  vendored and run against a trivial test on this project's actual Godot 4.7.2 install;
  it crashed with a real compile error (`NullCoverage` failing its own declared return
  type, `addons/coverage/coverage.gd:463`) — a genuine incompatibility with Godot 4.7's
  stricter static type checker, not a stale-docs mismatch. A sibling project
  (SSidey/Sweepminer) was checked too and confirmed to have the identical gap despite
  its README initially appearing to claim otherwise (see above) — this isn't a gap
  specific to how this repo looked for a tool. Coverage is reviewed procedurally
  instead: does every Given/When/Then scenario in the relevant `specs/*.md` file have a
  corresponding automated test, checked by a human/agent at spec-baseline review time
  rather than by a coverage percentage. Decision 10 can be superseded if a maintained
  tool later appears — that's new information, not a reason to keep this row open-ended
  in the meantime.
- `contract-tests-pass` — mechanically enforceable via gdUnit4 once a base
  contract/interface has 2+ implementations (per `solid-mechanical.md` criterion L,
  e.g. the Messenger/Hero Party Task Force contract in
  `specs/04-suspicion-and-response.md`), but none exist yet. No row to wire until
  Phase 3 introduces the first one — will be added then, against the real shape of that
  code, rather than guessed at now. (Sweepminer's approach is a naming convention —
  `tests/**/test_*_contract.gd` run by the same generic test runner — not a distinct
  script; adopt the same convention here once a real contract exists, rather than
  building anything new.)
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

# OCP shotgun-surgery (diff-scoped; CI-only, but runnable locally against a real ref)
python3 ci/godot/scripts/check_ocp_shotgun_surgery.py origin/main

# Gate 1 mechanical progress log (end of an implementation pass)
python3 ci/godot/scripts/gate1_progress_log.py
```

First-time Godot setup note (verified empirically while wiring this layer): a fresh
clone needs one `godot --headless --path . --import` pass before gdUnit4's classes
resolve — without it, gdUnit4 (and previously GUT) fails with an "not been imported"
class-name error. CI's workflow runs this automatically before tests.

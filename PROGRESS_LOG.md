# Gate 1 Mechanical Progress Log

Per AI_First_Development_Kit/principles/progress-tracking.md. Appended to at the end of every implementation pass by `ci/godot/scripts/gate1_progress_log.py` - never edited in place.

Schema note: rows from 2026-09-20 onward that predate the `isp violations` / `helper violations` / `dip violations` columns were logged before those checks existed (ported from https://github.com/SSidey/Sweepminer) - shorter rows are the historical record, not an error.

| Date | Branch | Test count | Lint warnings | srp-size (function) violations | naming violations | isp violations | helper violations | dip violations | Coverage | Result |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-20 | chore/godot-ci-tooling | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/data-resources | 12 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | chore/port-sweepminer-ci-checks | 12 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/simulation-clock | 21 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/command-queue | 29 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | chore/drop-coverage-automation | 29 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/lane-movement-and-combat | 42 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/economy-system | 51 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/capture-resolution | 61 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/suspicion-system | 73 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/scripted-beat-watcher | 81 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/lane-view | 92 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | feature/hud | 104 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-20 | chore/codify-pr-notify-and-stop | 104 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | chore/context-locality-check | 104 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | fix/exempt-merge-commit-messages | 104 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | feature/map-assembly-playtest | 118 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | feature/tick-progress-indicator | 121 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | fix/loss-condition-and-choice-button-visibility | 122 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | feature/tick-speed-and-auto-pause | 133 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | fix/speed-sync-pending-count-cap-and-end-of-game | 136 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | fix/speed-sync-pending-count-cap-and-end-of-game | 134 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-21 | feature/node-graph-data-model | 142 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-25 | feature/map-scene-authoring-tool | 148 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-25 | feature/graph-topology-edges | 158 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-25 | feature/node-schema-round-3 | 168 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-26 | feature/node-schema-round-3 | 179 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-27 | feature/node-schema-round-3 | 180 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-28 | feature/node-schema-round-3 | 185 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-28 | feature/designer-map-import | 205 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-28 | feature/local-designer-app | 205 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-29 | feature/map-viewer | 231 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-30 | feature/map-layout-schema | 281 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-30 | feature/realtime-skirmish | 311 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-30 | feature/formation-skirmish | 356 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-30 | feature/formation-skirmish | 369 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-09-30 | feature/formation-skirmish | 380 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/formation-skirmish | 386 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/formation-domain-production | 399 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/formation-positions | 412 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/formation-weapons-scale | 428 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/formation-spread-merge | 442 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-01 | feature/lanes-eight-wide | 443 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/designer-ground-model | 455 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/ground-elevation | 469 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/ground-liquids | 477 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/ground-liquids | 479 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/ground-relief | 495 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/structure-loads | 505 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/structure-loads | 505 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/structure-planner | 509 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/planner-editing | 515 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/planner-editing | 515 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/tile-scale-64 | 519 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/node-footprints | 526 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |
| 2026-10-02 | feature/subnodes | 538 | 0 | 0 | 0 | 0 | 0 | 0 | N/A (no tool, see ci/godot/README.md) | PASS |

---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Composition Root and Minimal Player Input

## Purpose

Phase 3, item 11 of the vertical-slice execution plan: wire every `sim/` and
`presentation/` component built so far into a real, running Godot scene loading the
`P-f-F-c` `MapDef`, plus the minimal player-input surface needed to actually play it.
This is `hybrid`: the composition root itself (`main.tscn`/`main.gd`) is a wiring/
assembly artifact with no independent behavior of its own to unit-test (policy half,
same honesty as `LaneView`'s engine callbacks — see `specs/05`'s Notes); the two new
input components it wires in (`WaveFormPanel`, `CaptureChoicePanel`) and one small
`LaneSimulation` addition they depend on have real testable logic (tooling half).

**Why an input spec is needed now, and not before:** every earlier spec explicitly
deferred "a composition root (Phase 3 item 11)" for connecting `SimEvents` (see
`specs/01`/`03`/`04`/`06`'s Notes), but none of them — including `specs/05`, which
covers all of `HUD`'s four files — defines how a player actually *issues* a command.
`WaveCommandPanel` and `TimeControls` are read-only/timing-only by design (`specs/05`'s
own scope). Without this spec, there is no way to queue a unit, march a wave, or choose
Ravage/Fortify/Dismantle — the scripted scenario in `specs/00` could not actually be
played. Confirmed with the user before implementation: a small set of real UI buttons
(not keyboard shortcuts, not a non-interactive scripted replay) is the right scope for
this first playtest, matching `TimeControls`' own "a few plain buttons" shape.

## Components introduced

- `LaneSimulation.despawn_wave(wave: Dictionary)` (`sim/lane_simulation.gd`) — removes
  a wave from active tracking without combat. **Fills a real gap found while
  integrating, not a pre-planned addition:** `specs/03`'s auto-extraction scenario
  states a capturing wave's units "are no longer available for a marching wave without
  a new command," but `CaptureResolution.on_node_captured()` only tracks yield-ticking
  state — it never touches `LaneSimulation._waves`. Left alone, `advance_positions()`
  would blindly re-march that same wave into whatever's next on the lane on the very
  next tick (in this map, straight into the Fort's garrison with an under-sized force),
  contradicting the "auto-extraction" behavior every other spec assumes already works.
  `despawn_wave()` is the composition root's tool to actually detach a wave once it
  auto-extracts. Scoped to resource-node captures only, per `specs/03`'s explicit
  "fort capture always goes to the awaiting-choice state — there's no 'default job'"
  note: a Fort-capturing wave is deliberately *not* despawned, since `specs/00`'s beats
  4/5 require that same horde to keep marching toward the Hero Party and the Core.
- **Committed wave commands are interpreted by the composition root directly**
  (`main.gd`'s `_on_command_committed(command)`, calling `lane.spawn_wave(...)`), not
  by a new `LaneSimulation.on_command_committed()` method. This revises `specs/01`'s
  stated design ("`LaneSimulation`... owns applying its own committed commands") —
  disclosed here rather than silently dropped: `LaneSimulation` was already sitting at
  exactly the ISP method-count threshold (7 public methods) before this item;
  `despawn_wave()` alone would push it to 8. Rather than exploit
  `check_isp.py`'s documented multi-line-signature blind spot (it can't see
  `spawn_moving_blocker`'s wrapped signature, which is why it under-counts by one) or
  bump the configured threshold, the composition root — which already needs to
  interpret domain-specific narrative/suspicion glue no `sim/` class owns (see Notes
  below) — takes on this one additional translation too. `LaneSimulation`'s own
  `node_owner()`/`node_garrison_hp()` were also merged into a single `node_state()`
  query (see below) to make room for `despawn_wave()` without growing the count at
  all, keeping the real threshold honest rather than borrowing against it.
- `LaneSimulation.node_state(index: int) -> Dictionary` (`sim/lane_simulation.gd`) —
  replaces the separate `node_owner(index)`/`node_garrison_hp(index)` queries with one
  `{"owner": String, "garrison_hp": int}` result. Both queries had no real consumer
  outside this file's own tests yet, and callers that want a node's state generally
  want both fields together — merging them is a same-behavior refactor, not a scope
  change, made to free a slot in the ISP count for `despawn_wave()` (see above).
- `WaveFormPanel` (`presentation/wave_form_panel.gd`) — the "queue a Grem, then march"
  input. `on_queue_grem_pressed(unit_def)` spends `unit_def.cost_food` from
  `EconomySystem` immediately and buffers the unit (Grem are bought instantly, per the
  prototype's `pay(cost)` — there is no "unit in production" concept in this slice to
  gate on); `on_march_pressed(start_index, direction)` enqueues the buffered units as a
  single `CommandQueue` command with an always-filled predicate. Real latching against
  `SimulationClock`'s tick boundary (Decision 3) still applies — the wave only starts
  marching on the *next* tick, not immediately — but this map has no content that
  makes slots fill *gradually* (no "unit becomes available later" source), so unlike
  `specs/01`'s illustrative 5-slot example, "filled" here just means "at least one unit
  was bought." A future item with real gradual availability would change the predicate,
  not `CommandQueue` itself.
- `CaptureChoicePanel` (`presentation/capture_choice_panel.gd`) — `on_ravage_pressed`,
  `on_fortify_pressed`, `on_dismantle_pressed`, each calling exactly one
  `CaptureResolution.issue_choice(node_index, choice)` and nothing else. Bypasses
  `CommandQueue` deliberately, same exception class as `TimeControls` (`specs/05`):
  a capture choice is an instantaneous, one-shot decision with nothing to slot-fill —
  `CommandQueue`'s latching exists for commands that can be partially filled over time,
  which does not describe "pick Ravage or Harvest."
- `main.tscn` / `main.gd` — the composition root. Loads
  `content/maps/p_f_F_c.tres`, constructs one instance of every `sim/` component
  against it, connects every `SimEvents` signal each spec's Notes deferred to this
  item, and hosts `LaneView` plus the input/readout nodes above. See Notes below for
  the suspicion-spike wiring and Hero-Party-defeat correlation this item had to decide.

## Scenarios (Given/When/Then)

```gherkin
Scenario: Despawning a wave removes it from active tracking
  Given a wave exists in LaneSimulation
  When despawn_wave(wave) is called
  Then the wave no longer appears in waves()
  And it is not moved or resolved by a later advance_positions() call

Scenario: node_state reports a node's current owner and garrison hp together
  Given a LaneSimulation with a node that has been captured and partially damaged
  When node_state(index) is called
  Then the returned Dictionary's "owner" and "garrison_hp" match the node's actual
    tracked state

Scenario: Queueing a Grem spends food and buffers the unit
  Given the player can afford a Grem's cost_food
  When on_queue_grem_pressed(unit_def) is called
  Then EconomySystem's food balance decreases by cost_food
  And the method returns true

Scenario: Queueing a Grem the player cannot afford does nothing
  Given the player's food balance is below cost_food
  When on_queue_grem_pressed(unit_def) is called
  Then EconomySystem's food balance is unchanged
  And the method returns false

Scenario: Marching with no buffered units does nothing
  Given no Grem have been queued
  When on_march_pressed(start_index, direction) is called
  Then CommandQueue has no pending commands

Scenario: Marching with buffered units enqueues exactly one command
  Given at least one Grem has been queued
  When on_march_pressed(start_index, direction) is called
  Then CommandQueue has exactly one pending command
  And it is already filled
  And the buffered units are cleared for the next wave

Scenario: Each capture-choice button calls exactly one CaptureResolution method
  Given a node awaiting a capture choice
  When on_ravage_pressed(node_index) / on_fortify_pressed(node_index) /
    on_dismantle_pressed(node_index) is called
  Then CaptureResolution.issue_choice(node_index, "ravage" / "fortify" / "dismantle")
    is the only call made
```

## Test-first order

1. `LaneSimulation.node_state()` — merge of the two existing query methods, red/green
   against the existing call sites updated to match.
2. `LaneSimulation.despawn_wave()` — red before the method exists.
3. `WaveFormPanel.on_queue_grem_pressed()` — afford/can't-afford cases, against a real
   `EconomySystem` (cheap to construct, same reasoning as `TimeControls`' tests).
4. `WaveFormPanel.on_march_pressed()` — empty-buffer no-op, then the enqueue case,
   against a real `CommandQueue`.
5. `CaptureChoicePanel`'s three button methods, against a real `CaptureResolution`.
6. No automated test for `main.gd` itself — engine glue (scene tree construction,
   signal wiring), same honesty as every other composition-level file in this project.
   Verified by the manual playtest this item exists to run.

## Notes / open questions

- **A second real gap found while verifying this item's balance numbers, disclosed
  here rather than silently patched:** `LaneSimulation._resolve_wave_arrival()`'s
  mid-lane-clash branch (a wave meeting a moving blocker, e.g. the Hero Party) never
  wrote a surviving blocker's reduced hp back onto it — only the stationary-garrison
  branch did (`_node_garrison_hp[index] = outcome["remaining_blocker_hp"]`). A Hero
  Party that survived a clash would fight at full hp again on every later tick,
  silently breaking `specs/02`'s own stated stalemate rule ("this is what makes
  grinding down a fort over several rounds a real multi-tick siege") for the moving-
  blocker case specifically. Fixed by mirroring the garrison branch's persistence
  (`mover["blocker"]["hp"] = outcome["remaining_blocker_hp"]`), with a regression test
  (`test_a_surviving_moving_blocker_keeps_its_reduced_hp_for_the_next_clash`) — no
  existing test exercised a moving blocker surviving a hit, only the destroyed case.
  This directly shaped this map's Hero Party balance: since grinding a mid-lane clash
  down over several ticks now genuinely works, the numbers below don't have to
  guarantee a one-hit kill, matching `specs/00` beat 5's actual intent (a Ravage-funded
  horde that can plausibly finish the fight, not necessarily in one exchange).
- **The "Messenger flees" beat (`specs/00`, beat 3) has no mechanically interceptable
  entity in this slice**, consistent with Decision 7 already deferring Scout/
  Infiltrator (nothing in this slice's roster could intercept a Messenger anyway).
  Instead of a real lane-entity Messenger, the composition root raises Core Suspicion
  in **two** steps from the Fort fight, both driven directly by `SimEvents`: an
  "engagement" spike (`+50`) on `combat_resolved` at the Fort's node index, and a
  "capture" spike (`+25`) on `node_captured` at the same index. Against this map's
  thresholds (`[20, 45, 70, 90]`), the first spike alone lands in Alarmed (narrating
  "The defenders are on alert" — beat 3's fictional beat), and the second pushes the
  total to 75, crossing into Mobilized and dispatching the Hero Party (beat 4) — two
  distinct `suspicion_tier_changed` events and narrative lines from one Fort assault,
  without needing a real Messenger mover. A `Messenger` `ResponseUnitDef` is still
  authored as map data (per `specs/06`'s policy half) since it's referenced by name in
  `specs/00`'s narrative and may back a real interceptable entity in a future slice
  once Scout/Infiltrator exist — but no `TaskForceDispatch` tier is assigned to it in
  this map's tier-to-unit table, the same "exists in code/data as content, currently
  no-op" treatment Decision 5 already gives Wary/Alarmed.
- **Hero Party defeat correlation** follows the exact pattern
  `tests/sim/test_vertical_slice_win_condition.gd` already established: the
  composition root records `moving_blockers().size()` before calling
  `advance_positions()`each tick, and if `TaskForceDispatch.dispatched()` is non-empty
  and the mover count dropped afterward, treats it as that Task Force's defeat —
  correct for this map's actual content (at most one dispatched Task Force, the Hero
  Party, ever exists at a time per Decision 5's minimal-content scope) without needing
  `LaneSimulation` to hand out per-entity ids it doesn't have yet (same "not built
  ahead of a real second case" reasoning `specs/05`/`specs/06` already applied to
  `LaneView`/`ScriptedBeatWatcher`).
- **Player unit count for the loss condition** (`ScriptedBeatWatcher.
  on_player_unit_count_changed`) is recomputed by the composition root after every
  `advance_positions()` call by summing surviving units across all player-owned
  entries in `lane.waves()` — the only place casualties can occur.
- Manual playtest itself (does it *feel* right, is the pacing good) is deferred to the
  user, per this project's standing rule that an agent judging its own change's
  play-feel has a conflict of interest (`progress-tracking.md`, already the basis for
  Gate 2 being human-only). What this item's author *can* and does verify: a scripted,
  non-interactive run through the exact same beats using the real authored data
  (`content/maps/p_f_F_c.tres` etc.) via a headless Godot script, confirming the wiring
  produces the intended events in order. This is a stand-in smoke check, not a
  replacement for the human's own interactive pass — recorded as such in the PR.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into `wave_form_panel.gd` ("wave-
  forming input"), `capture_choice_panel.gd` ("capture-choice input"), and the two
  `LaneSimulation` additions grouped with their existing file (already "lane
  occupancy"). `main.gd`'s purpose is "composition root" — one noun phrase, described
  once even though it wires many things, same reasoning `specs/01`'s `SimulationClock`/
  `CommandQueue` pairing already used for "one feature, two files."
- `ocp-extension-point`: a new command type is a new `command["type"]` value and a new
  `match`/`if` arm in the relevant system's `on_command_committed` — not a change to
  `CommandQueue`. A new capture choice is a new button method plus a new `match` arm
  already inside `CaptureResolution.issue_choice` (existing, unchanged by this item).
- `lsp-contract-scope`: not applicable — no shared base/interface introduced here.
- `isp-fit`: `WaveFormPanel`'s surface is `on_queue_grem_pressed`, `on_march_pressed` —
  2 methods. `CaptureChoicePanel`'s is 3 button methods. `LaneSimulation` nets to the
  same 7 public methods it had before this item (`node_owner`/`node_garrison_hp`
  merged into `node_state`, freeing the slot `despawn_wave` needed) — see Components
  introduced above for why this was a real constraint, not a stylistic choice.
- `dip-direction`: `WaveFormPanel`/`CaptureChoicePanel` are presentation-layer,
  depending on `sim/` (`EconomySystem`, `CommandQueue`, `CaptureResolution`), never the
  reverse. `main.gd` is the one file in this project allowed to import both layers by
  construction — it *is* the composition root the DIP boundary is drawn around, same
  as `core/sim_events.gd`'s documented exception for a different reason.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — the composition root (`main.tscn`/`main.gd`) and the
  `.tres` map-content authoring already covered by `specs/06` are policy/no-test-plan;
  `LaneSimulation`'s two additions and the two new input panels are `code`, tested per
  above.
- `tdd-plan-present`: see Scenarios and Test-first order above, for the tooling half.
- `no-drift`: implements the "composition root, Phase 3 item 11" deferral already
  named in `specs/01`/`03`/`04`/`06`'s Notes; resolves (does not contradict) Decision 2
  and Decision 5's open ends.
- `commit-classification-plan`: `fix(sim): despawn a wave on resource-node
  auto-extraction, merge node queries for ISP` (corrects behavior implied but not
  shipped by `specs/03`, plus the same-commit refactor it required to stay within the
  ISP threshold); `feat(presentation): add wave-forming and capture-choice input`;
  `feat: assemble the P-f-F-c composition root scene` (data authoring + scene, no test
  plan) — three commits, since the diff genuinely mixes a bug fix with two additive
  features, per the type-vs-diff test in `templates/commit-message.md`.

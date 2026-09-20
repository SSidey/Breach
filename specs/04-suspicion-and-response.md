---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Suspicion Meter and Task Force Dispatch

## Purpose

The Core Suspicion meter, its tiered state machine, and Task Force dispatch — generalized
per the parent spec's architecture, content-populated only for this slice's Hero Party
beat (Decision 5).

## Components introduced

- `SuspicionSystem` — owns the 0–100 meter, its data-driven tier thresholds
  (Calm/Wary/Alarmed/Mobilized/Full Alert), decay-when-calm, and the two inputs that
  raise it (silence, detection).
- `TaskForceDispatch` — owns spawning a Task Force (Messenger, Hero Party) onto the
  lane when a tier's entry action fires, and returning it to the roster / marking it
  consumed on completion or destruction, per the parent spec's Core Roster section.
  Deliberately generic over Task Force *purpose* (respond, investigate, ...) even
  though this slice only exercises "respond."

## Scenarios (Given/When/Then)

```gherkin
Scenario: Attacking a fort raises suspicion via detection
  Given Core Suspicion is at its Calm baseline
  When the player's force engages F's garrison (specs/02-lane-movement-and-combat.md)
  Then Core Suspicion receives a detection-spike increment

Scenario: A silent node still raises suspicion over time
  Given a resource node is held by the player with no report to the Core for N ticks
  When N ticks elapse without a report
  Then Core Suspicion receives a silence increment
  (Not exercised by this slice's scripted scenario, but must not regress once tuned —
   ported from the prototype's alarm/messenger mechanic per the parent spec.)

Scenario: Crossing the Mobilized threshold dispatches a Hero Party
  Given Core Suspicion crosses the Mobilized tier's threshold
  When SuspicionSystem transitions Calm/Wary/Alarmed -> Mobilized
  Then TaskForceDispatch spawns a Hero Party Task Force from c
  And SimEvents.suspicion_tier_changed is emitted with tier = Mobilized
  And the Hero Party marches down the lane as a real, visible, interceptable entity

Scenario: Wary/Alarmed tiers with no assigned unit no-op safely (Decision 5)
  Given Core Suspicion crosses the Wary tier's threshold
  And this map's tier-to-unit table has no ResponseUnitDef assigned to Wary
  When SuspicionSystem transitions into Wary
  Then no Task Force is dispatched
  And SimEvents.suspicion_tier_changed is still emitted (for the narrative log,
    Decision 8), only the dispatch step is skipped

Scenario: Suspicion decays over time when nothing is wrong
  Given Core Suspicion is elevated and no new silence/detection input occurs
  When ticks elapse
  Then Core Suspicion decreases toward its Calm baseline at the configured decay rate

Scenario: A Task Force that completes its task returns to the roster, not consumed
  Given a Hero Party Task Force reaches its destination and is not defeated
  When its task resolves (e.g. investigation complete)
  Then it returns to the Core's roster and becomes available for a future dispatch
  (Documented for completeness per the parent spec's roster model; this slice's
   Hero Party is expected to be defeated in combat, which is the consumption path,
   not the return-to-roster path — both must exist since Decision 5 keeps this
   generalized rather than hardcoded to only the combat outcome.)

Scenario: A Task Force destroyed before completing its task is consumed
  Given a Hero Party is defeated in CombatResolver (specs/02-lane-movement-and-combat.md)
  When combat resolves with the Hero Party as the loser
  Then the Hero Party Task Force is removed from the roster permanently
  And this is the trigger the vertical slice's closing beat (Decision 9) waits on
```

## Test-first order

1. `SuspicionSystem`: meter add/decay, tier-threshold crossing detection — pure state,
   tested before any dispatch wiring exists.
2. Tier-changed event emission, independent of whether a unit is assigned to that tier.
3. `TaskForceDispatch.on_tier_entered(tier)` — no-op case (no assigned unit) tested
   first, since it's the common case for this slice's Wary/Alarmed tiers; then the
   assigned case (Mobilized → Hero Party).
4. Return-to-roster vs. consumed-on-defeat, as two separate outcomes of the same
   Task Force lifecycle.
5. Integration test replaying this slice's exact scripted path: attack F → detection
   spike → Mobilized → Hero Party spawned → defeated in combat → consumed.

## Notes / open questions

- Tier thresholds, decay rate, and the tier→unit assignment table are per-map data
  (`MapDef`), not hardcoded — this is what makes "no unit assigned" a data fact rather
  than a special-cased code branch.
- Guard/Militia `ResponseUnitDef`s are not authored in this slice (Decision 5); adding
  them later is authoring new data and assigning it to the Wary/Alarmed rows of the
  tier table, not a change to `SuspicionSystem` or `TaskForceDispatch`.
- Per the parent spec, Scout would reveal the numeric meter and Infiltrator could
  intercept any tier's Task Force — neither ships in this slice (Decision 7), so the
  Hero Party is interceptable in principle (it's a real lane entity) but nothing in
  this slice's roster can actually intercept it before it engages the player's force.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into `sim/suspicion_system.gd`
  ("suspicion meter and tier state") and `sim/task_force_dispatch.gd` ("Task Force
  spawn and lifecycle") — grouped here because the tier state machine's entry action
  *is* a dispatch call, so the two scenarios can't be reviewed independently.
- `ocp-extension-point`: adding a new tier's content (Guard/Militia) is a data change
  to the tier→unit table, not a new `if`/`match` arm in `TaskForceDispatch` — this is
  the direct target of the shotgun-surgery check for this feature.
- `lsp-contract-scope`: Messenger and Hero Party are two `ResponseUnitDef` instances of
  the same Task Force contract (`composition`, `purpose`, `destination`, per the parent
  spec). With 2 implementations reaching the roster/lifecycle path, a shared contract
  test is required (`solid-mechanical.md` criterion L, threshold 2): both must pass
  "returns to roster on completion, consumed on destruction" unmodified.
- `isp-fit`: `TaskForceDispatch`'s public surface is `on_tier_entered(tier)`,
  `mark_completed(task_force)`, `mark_consumed(task_force)` — 3 methods.
- `dip-direction`: simulation-layer only; HUD's narrative log (Decision 8) subscribes
  to `SimEvents.suspicion_tier_changed`, never reads `SuspicionSystem` state directly.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decisions 5 and 8; generalizes the prototype's
  alarm/messenger mechanic per the parent spec's Enemy Threat Model section rather than
  replacing it.
- `commit-classification-plan`: `feat(sim): add suspicion meter and task force
  dispatch`.

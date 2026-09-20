---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Resource Nodes, Capture Choice, and Auto-Extraction

## Purpose

What happens to a node and its capturing units the instant a resource node or fort is
taken: the Harvest/Ravage and Fortify/Dismantle capture choices, and the auto-extraction
default (Decision 2). Also owns harvester yield decay/floor and the economy's resource
pools, since capture choice and yield are the same feature (a Harvest choice *is* a
commitment to a yield curve).

## Components introduced

- `EconomySystem` — five resource pools (Food, Wood, Stone, Metal, Crystal); harvester
  yield with –10%/N-round decay floored at a minimum trickle, per the parent spec's
  Economy section.
- `CaptureResolution` — per-node capture-choice component. For a resource node:
  Harvest (steady, decaying rate) vs. Ravage (lump sum, node exhausted after). For a
  fort: Fortify (cost, forward defense) vs. Dismantle (free salvage). Also owns the
  auto-extraction default: units present at a resource node when it flips to "held"
  are assigned to Harvest at that node unless the player issues a different command.

## Scenarios (Given/When/Then)

```gherkin
Scenario: Capturing a resource node with units present defaults them to Harvest
  Given 3 Grem arrive at f and f has garrison 0
  When f's ownership flips to the player (per specs/02-lane-movement-and-combat.md)
  Then all 3 Grem are assigned the Extraction job at f, using the Harvest choice
  And they are no longer available for a marching wave without a new command

Scenario: Harvest yield decays over time toward a floor
  Given f is held and Harvested, yielding 10 Food/tick initially
  When 1 decay interval (N ticks) elapses
  Then the yield drops by 10%
  When enough decay intervals elapse to reach the configured floor
  Then the yield stays at the floor and decays no further

Scenario: Ravage grants a lump sum and exhausts the node
  Given f is held, previously Harvested for several intervals (yield partially decayed)
  When the player issues Ravage on f
  Then EconomySystem receives a one-time Food lump sum reflecting f's remaining value
  And f produces no further yield afterward (exhausted, per the parent spec's
    recommended simplification: no reduced-lump re-ravage)

Scenario: Fort capture offers Fortify/Dismantle, does not auto-resolve
  Given F's garrison is defeated (per specs/02-lane-movement-and-combat.md)
  When the tick resolving F's capture completes
  Then F's ownership flips to the player
  And F enters an awaiting-choice state (neither Fortify nor Dismantle applied yet)
  And the player must issue one of the two choices before F does anything further

Scenario: Dismantle grants salvage resources for free
  Given F is held and awaiting choice
  When the player issues Dismantle
  Then EconomySystem receives Wood/Stone salvage per the parent spec's Economy table
  And F no longer functions as a structure

Scenario: An uncaptured/lost node reverts if left undefended
  Given f is held but has no fortification and no harvester/garrison present
  When an enemy Task Force (e.g. Messenger, per specs/04-suspicion-and-response.md)
    passes through f unopposed
  Then f's ownership reverts to the defender
```

## Test-first order

1. `EconomySystem` resource pools: add/spend, red before any pool exists.
2. Harvest yield decay/floor — pure calculation, tested in isolation before wiring to
   ticks.
3. `CaptureResolution` auto-extraction default on resource-node capture (Decision 2) —
   this is the scenario the vertical slice's first beat depends on directly.
4. Ravage lump-sum + node exhaustion.
5. Fort awaiting-choice state + Fortify/Dismantle.
6. Ground-must-be-held reversion (lowest priority for the vertical slice — the scripted
   scenario doesn't require the player to lose ground, but the parent spec marks this
   mechanic as already validated and load-bearing, so it ships in this pass rather than
   being silently dropped).

## Notes / open questions

- Harvest decay interval `N` and floor rate are per-`NodeDef` values (data), not
  hardcoded — ported from the prototype's tuned defaults per the parent spec's
  instruction, with exact figures recorded in `specs/06-map-content-p-f-F-c.md`.
- Auto-extraction (Decision 2) only fires for resource nodes; fort capture always goes
  to the awaiting-choice state — there's no "default job" to assign a unit to at a
  fort.
- **Scope decisions made while implementing item 6 (`CaptureResolution`), both
  disclosed here rather than silently built or silently dropped:**
  - **Ground-must-be-held reversion (scenario 6) is deferred**, not implemented in
    this item. Its actual trigger — an enemy Task Force passing through unopposed —
    doesn't exist as a concept until `specs/04`'s `TaskForceDispatch` ships (Phase 3
    item 7). Building the revert mechanism now, with no real trigger to drive or test
    it against, would be exactly the kind of premature scope this project avoids
    elsewhere. Revisit when Task Force movement exists.
  - **Fortify's economic half ships (spend Wood/Stone per `NodeDef.fortify_wood_cost`/
    `fortify_stone_cost`); its mechanical defensive effect does not.** The parent
    spec's Fortify is "forward defense" — a new blocker at that node — but nothing in
    this vertical slice's scripted scenario (`specs/00`) ever re-attacks a fortified
    position, so there's no concrete case to build or test against yet. Doing so would
    also need `LaneSimulation` to expose garrison mutation after the fact, which
    nothing currently calls. `specs/00`'s own framing already treats Dismantle as "the
    simplest path to close the slice," implying Fortify's full payoff was never
    load-bearing for this pass.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into `sim/economy_system.gd`
  ("resource pools and yield") and `sim/capture_resolution.gd` ("node capture-choice
  and auto-extraction") — grouped in this spec because the auto-extraction default is
  meaningless without the yield/choice model it defaults into.
- `ocp-extension-point`: a new resource type or a new capture-choice option (e.g. a
  future third option) plugs in as new `NodeDef` data and a new case in
  `CaptureResolution`'s choice enum — flagged for review if a third choice ever
  requires touching `EconomySystem` itself, which would indicate the two aren't as
  separable as assumed here.
- `lsp-contract-scope`: not yet applicable — one capture-choice implementation per node
  type (resource, fort); these are two different contracts (different choice sets), not
  two implementations of the same one, so no shared contract test is required yet. If a
  third node type introduces a third choice-pair, revisit whether a shared
  "CaptureChoice" contract should unify them.
- `isp-fit`: `CaptureResolution`'s public surface is `on_node_captured(node_index,
  node)`, `issue_choice(node_index, choice)`, `is_awaiting_choice(node_index)`, plus
  (added in item 6, same reasoning as `CommandQueue`'s `on_tick_advanced` — see
  `specs/01`) an explicit `on_tick_advanced(tick_number)` rather than self-subscribing
  to `SimEvents` — 4 methods, under threshold.
- `dip-direction`: simulation-layer only; HUD (later spec) reads `SimEvents` to know a
  node is awaiting choice and calls `issue_choice` via `CommandQueue`, never mutates
  `CaptureResolution` state directly.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decision 2 directly; ports the Economy section's
  five-resource model and decay rule, and the Structures section's capture-choice rule,
  without altering either.
- `commit-classification-plan`: `feat(sim): add resource economy, capture choice, and
  auto-extraction`.

---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Presentation: Tick Interpolation, Wave UI, Narrative Log, Time Controls

## Purpose

Everything that renders simulation state without ever mutating it. Consumes
`SimEvents` exclusively; issues player intent back into the simulation only through
`CommandQueue`. This is the DIP boundary the parent spec's Notes for the implementing
agent calls for ("separate simulation from presentation... a separate scene tree
consumes those events to animate").

## Components introduced

- `LaneView` — renders nodes and the lane; interpolates unit position/animation
  between the previous and current tick's state using elapsed real time ÷
  `SimulationClock`'s configured tick duration (Decision 1).
- `HUD` — resource bar (`EconomySystem` pool readout), wave-command panel (shows live
  slot-fill state from `CommandQueue`, per Decision 3), narrative log (tier-change
  lines per Decision 8), time controls (play/pause/speed/skip-to-marker, calling
  `SimulationClock` directly — these are timing controls, not simulation commands, so
  they bypass `CommandQueue` deliberately).

## Scenarios (Given/When/Then)

```gherkin
Scenario: A unit's on-screen position interpolates smoothly between ticks
  Given a unit moved from lane position 0 to 1 on the last tick
  And 50% of the tick duration has elapsed in real time since
  When LaneView renders the current frame
  Then the unit is drawn at approximately the midpoint between position 0 and 1

Scenario: Skip-to-marker snaps the view forward without a partial interpolation frame
  Given LaneView is mid-interpolation between two ticks
  When the player presses skip-to-marker
  Then LaneView immediately reflects the new tick's full state with no visible
    half-interpolated frame persisting

Scenario: Wave-command panel reflects live slot-fill state
  Given the player opens a wave command requiring 5 slots
  And 3 slots are currently filled
  When the panel renders
  Then it shows 3/5 filled and indicates the command is not yet committed
  When the 5th slot fills and the next tick advances
  Then the panel shows the command as committed

Scenario: Narrative log surfaces tier-change events without exposing the raw meter
  Given SimEvents.suspicion_tier_changed fires with tier = Mobilized
  When HUD receives the event
  Then a log line appears ("A Hero Party is marching toward the fort.")
  And no numeric suspicion value is displayed anywhere in the HUD

Scenario: Time controls affect timing only, never simulation content
  Given the player presses pause
  When SimulationClock.pause() is called
  Then no CommandQueue or EconomySystem state changes as a result of that call alone
```

## Test-first order

1. Tick-interpolation math as a pure function (given prev state, current state,
   elapsed fraction → interpolated position) — tested headless, no render context
   needed, before wiring it into `LaneView`'s `_process`.
2. `HUD` slot-fill readout — subscribe to `CommandQueue`'s state, assert display logic
   against a fake/stub queue state before wiring to the real autoload.
3. Narrative log line selection — a pure mapping from `(tier, node)` to a log string,
   tested independent of the actual `RichTextLabel`/UI node.
4. Time control button wiring — assert each button calls the correct `SimulationClock`
   method and nothing else (guards the "timing only" scenario above).

## Notes / open questions

- Whatever GUT can drive without a real render context (the pure-function pieces above)
  gets automated coverage; anything requiring an actual visual frame (does it *look*
  right) is manual playtest, per the plan's Verification section — this is stated
  plainly rather than claimed as automated.
- `LaneView` and `HUD` both only ever read simulation state via `SimEvents` payloads or
  direct read-only queries (e.g. `CommandQueue.pending_commands` for display) — neither
  holds simulation state of its own that could drift from the source of truth.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into `presentation/lane_view.gd`
  ("tick interpolation and lane rendering") and `presentation/hud.gd` ("player-facing
  readouts and controls") — grouped in this spec because both consume the same event
  set and share the "read-only, never mutates sim state" constraint being specified.
- `ocp-extension-point`: a new `SimEvents` signal (e.g. a future Scout reveal event)
  plugs into `HUD` as a new subscriber method, not an edit to existing subscriber
  logic; a new narrative log line is a new entry in the tier→string mapping table, not
  a new `if` branch.
- `lsp-contract-scope`: not applicable — no shared contract with multiple
  implementations at this layer yet.
- `isp-fit`: `LaneView`'s public surface (other than its rendering pass) is empty — it
  only reacts to signals and read-only queries, no methods for other code to call.
  `HUD` similarly exposes no methods beyond its own signal handlers.
- `dip-direction`: this spec *is* the DIP boundary — every dependency here points from
  presentation into simulation (`SimEvents`, `CommandQueue`, read-only queries), never
  the reverse. The dependency-direction check (`ci/godot/`) should treat any import
  from a `sim/` file into a `presentation/` file as a hard failure.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decision 1 (real-time interpolation) and Decision 8
  (narrative log, not a meter); matches the Notes for the implementing agent's
  simulation/presentation separation directly.
- `commit-classification-plan`: `feat(presentation): add tick interpolation, wave UI,
  narrative log, and time controls`.

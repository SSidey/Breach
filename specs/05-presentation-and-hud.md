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
- `TickProgressIndicator` (added Phase 4, item 1) — shows progress toward the next
  tick, reusing `TickInterpolation.elapsed_fraction` exactly as `LaneView` already
  does for unit position. A read-only presentation widget, not a new HUD file per the
  original four-file split (Decision-tier reasoning: it consumes the same
  `SimEvents.tick_advanced`/`TickInterpolation` pair `LaneView` already does, not a
  new concern category), but its own file per `ai-first-organisation.md`'s
  one-concern-per-file rule.
- `TimeControls` speed/auto-pause (added Phase 4 follow-up, prompted directly by the
  user's own manual playtest) — `SimulationClock` gains two plain fields,
  `speed_multiplier: float` (scales real elapsed time before it's compared against
  `tick_duration_seconds`, so 2x/4x just means time passes faster, ticks still
  resolve one at a time — no simulation-logic change) and `auto_pause_each_tick: bool`
  (when true, `advance_tick()` calls `pause()` right after emitting
  `tick_advanced` — the "pause at each turn start" the user asked for, so the player
  can queue actions before manually resuming). Both are plain `@export` fields, not
  new public methods — `SimulationClock` was already at the 7-method ISP ceiling
  (see the `TickProgressIndicator` Notes above), and `tick_duration_seconds` already
  established the "policy-relevant field, not a method" pattern this follows.
  `TimeControls` gains two thin pass-through methods, `on_speed_selected(multiplier)`
  and `on_auto_pause_toggled(enabled)`, matching the existing "each button call touches
  exactly one `SimulationClock` field/method" scenario.

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

Scenario: Tick progress indicator reflects elapsed time toward the next tick
  Given 50% of the tick duration has elapsed in real time since the last tick
  When TickProgressIndicator renders the current frame
  Then it shows the same 0.5 fraction TickInterpolation.elapsed_fraction computes for
    that elapsed time and tick duration
  When SimEvents.tick_advanced fires
  Then the indicator resets to reflect zero elapsed time for the new tick

Scenario: Speed multiplier scales how fast real time counts toward a tick
  Given tick_duration_seconds = 2.0 and speed_multiplier = 2.0
  When advance_time(1.0) is called (1 real second elapsed)
  Then a full tick advances, as if 2.0 seconds had elapsed at 1x speed

Scenario: Auto-pause-each-tick pauses right after a tick fires
  Given auto_pause_each_tick is true
  When a tick advances, by either advance_time reaching the duration or
    skip_to_next_marker
  Then SimulationClock is paused immediately after tick_advanced is emitted
  And the player must press Resume before real time (or a further skip) advances
    another tick

Scenario: Auto-pause-each-tick does nothing when disabled
  Given auto_pause_each_tick is false (the class default)
  When a tick advances
  Then SimulationClock's paused state is unchanged by the tick itself
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
5. `TickProgressIndicator` construction (Phase 4, item 1) — a smoke test only, same
   honesty as `LaneView`/`ResourceBar`: its `_ready`/`_process`/`_draw` engine
   callbacks are deferred to manual playtest, since `TickInterpolation`'s math (the
   only pure logic involved) is already covered.
6. `SimulationClock.speed_multiplier`/`auto_pause_each_tick` (Phase 4 follow-up) — red
   before each field has any effect, mirroring the existing `tick_duration_seconds`/
   `pause`/`resume` test shape exactly.
7. `TimeControls.on_speed_selected`/`on_auto_pause_toggled` — same "exactly one field/
   method touched" assertion pattern as the existing pause/skip button tests.

## Notes / open questions

- Whatever GUT can drive without a real render context (the pure-function pieces above)
  gets automated coverage; anything requiring an actual visual frame (does it *look*
  right) is manual playtest, per the plan's Verification section — this is stated
  plainly rather than claimed as automated. `TickInterpolation`'s math is fully
  unit-tested; `LaneView` itself has only a construction smoke test (catches a real
  type-inference compile error hit while writing this item) plus a direct test of its
  position-snapshot logic — its `_ready`/`_process`/`_draw` engine callbacks are
  genuinely deferred to manual playtest once a running scene exists (item 11).
- `LaneView` and `HUD` both only ever read simulation state via `SimEvents` payloads or
  direct read-only queries (e.g. `CommandQueue.pending_commands` for display) — neither
  holds simulation state of its own that could drift from the source of truth.
- **`LaneView` self-subscribes to `SimEvents.tick_advanced` in `_ready()`** — unlike
  every `sim/` `RefCounted` component in this project (which take an explicit
  `on_x()` method instead, per Decision-tier reasoning in `specs/01`/`03`/`04`), a
  Node's scene-tree lifecycle handles signal disconnection automatically when it
  exits the tree, so the reference-lifetime leak that ruled out self-subscription for
  `RefCounted` classes doesn't apply to Nodes. Self-subscription here is the
  idiomatic Godot pattern, not an inconsistency with the `sim/` convention.
- **Scoped to this slice's actual content shape**: `LaneView` tracks at most one
  player wave and one moving blocker (Hero Party) as two named positions, not a
  generic multi-entity id scheme, since `specs/00`'s scripted scenario never has
  simultaneous waves. A future map needing that would first need `LaneSimulation` to
  hand out stable per-entity ids — not built ahead of that real need, same reasoning
  already applied to `ScriptedBeatWatcher` (`specs/06`).
- **`HUD` split into four separate files, not one**, per `ai-first-organisation.md`'s
  one-concern-per-file test: `resource_bar.gd`, `wave_command_panel.gd`,
  `narrative_log.gd`, `time_controls.gd`. The spec's original "HUD" framing was a
  conjunction of concerns ("resource bar, wave-command panel, narrative log, time
  controls") that would fail the single-noun-phrase test if built as one file —
  splitting also cleanly separates each piece's testable pure logic
  (`NarrativeLog.message_for_tier`, `WaveCommandPanel.status_text`) from its
  Node-based rendering, mirroring `LaneView`/`TickInterpolation`'s split.
- **Wave-command status shows pending/committed only, not a numeric "X/Y filled"
  count**, despite this spec's original scenario wanting the latter. Two real gaps,
  not one glossed-over decision: `CommandQueue.is_filled_check` (`specs/01`) is a
  boolean predicate by design, generic across whatever "filled" means per command
  type, with no numeric progress to read; and nothing in this slice's content
  authors a wave "size" for a count to be measured against in the first place. Adding
  numeric progress now would mean extending `CommandQueue`'s already-shipped contract
  speculatively, with no real wave-forming content yet to drive it. Revisit once such
  content exists (likely alongside real wave-command authoring, a later item).
- **`TickProgressIndicator` (Phase 4, item 1) has no automated coverage beyond a
  construction smoke test** — same disclosed limitation as `LaneView`: its `_draw()`
  needs a real render context to verify visually, deferred to manual playtest. It
  does not add a public elapsed-time getter to `SimulationClock` (already at the
  7-method ISP ceiling, `AI_First_Development_Kit/config/thresholds.yaml`) — instead
  it tracks its own `_elapsed_since_last_tick`, mirroring `LaneView`'s own
  self-subscribe-and-track pattern exactly rather than reading clock internals.
- **`auto_pause_each_tick` defaults to `false` on `SimulationClock` itself, not
  `true`** — despite the user asking for auto-pause to be the game's default
  behavior. This is a composition-root policy choice, not a class-level one: the
  class stays neutral (same reasoning `tick_duration_seconds` already established —
  it defaults to `1.0` but every real map overrides it from `MapDef`), and `main.gd`
  explicitly sets `auto_pause_each_tick = true` after constructing the clock. Flipping
  the class default instead would have silently changed several already-passing
  `SimulationClock` tests' assumptions (e.g. `test_resume_allows_auto_advance_again`
  asserts `is_paused()` is `false` after a tick advances) for a policy question that
  belongs to the game, not the timing primitive.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into `presentation/lane_view.gd`
  ("lane rendering"), `presentation/tick_interpolation.gd` ("tick-boundary
  interpolation math"), `presentation/resource_bar.gd` ("resource pool readout"),
  `presentation/wave_command_panel.gd` ("wave-command status readout"),
  `presentation/narrative_log.gd` ("tier-to-message mapping"),
  `presentation/time_controls.gd` ("play/pause and skip controls"), and (Phase 4, item
  1) `presentation/tick_progress_indicator.gd` ("tick progress readout") — seven
  files, each one noun phrase, no conjunction. Grouped in this one spec because they
  all consume the same event set and share the "read-only, never mutates sim state"
  constraint being specified, not because they're one file-level concern (see Notes
  above for why "HUD" as originally framed would have failed this same test).
- `ocp-extension-point`: a new `SimEvents` signal (e.g. a future Scout reveal event)
  plugs into `HUD` as a new subscriber method, not an edit to existing subscriber
  logic; a new narrative log line is a new entry in the tier→string mapping table, not
  a new `if` branch.
- `lsp-contract-scope`: not applicable — no shared contract with multiple
  implementations at this layer yet.
- `isp-fit`: revised from this spec's original anticipation — `LaneView` ended up with
  one real public method beyond its engine callbacks, `snap_to_current_tick()` (called
  by `TimeControls`, to avoid a visible partial-interpolation frame on skip-to-marker
  per this spec's own scenario), plus public `lane`/`tick_duration_seconds`/
  `node_spacing` fields the composition root sets — still a small, focused surface,
  just not literally zero. Of item 10's four files: `NarrativeLog` is one static
  method; `WaveCommandPanel` has `status_text()` plus its fields; `TimeControls` has
  `on_pause_pressed()`/`on_skip_pressed()` (now also `on_speed_selected()`/
  `on_auto_pause_toggled()`, 4 methods total) plus its fields; `ResourceBar` has no
  methods beyond its engine callbacks. `TickProgressIndicator` (Phase 4, item 1)
  likewise has no methods beyond its engine callbacks, just an exported
  `tick_duration_seconds` field. `SimulationClock` (`sim/`) gains
  `speed_multiplier`/`auto_pause_each_tick` as plain fields, not methods — still 7
  public methods, unchanged. All well under threshold.
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

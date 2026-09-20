---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Simulation Clock and Command Latching

## Purpose

Tick-boundary simulation timing, and the slot-filled/next-tick-only rule for player
commands. Implements Decisions 1 and 3 of the parent spec.

## Components introduced

- `SimulationClock` (autoload) — owns the tick counter and real-time auto-advance
  timer. One concern: *when* a tick happens. It has no knowledge of what a tick does.
- `CommandQueue` (autoload) — owns pending command slot-fill state and commits
  commands on the tick boundary `SimulationClock` announces. One concern: *whether and
  when* a queued command takes effect. It has no knowledge of what a command does once
  committed (that's the consuming system's job — `LaneSimulation`, `EconomySystem`,
  etc. — each owns applying its own committed commands).
- `SimEvents` (autoload, signal hub) — `tick_advanced(tick_number)`,
  `command_committed(command)`. Introduced here since this is the first spec that needs
  it; later specs add their own event names to the same hub rather than each owning a
  separate one (avoids a cross-cutting "helpers" file by giving every event a single,
  precisely-named signal rather than a generic `event_fired` payload).

## Scenarios (Given/When/Then)

```gherkin
Scenario: Auto-advance fires a tick after the configured duration
  Given SimulationClock is running with tick_duration_seconds = 2.0
  And 0 seconds have elapsed since the last tick
  When 2.0 seconds of real time elapse
  Then SimulationClock advances exactly one tick
  And SimEvents.tick_advanced is emitted with the new tick number

Scenario: Skip-to-marker forces an immediate tick regardless of elapsed time
  Given SimulationClock is running with tick_duration_seconds = 2.0
  And 0.1 seconds have elapsed since the last tick
  When skip_to_next_marker() is called
  Then SimulationClock advances exactly one tick immediately
  And the elapsed-time counter resets for the next tick

Scenario: Pausing stops auto-advance but not skip-to-marker
  Given SimulationClock is paused
  When 10 seconds of real time elapse
  Then no tick advances
  When skip_to_next_marker() is called while paused
  Then SimulationClock advances exactly one tick

Scenario: An under-filled command stays pending
  Given a wave command requiring 5 unit slots
  And only 3 slots are currently filled
  When SimulationClock advances a tick
  Then the command remains pending (not committed)
  And no command_committed event is emitted for it

Scenario: A fully-filled command commits only on the next tick, not on fill
  Given a wave command requiring 5 unit slots
  And the 5th slot is filled mid-tick
  When no tick has advanced yet
  Then the command remains pending
  When SimulationClock advances a tick
  Then the command commits and command_committed is emitted exactly once

Scenario: A pending command can be cancelled before it commits
  Given a wave command with slots partially filled
  When the command is cancelled
  Then it is removed from the pending buffer
  And it never commits, even on a later tick
```

## Test-first order

1. `SimulationClock`: pause/resume, manual `advance_tick()`, auto-advance timer,
   `skip_to_next_marker()` — each as its own red test before the corresponding method
   exists.
2. `SimEvents.tick_advanced` — assert emission and payload once `advance_tick()` exists.
3. `CommandQueue`: enqueue, slot-fill query, commit-on-tick (subscribed to
   `tick_advanced`), cancel — red before each behavior, green after.
4. Integration test: enqueue an under-filled command, advance two ticks, fill the last
   slot between them, advance a third tick — assert commit happens on the third tick
   only.

## Notes / open questions

- Tick duration and auto-advance-on/off are per-map config (`MapDef`, see
  `specs/06-map-content-p-f-F-c.md`), not hardcoded here.
- `CommandQueue` re-validates fill state every tick rather than caching a "ready" flag,
  so a slot that becomes unfilled again (e.g. a unit died before commit) correctly
  un-commits the command instead of committing with a stale count.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: "simulation timing and command latching" reads as one
  compound concern, not two unrelated ones — the timing *is* what latching commits
  against; splitting further would leave `CommandQueue` unable to state its own commit
  rule without reference to the clock. Each gets its own file at implementation time
  (`sim/simulation_clock.gd`, `sim/command_queue.gd`) — the one-file-per-concern rule
  applies to code, this spec just describes both together because they're one feature.
- `ocp-extension-point`: new command *types* (wave, future build/repair commands) plug
  in as new data shapes queued through the same `CommandQueue.enqueue()` — no edit to
  `CommandQueue` itself required per new command type.
- `lsp-contract-scope`: not yet applicable — no second implementation of a shared
  contract exists at this point (only one `SimulationClock`, one `CommandQueue`).
  Revisit if a test/headless clock implementation is added for CI.
- `isp-fit`: `SimulationClock`'s public surface is `advance_tick`, `pause`, `resume`,
  `skip_to_next_marker`, `is_paused` — 5 methods, under the 7-method ISP threshold.
  `CommandQueue`'s is `enqueue`, `cancel`, `is_filled`, `pending_commands` — 4 methods.
- `dip-direction`: both are simulation-layer autoloads with no dependency on
  presentation/rendering code — presentation depends on `SimEvents`, never the reverse.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decisions 1 and 3 directly; introduces no contradicting
  behavior.
- `commit-classification-plan`: implementation lands as `feat(sim): add simulation
  clock and command latching` (new capability, no prior behavior to fix/refactor).

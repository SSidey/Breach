---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Map Content: `P-f-F-c` Data and Scripted-Beat Wiring

## Purpose

This spec is `hybrid`: authoring the actual `.tres` data for the `P-f-F-c` map (policy
half — no test plan required, per `tdd-bdd-workflow.md`'s taxonomy) plus the small
generic watcher component that fires this map's scripted beats and win/loss condition
(tooling half — TDD applies).

## Policy half — data to author (no test plan required)

- `UnitDef` — Grem: cost (Food), hp, dmg, speed. Values ported from the HTML prototype
  as starting defaults (parent spec's instruction), recorded here once finalized.
- `NodeDef` × 4 — `P` (origin, not capturable), `f` (Farm: resource=Food, garrison=0,
  yield/decay/floor per `specs/03-resource-nodes-and-workers.md`), `F` (Fort: small
  garrison, structure-slot metadata for future Option 2), `c` (Core: origin, undefended
  per Decision 9).
- `ResponseUnitDef` × 2 — Messenger (fast, no combat stats needed — it only needs to
  reach `c` or be intercepted), Hero Party (combat stats tuned so the player's starting
  force alone cannot beat it, forcing the Ravage-for-a-horde beat — this is the one
  balance number this slice must get right for the scenario to actually teach what it's
  meant to teach).
- `MapDef` — the `P-f-F-c` graph, tick duration, Suspicion tier thresholds/decay rate,
  and the tier→unit table (Mobilized → Hero Party; Wary/Alarmed → none, per Decision 5).

## Tooling half — `ScriptedBeatWatcher` (TDD applies)

This map's win/loss rules (see Notes below for why this ended up as a small explicit
class rather than the generic data-driven rule-matcher originally sketched here):

| Watching for | Outcome |
|---|---|
| `on_hero_party_defeated()` called (a composition root correlates a `combat_resolved` event against `TaskForceDispatch`'s dispatched list first) | Not `SimEvents.victory` directly — the Hero Party's defeat alone doesn't win, reaching `c` afterward does. Records an internal `hero_party_defeated` flag instead. |
| `on_node_captured(node_index)` for `c` (`CORE`), gated on `hero_party_defeated` already being set | fires `SimEvents.victory` |
| `on_player_unit_count_changed(total_units)` reaches 0, regardless of `hero_party_defeated` | fires `SimEvents.defeat` |

### Scenarios (Given/When/Then)

```gherkin
Scenario: Reaching the Core before the Hero Party is defeated does not win
  Given the Hero Party has not yet been defeated
  When the player's force captures c
  Then no victory event fires
  (Not part of this slice's intended path, but must not silently "win" the scenario
   before its actual test — the Hero Party clash — has happened.)

Scenario: Defeating the Hero Party sets the flag but does not win by itself
  Given the Hero Party is defeated in combat
  When ScriptedBeatWatcher processes the combat_resolved event
  Then the internal hero_party_defeated flag is set
  And no victory event fires yet (Core has not been reached)

Scenario: Reaching the Core after the Hero Party is defeated wins
  Given hero_party_defeated is already set
  When the player's force captures c
  Then SimEvents.victory fires exactly once

Scenario: Losing the entire force before defeating the Hero Party loses
  Given hero_party_defeated is not set
  When the player's total unit count (roster + lane) reaches 0
  Then SimEvents.defeat fires exactly once

Scenario: Losing the entire force after already defeating the Hero Party does not
  also fire defeat (edge case, since capturing c is now the only remaining step)
  Given hero_party_defeated is set
  And the player's remaining force is wiped out before reaching c
  When the player's unit count reaches 0
  Then SimEvents.defeat still fires — the player must have surviving units to reach c,
    per Decision 9's "surviving horde" wording, so wipe-after-win-condition is still a
    loss, not an exception
```

### Test-first order

1. `ScriptedBeatWatcher` construction (`core_node_index`) — red before the component
   exists.
2. Flag-setting via `on_hero_party_defeated()`.
3. Gated victory on `on_node_captured(node_index)` + flag.
4. Defeat on unit-count-zero, both gated and ungated cases per the scenarios above.
5. Full integration replay of this slice's exact scripted path (shared with
   `specs/04-suspicion-and-response.md`'s integration test, extended through to the
   victory event).

## Notes / open questions

- **Built simpler than originally framed, disclosed here rather than silently
  narrowed:** the spec's "configured rules" language suggested a generic
  data-driven rule-matcher (`configure(rules)`); what was actually built is a small
  class with three explicit methods (`on_hero_party_defeated()`,
  `on_node_captured(node_index)`, `on_player_unit_count_changed(total_units)`) fixed
  to this map's specific win/loss shape. With exactly one map and three rules, a
  generic engine would be built for a genericity nothing yet exercises — the same
  "prove the abstraction against a real second case first" reasoning already applied
  elsewhere (e.g. the helper-promotion threshold). Revisit if/when a second map's
  ruleset needs to reuse this component with a genuinely different shape.
- `ScriptedBeatWatcher` does not self-subscribe to `SimEvents` (same `RefCounted`/
  long-lived-signal reasoning as every other `sim/` component this slice). A
  composition root (Phase 3 item 11) calls `on_hero_party_defeated()` explicitly once
  it's correlated a `combat_resolved` event against `TaskForceDispatch`'s own
  dispatched-list bookkeeping — `ScriptedBeatWatcher` itself never needs to identify
  *which* Task Force died, only that the (one, this map's) Hero Party did.
- `ScriptedBeatWatcher`'s state (the `hero_party_defeated` flag) is disjoint from
  `SuspicionSystem`/`TaskForceDispatch`'s own state — the systems compose (suspicion
  dispatches the Hero Party; this watcher reacts to its defeat) without either owning
  the other's data.
- Exact Hero Party combat stats are a balance question that can only really be
  confirmed by playtesting Phase 3, item 11 of the execution plan — record the chosen
  values and the reasoning (e.g. "starting force of 5 Grem loses, a Ravage-funded
  horde of 12 wins") once tuned, rather than guessing a number here and leaving it
  unverified.

- **Final authored values (Phase 3, item 11), with the reasoning per field:**
  - `Grem` (`content/units/grem.tres`): `cost_food=8, hp=20, dmg=6, speed=1.0` — ported
    directly from the prototype's `raider` unit (the closest basic-attacker analog;
    `speed` is unused by any current sim code, a placeholder for a future spatial
    pass per Decision 4).
  - `f` (Farm, `content/maps/p_f_F_c.tres`): `yield_food_per_tick=6` (prototype
    `HARVEST_RATE.food`), `decay_interval_ticks=5, decay_floor_food=2`,
    `ravage_yield_food=40` (prototype `RAVAGE_YIELD.food`).
  - `F` (Fort): `garrison_hp=26, garrison_dmg=6` (prototype `GARRISON_BASIC` — the
    closest analog to a "lightly defended" structure; the prototype's own
    `defFort`/`GARRISON_CRYSTAL` shapes don't apply to this slice's undecorated Fort),
    `dismantle_wood_yield=8, dismantle_stone_yield=5` (`DISMANTLE_YIELD`),
    `fortify_wood_cost=10, fortify_stone_cost=6` (`FORTIFY_COST`).
  - `Hero Party` (`content/response_units/hero_party.tres`): `hp=70, dmg=18` — the
    prototype's own `HERO_HP`/`HERO_DMG` constants, unchanged (Decision 11: port real
    values, don't invent tuned-to-taste ones).
  - `Messenger` (`content/response_units/messenger.tres`): `hp=0, dmg=0, speed=2.0` —
    authored as map data per this spec's policy half, but **not assigned to any
    `TaskForceDispatch` tier in this map** (see `specs/08`'s Notes for why: the
    "Messenger flees" narrative beat is realized as a two-step suspicion spike
    instead, since no Scout/Infiltrator exists yet to make a real interceptable
    Messenger meaningful — Decision 7). Exists in code/data as content, currently
    no-op, same treatment Decision 5 already gives Wary/Alarmed.
  - `MapDef`: `tick_duration_seconds=1.5`, `suspicion_tier_thresholds=[20, 45, 70, 90]`
    (Wary/Alarmed/Mobilized/Full Alert), `suspicion_decay_per_tick=2`.
  - **Map topology has five lane positions, not four**: `P, f, F,` an unnamed
    midpoint, `c`. See `specs/08`'s Notes — `F` and `c` being directly adjacent made
    `specs/02`'s "meet mid-lane" scenario physically impossible (a wave leaving `F`
    and a Hero Party leaving `c` would swap past each other in one tick without ever
    sharing a node). The midpoint is narratively inert, mechanically required.
  - **Verified end-to-end via a scripted (non-interactive) headless run** of the exact
    beat sequence against these real authored values: farm captured (3 starting
    Grem) → harvested to 44 food over 8 ticks → 5 Grem bought (40 food) → Fort
    destroyed outright (30 dmg ≥ 26 hp, zero casualties) → two suspicion spikes
    (Alarmed then Mobilized) → Hero Party dispatched → the two sides meet and hold at
    the midpoint (per the stalemate fix in `specs/08`) → **the base 5-Grem force
    alone wins the siege over three exchanges (70 hp ÷ 30 dmg/tick), losing one unit
    to retaliation** → the survivors reach the Core → victory. **Honest disclosure,
    not silently tuned away:** with these numbers the Ravage beat is a strong,
    lower-risk accelerant (a bigger horde finishes the Hero Party in fewer exchanges
    with fewer losses) rather than a strictly mandatory precondition for winning —
    the spec's framing ("not assumed large enough to beat outright") holds (no
    single exchange kills the Hero Party), but a patient player can grind it out
    unreinforced. This is a genuine playtest-only finding, left for the user's own
    manual pass to confirm whether it needs retuning (e.g. raising Hero Party `dmg`
    so a full-hp Grem dies per exchange instead of surviving partially, forcing
    faster losses) rather than the agent unilaterally re-tuning numbers to force a
    specific outcome without a human playtest to confirm it's the right one.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: the policy half's purpose is "map content data" (one noun
  phrase); the tooling half's is "scripted-beat watching" — implemented as
  `content/maps/p_f_F_c.tres` (+ sibling `.tres` resources) and
  `sim/scripted_beat_watcher.gd` respectively, kept in separate files despite sharing
  one spec because the spec-type split (policy vs. tooling) already forces the
  distinction at review time.
- `ocp-extension-point`: revised from this spec's original anticipation — with the
  simpler, explicit-methods design actually built (see Notes), a new map's different
  win/loss shape would currently mean a new/edited class, not a data-only change. This
  is an honest trade against the "prove genericity against a real second case first"
  reasoning: acceptable for one map, worth re-examining the moment a second map's
  ruleset actually needs to compose with this component.
- `lsp-contract-scope`: not applicable — one `ScriptedBeatWatcher`, no shared
  base/interface, no second implementation.
- `isp-fit`: `ScriptedBeatWatcher`'s public surface is `hero_party_defeated()` (query),
  `on_hero_party_defeated()`, `on_node_captured(node_index)`,
  `on_player_unit_count_changed(total_units)` — 4 methods, under threshold.
- `dip-direction`: simulation-layer; reacts to `SimEvents`, emits `SimEvents.victory`/
  `defeat`; presentation (`specs/05-presentation-and-hud.md`) reacts to those in turn
  to show a win/loss screen, never the reverse.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — policy half (data) has no test plan; tooling half
  (`ScriptedBeatWatcher`) does, per `tdd-bdd-workflow.md`.
- `tdd-plan-present`: present for the tooling half only, as required.
- `no-drift`: implements parent Decision 9 exactly (Core-arrival-after-Hero-Party-
  defeat as the win trigger, no Core combat resolution required).
- `commit-classification-plan`: data lands as `feat(content): author P-f-F-c map data`;
  the watcher component lands as `feat(sim): add scripted beat watcher` — two commits,
  since one is content-authoring and the other is new behavior, per the
  type-vs-diff test in `templates/commit-message.md`.

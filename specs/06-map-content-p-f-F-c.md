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

A generic, data-driven component: watches `SimEvents` for a configured set of
`(event, condition) → outcome` rules and fires the outcome once. This map's specific
rules (not hardcoded into the component):

| Watching for | Outcome |
|---|---|
| `combat_resolved` where the loser is this map's Hero Party Task Force | fire `SimEvents.victory` is *not* correct here — see scenario below; the Hero Party's defeat alone doesn't win, reaching `c` afterward does. Record as an internal "hero_party_defeated" flag instead. |
| `node_captured` for `c`, gated on the "hero_party_defeated" flag already being set | fire `SimEvents.victory` |
| player's total unit count reaches 0 while "hero_party_defeated" is not yet set | fire `SimEvents.defeat` |

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

1. `ScriptedBeatWatcher` construction from a plain rule list (no map-specific logic
   baked into the component) — red before the component exists.
2. Flag-setting on `combat_resolved` matching a configured Task Force id.
3. Gated victory on `node_captured` + flag.
4. Defeat on unit-count-zero, both gated and ungated cases per the scenarios above.
5. Full integration replay of this slice's exact scripted path (shared with
   `specs/04-suspicion-and-response.md`'s integration test, extended through to the
   victory event).

## Notes / open questions

- `ScriptedBeatWatcher`'s rule list is this map's own `MapDef` data, not a second
  hardcoded copy of the logic in `specs/04-suspicion-and-response.md` — the two specs
  compose (suspicion dispatches the Hero Party; this watcher reacts to its defeat) but
  own disjoint state.
- Exact Hero Party combat stats are a balance question that can only really be
  confirmed by playtesting Phase 3, item 11 of the execution plan — record the chosen
  values and the reasoning (e.g. "starting force of 5 Grem loses, a Ravage-funded
  horde of 12 wins") once tuned, rather than guessing a number here and leaving it
  unverified.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: the policy half's purpose is "map content data" (one noun
  phrase); the tooling half's is "scripted-beat watching" — implemented as
  `content/maps/p_f_F_c.tres` (+ sibling `.tres` resources) and
  `sim/scripted_beat_watcher.gd` respectively, kept in separate files despite sharing
  one spec because the spec-type split (policy vs. tooling) already forces the
  distinction at review time.
- `ocp-extension-point`: a new map's beats are a new rule list passed into a new
  `ScriptedBeatWatcher` instance — no edit to the component itself.
- `lsp-contract-scope`: not applicable yet — one `ScriptedBeatWatcher` instance in this
  slice. If a second map's watcher instance is added, both must already satisfy the
  same rule-list contract by construction (it's data-driven, not subclassed), so no
  separate contract test is needed unless a genuine second *implementation* (not
  instance) appears.
- `isp-fit`: `ScriptedBeatWatcher`'s public surface is `configure(rules)` and its
  `SimEvents` subscriptions (not called by other code) — effectively 1 method.
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

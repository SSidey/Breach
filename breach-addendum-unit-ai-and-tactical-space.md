# Breach — Design Addendum: Unit AI and Tactical Space

*Addendum to "Breach — Reverse Tower Defense: Design Spec" and "Design Addendum: Unified Combat Resolution." Assumes the Combatant/Encounter model from the latter.*

## Unit AI: a priority-layered behavior stack

Not full per-unit autonomy — a small decision layer sitting on top of the centralized sim, which stays cheap regardless of army size because it only needs to run once per round per unit, not continuously:

- **Per-unit layer** decides intent each round: advance, hold and fight, retreat.
- **Encounter layer** (prior addendum) decides outcome when two proposed intents collide.

The unit AI never touches combat math — it proposes an action, the existing resolver handles what happens.

**The stack, highest priority first, hard-gated (not just weighted — a lower tier can never outscore a higher one):**

1. **Rout** — morale below threshold. Checked first, short-circuits everything below.
2. **Local command override** — a Commander Combatant present in the same Encounter can issue a temporary order that supersedes the unit's standing order for as long as that Commander is alive and present.
3. **Standing order** — the default dispatched task (e.g. "build a wall from the core").
4. **Idle/default** — nothing else applies.

**Formalize "order" as one small shared shape**, since it's the same concept in three places already in the spec:

```
Order { priority, source: Core | Commander | Detection, directive, expires_when }
```

A standing order's source is the Core, persisting until complete. A Commander's override's source is that specific Combatant, expiring the moment the Commander dies or leaves the Encounter — the unit reverts to whatever's next in the stack automatically, no special-case code needed for "the skirmish ends, they go back to building the wall."

This retroactively unifies two things already in the spec as instances of the same pattern: a **Task Force** *is* a standing order; a garrison's **sortie** trigger *is* a mid-tier order sourced from detection rather than a person.

## Event-driven reactivity within a round

A round is an **ordered sequence of discrete events**, not continuous time — true continuous simulation would undo the determinism and debuggability round-based resolution buys. But a round made of events, where processing one can generate more, gets the reactive feel without giving that up:

- A unit posts an "entered node" event while moving.
- If that node has hostiles, it immediately opens an Encounter — interrupting the rest of that unit's move for the round — rather than waiting for a separate global combat phase. This is "a unit enters combat midway through its travel."
- Combat resolving posts "damage taken" events; if that drops morale under threshold, it posts a "routing" event immediately.
- A rout event can free up a node, unblocking some other unit's movement — a new event, potentially cascading further within the same round.

**The priority stack is already the reaction function.** An event doesn't need bespoke handling per type — it just means "this unit's situation changed, re-run its stack." The event queue's only job is deciding *when* to trigger that re-check.

**Two things worth nailing down deliberately, since ambiguity here causes the subtle sim bugs later:**
- A **stable, explicit tiebreak** for same-round simultaneity (e.g. defender events before attacker's, or by fixed Combatant ID) — pick one, document it, so results are reproducible rather than depending on data-structure iteration order.
- A **hard cap on cascade passes per round** (e.g. 5) as a safety valve against a pathological chain reacting forever.

Reference for this pattern: Total War's real-time battles work this way — routing units fleeing through the line, disrupting others, who then react. Same interrupt-driven idea, continuous engine instead of round-based.

Presentation implication: the sim itself only needs to resolve at discrete event points — "midway through travel" only needs to *read* as continuous, via the animation layer interpolating between two real states. No physics-level continuous movement required in the sim to get that look.

## Two-tier spatial model: discrete strategic graph, continuous tactical space

The node/lane graph stays exactly as specced — map authoring, ownership, capture, pathing, economy, suspicion all genuinely want to be discrete, and nothing here threatens that. What changes is scope: a node is where a unit is heading or holding, not necessarily where a fight resolves pixel-for-pixel.

When an Encounter triggers, it can spin up its own small **continuous local space** — real positions, real distances, real archer-vs-melee spacing — that exists only for the Encounter's duration and collapses back to a single node-level result (who's where, who's dead, who routed) once resolved. Discrete strategic graph always; continuous tactical space only while a fight is actually live. Same shape as a campaign map vs. a battle map (Total War, again).

**Accuracy is a genuine either/or, not a detail:**
- **Roll first, animate second.** Resolve hit/miss as probability against the existing damage math, then pick an animation that sells the outcome. Consistent with everything else already decided (deterministic, round-based), and slots in as one more sub-step of the Encounter's damage-computation stage — no structural change.
- **Real geometry decides it.** A unit fires at a target's actual position in that local space; it can genuinely miss because of where things are. Richer — flanking and positioning become real levers — but real added scope (projectile speed, target-leading, collision).

Recommend: roll-first-animate-second as the default everywhere, real geometry reserved for the unit types where positioning is the actual point (archers/ranged skirmishers) rather than committing every unit to full physical simulation.

## Long-range structure attacks fit this without new mechanics

A fort's ballista opening fire on an approaching force well outside melee range is already covered by `engage_range` from the combat-depth addendum — a Structure Combatant with a large `engage_range` participates in the Encounter engagement check against a target node without needing adjacency. No new stat, no new system.

**Correction to the assumption above:** it claimed range was graph-distance along a Structure's own lane only, and used that to argue a turret could never reach another lane. That was an assumption stated as settled without confirming it against actual intent — it isn't right. Corrected model:

**Range is spatial (grid) distance, not just along-lane hops.** Every node across every lane gets a shared **(row, column) grid coordinate**, in addition to its existing per-lane linear index (which still governs movement/pathing, unchanged). A Structure's `engage_range` is measured against that grid coordinate. In a 3-lane board where lanes occupy rows 1/3/5 (rows 2/4 are pure spacing, not traversable), a turret at row 3 with `engage_range: 3` can validly target nodes on rows 1 and 5 too, not only its own row. Default metric: Chebyshev distance (`max(|Δrow|, |Δcol|)`) — the standard "range N" measure in grid tactics games, and simpler to reason about and render as a range indicator than Euclidean, though Euclidean is a fine alternative if a rounder range shape matters more than that simplicity.

**This means an Encounter is no longer necessarily single-location.** Melee still requires colocation (range 0 forces the same node), but a ranged Encounter now has a **source location and a target location**, connected by "within range" rather than "at the same node."

**One open decision this creates**: can a Structure with multiple valid targets across lanes fire at more than one per round, or must it pick one? Recommend single-target-per-round for v1 (prioritized the same way the defender AI already prioritizes threats elsewhere in the spec), with multi-target as a later Metal-funded upgrade tier — consistent with how Fort upgrades already work in the base spec.

**Presentation — this is exactly what a dual-viewport view handles, as a natural extension of the Inspector Viewport pattern from the art discussion rather than a new system.** A ranged Encounter with separate source and target locations gets *two* Inspector Viewports live at once — one on the firing Structure, one on the advancing force. As the target closes the distance and its location converges with the Structure's, the two locations become one, and the two viewports collapse into the single shared one already used for melee — no explicit "merge" logic required, since at that point there's genuinely only one location left to look at.

**Long-range fire still stays in the cheap roll-first tier by default** (unaffected by this correction) — a stationary structure firing across the grid at a force mostly following its lane's track doesn't need real projectile/positioning simulation the way close-range archer-vs-target spacing does.

**Further refinement: range checks must use actual position along the path, not the node it's snapped to.** Node-to-node grid distance decides *whether a Structure's range could ever reach a given lane at all* — but *when* an engagement actually fires needs to be evaluated against where a moving cluster genuinely is during its transit, not only its start/end node for that round.

Concretely: a moving cluster's position for a round is a parametric path — interpolated between its start and end node's grid coordinates — not a single discrete point. A ranged Structure's engagement check becomes a path-vs-range-area intersection test (a line segment against a circle, or against a Chebyshev square, matching whichever range metric was chosen above) rather than a point-in-range check evaluated only at round boundaries. This is cheap, ordinary geometry, not a simulation cost increase, and it adds one new trigger to the existing reactive event queue: **"entered threat radius,"** firing at the point the path first crosses into range — alongside the existing "entered node" trigger, feeding the same priority-stack re-evaluation already specced. Only the trigger condition is new, not the reaction to it.

**Scope note, consistent with the earlier tiering decision:** this path check runs on one representative position per cluster — it doesn't require every individual unit inside a cluster to carry its own independent position at the strategic layer. That's exactly what the richer continuous local space (already specced, reserved for unit types where positioning is the point) is for once an Encounter actually opens: the cluster-level path decides *if* a fight starts; the Encounter's own local space decides how it looks and plays out once it has.

## Note for implementation

The only genuinely new runtime system here is the priority stack + event queue — everything else (long-range fire, the strategic/tactical split) is existing primitives (`engage_range`, Combatant, Encounter) applied correctly rather than new code. Build the unit AI to consume the same Combatant/Encounter data the rest of combat already uses; it should never become a second, parallel decision system.

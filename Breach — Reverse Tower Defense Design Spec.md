# Breach — Reverse Tower Defense: Design Spec

2026-09-19 · @Someone

A reverse tower-defense game: the player is the aggressor, building hordes to break a defended core while the defense builds, upgrades, and reacts. Six rounds of a browser prototype (HTML/JS) validated the core loop; this spec consolidates that plus the next layer of systems for a full build in Godot.

## What's already validated

Six iterations of a single-file HTML/JS prototype proved out the core loop without needing an engine. Carry these mechanics forward as-is; they've been played and tuned:

- **Round-based planning, not real-time clicking.** Player reinforces lanes, then advances a round; all combat resolves at once. Keep this for v1 even if presentation later adds animation on top (see Presentation section).
- **Lanes as tracks, not an open grid.** Early open-grid capture read as "dots and boxes"; fixed lanes with nodes read as a real front line.
- **Reinforcements travel.** Units spawn at home and march up over rounds rather than appearing at the front, so a hero party can catch a straggling group before it merges with the main force.
- **Multi-round construction.** Defender forts take rounds to build/upgrade, and are fragile while under construction — rushing an unfinished fort is a real option.
- **Capture is a choice, not an auto-resolve.** Destroying a fort lets the player Fortify (forward defense, costs Wood/Stone) or Dismantle (salvage, free). Breaking a resource garrison lets the player Harvest (steady rate) or Ravage (lump sum, node exhausted after).
- **Ground must be held.** Anything captured but left undefended (no fortification, no harvester escort) reverts to the defender if an enemy hero party walks through it unopposed. This is the current "defender regains resources" mechanic; the suspicion system below generalizes it further.
- **Alarm/messenger.** Grinding on a fort or garrison risks a messenger fleeing to raise the alarm (rising % chance per round of contact); Scout units reveal the otherwise-hidden risk; Infiltrator units bypass structures entirely and can intercept a messenger if positioned ahead of it. This is the seed of the suspicion system in the next section — it should be generalized rather than replaced.

Open gaps the prototype does not cover, carried into the sections below: only one fixed hero-party archetype, no player-built towers, no meta-progression between maps, and combat resolves invisibly rather than animating.

## Enemy threat model: suspicion, not a timer

Replace the fixed hero-party interval entirely with a single **Core Suspicion** meter (0–100) that generalizes the alarm/messenger system already built. Two independent inputs raise it:

- **Silence.** Each settlement/node normally reports resources back to the core on a schedule. No report for N rounds (tunable per node) adds suspicion — this is what happens when the player harvests, dismantles, or otherwise disrupts a node without covering it.
- **Detection.** A messenger that reaches the core, or a player unit spotted tampering with a structure, adds a larger, immediate spike.

Suspicion decays slowly when nothing is wrong. Thresholds gate an escalating response — each tier's response, if it doesn't return or report back within its own window, adds suspicion again and triggers the next tier:

```mermaid
flowchart LR
  A[Calm] -->|silence or minor detection| B[Wary: send Guard]
  B -->|guard doesn't return| C[Alarmed: send Militia]
  C -->|militia doesn't return| D[Mobilized: send Hero Party]
  D -->|hero doesn't return| E[Full Alert: Hero Party + patrols on all lanes]
  E -.decays over time.-> A
  B -.decays over time.-> A
  C -.decays over time.-> A
```

Design notes:

- Each tier's unit is a real, defeatable entity, not a countdown — stopping a Guard before it reports resets that lane's suspicion growth, same as intercepting a messenger today.
- Full Alert should scale response *per lane* by how much pressure the player is applying there, not uniformly — the lane where the player is heaviest gets patrols and reinforced garrisons; quiet lanes stay calmer.
- This directly answers the "can't just sit on income" requirement: even zero combat activity eventually raises suspicion through silence, so turtling on captured resources without holding them isn't free.
- Scout and Infiltrator keep their current jobs under this model — Scout reveals the suspicion number, Infiltrator can intercept any tier's response unit, not just messengers.

## Core roster and Task Force dispatch

Generalize builders, repair crews, and every suspicion-tier response unit (Guard/Militia/Hero) into one system: the core has a finite **roster** of units by type, and any dispatch — build, repair, or respond — pulls a **Task Force** out of that roster rather than conjuring a unit from an abstract currency.

- **Roster, not just gold.** The core tracks a count per unit type (e.g. 3 Builders, 6 Guards, 2 Heroes available). Spending supplies still gates *training* new roster members over time; dispatch is then gated by *availability*, not just affordability. A core that has sent all its Builders out has none to send, even if it can afford more — until one returns or a new one finishes training.
- **One dispatch model, several purposes.** A Task Force is `{composition, purpose, destination}`: `{1 Builder → construct, empty slot X}`, `{1 Builder → repair, damaged fort Y}`, `{2 Guards → investigate, silent settlement Z}`, `{1 Hero → respond, alarm on lane W}` all use the same travel/arrival/return logic already built for hero parties in the prototype.
- **Visible and interceptable.** Every Task Force travels as a real, visible entity on its lane (like the current hero party token), so Infiltrator/ambush counterplay applies uniformly — stopping a Builder before it reaches an empty slot prevents that tower from ever going up, exactly as intercepting a messenger prevents an alarm.
- **Return to roster.** A Task Force that completes its task (finishes building, finishes repairing) returns to the roster and becomes available again, rather than being consumed — consumption only happens if the Task Force is destroyed en route or at its destination.

This turns "the defender builds a tower" from a currency-gated timer (current prototype) into a logistics problem with its own attack surface: a player who keeps killing Builders on the road starves the defender's ability to fill empty slots at all, independent of how much gold/supplies it has stockpiled.

## Economy: five resources, with decay

Keep the five-resource split validated in the prototype, and add depletion so holding a node isn't a permanent, static gain:

| Resource | Source | Spent on |
| --- | --- | --- |
| Food | Small baseline trickle + Food nodes | Raising units |
| Wood | Timber nodes, dismantling forts | Basic units, structures |
| Stone | Dismantling forts | Basic structures |
| Metal | Ore nodes | Fort/tower upgrades |
| Crystal | Ravaging any node (rare, one-time) | Unit upgrades |

New rule: a **Harvester's** yield tapers over time (e.g. –10% every N rounds) rather than staying flat forever, floors at some minimum trickle. This does two things: it stops "set up three harvesters and coast" from being the dominant strategy, and it makes Ravage (lump sum, node destroyed) a genuinely competitive choice late in a node's life rather than only an early rush option.

Open question: does a depleted Harvester become ravageable for a smaller final lump, or just fall to its floor rate permanently? Recommend the latter for simplicity in v1.

## Player meta-layer: the Lair

Before sending the next wave, the camera pulls back to the Lair — a persistent, cross-map screen where units are bred/fused and the tech tree lives. This is the meta-progression the current prototype has none of.

**Fusion, not a flat roster.** Base unit: Grem (cheap, Food only). Combinations produce new units:

```mermaid
flowchart TD
  Grem -->|2 Grem + Wood| Brute
  Grem -->|1 Grem + Food, Lair upgrade unlocked| Scout
  Grem -->|1 Grem + Food + Wood, Lair upgrade unlocked| Infiltrator
  Brute -->|2 Brute + Metal, tech unlocked| Warbeast
  Scout +.-> Infiltrator
```

- A recipe needs both the input units (consumed) and a resource cost — mirrors "2 Grem + Y Food = Brute" as specified.
- Some recipes are gated behind a Lair upgrade (a one-time unlock, paid for with resources brought back from maps) rather than being available from turn one — this is the tech tree.
- Resources carried back from a completed map convert into Lair currency at some exchange rate (needs tuning) rather than being spent directly, so map performance feeds the meta-layer without letting a single great map trivialize it.

**Open question:** does fusion happen only in the Lair between maps, or can it happen mid-map at a captured Fort (turning "fortify" into "fortify + garrison a fused unit there")? Recommend Lair-only for v1 — mid-map fusion is a natural v2 add once the base loop is proven.

## Structures and combat: the scope-defining decision

Two genuinely different games are on the table here, and this needs a deliberate choice before Godot work starts:

1. **Abstracted capture (current prototype).** Forts/settlements are single nodes on a lane with hp and a garrison. Breaking one is one combat resolution, not a siege. Player towers don't exist — the player's "defense" is Fortify/Harvester placement on captured ground.
2. **Spatial tower defense (the new ask).** Settlements/forts are physical obstacles that bar a path; the player routes units around or through them, needs dedicated siege/anti-structure units to bring one down, and can place their own towers on ground they hold, mirroring a standard TD's tower-placement grid.

Option 2 is the more classic and probably more satisfying tower-defense feel, but it's a materially bigger build: it needs real pathfinding around obstacles, a siege-unit role that doesn't exist yet, a tower-placement UI on captured ground, and rebalancing most of the numbers in this doc. Recommend committing to Option 2 as the target for the Godot build (it's clearly where the design is heading), but implementing it in two passes: ship lane-based structures first (fast, reuses everything validated in the prototype) and layer in free-form placement once the core loop is confirmed fun in 3D/2D space.

**Anti-structure requirement:** if towers can bar a path outright, at least one unit type must exist purely to bring them down (a Sapper/Siege unit — high damage to structures, weak against units), so the player always has an answer to "the road is walled off."

Every map also predefines its full set of structure slots — tower foundations and other ancillary sites — up front. A scenario decides per slot whether it starts occupied (an existing fort/settlement) or empty; empty slots aren't necessarily permanent gaps, since the core can dispatch Builders to construct on them later (see Core roster and Task Force dispatch, below). This is the same `slot` node type already in the prototype, just formalized as map-authoring data rather than always-empty-until-AI-fills-it.

## Map structure and campaign progression

Build 2–3 hand-authored maps before any map-creator tooling — prove the campaign feel first, generalize into a tool second.

**Worked early map (from your example):** one track, one loosely-defended farm, one lightly-defended fort.

| Beat | What happens | Teaches |
| --- | --- | --- |
| 1 | Player overruns the farm (weak/no garrison) | Basic movement, Food income |
| 2 | Player attacks the loosely-defended fort | Combat resolution, fort destroyed → Fortify/Dismantle choice |
| 3 | The fort's attack sends a messenger | First taste of the suspicion system |
| 4 | Warning: hero party incoming | Player must react, not just advance |
| 5 | Player ravages the farmland for a burst of Food | Ravage vs Harvest becomes a real tradeoff under pressure |

This is a clean template for a map-design pattern: **each map should teach exactly one new pressure by forcing a choice under a timer**, not introduce new mechanics passively. Later maps compose already-taught pressures (multiple suspicion sources, tighter timers, harder garrisons) rather than only adding new unit/structure types.

**Map-creator tool**, once justified by 5+ hand-built maps: needs at minimum a lane/node graph editor, garrison/resource placement, and a way to author scripted beats (like the messenger warning above) without code.

## Presentation: keep round-resolution, add animation on top

Keep the underlying simulation round-based (it's simulation-friendly, deterministic, and already balanced) but stop resolving it invisibly. When a round advances:

- Animate units marching, clashing, and structures taking damage over a few seconds rather than snapping to the new state.
- Surface structure hp, and enemy unit composition **only where scouted** — this is Scout's second job beyond alarm-risk: without one, show a fort as "a fort" with an hp bar only; with one, show its actual level/garrison type.
- Stealth units (Infiltrator and future espionage units) should be invisible to the animation/combat log entirely unless detected — no death animation, no log line — and should return to an idle state at the Lair once their task (intercept, sabotage) completes, rather than being consumed. Hero parties gaining "see invisibility" on harder difficulties is a clean way to make later maps meaningfully harder without new mechanics.

This is presentation layered on the existing math, not a rewrite of the round resolution — the Godot build can start with instant resolution (matching the prototype) and add animation as a second pass once the simulation itself is confirmed correct.

## Open design questions

- [ ] Abstracted lane combat vs full spatial tower placement (Structures section) — the single biggest scope decision.
- [ ] One overlord/playstyle for v1, or design the unit data now for multiple armies later? Recommend one now, data-driven for later.
- [ ] Does a depleted Harvester become ravageable for a reduced lump, or just floor at a low trickle permanently?
- [ ] Does fusion happen only in the Lair, or also mid-map at a fortified position?
- [ ] Exchange rate for map resources → Lair currency — needs actual numbers once Lair economy is drafted.
- [ ] Research/goals per map (mentioned but not yet specced): is this a fixed unlock tree per map, or player-chosen objectives within a map?
- [ ] Suspicion decay rate and per-tier response-unit stats — needs a tuning pass once the state machine is implemented.
- [ ] Does the map-creator tool get scoped at all for v1, or purely a post-launch investment (recommended)?
- [ ] Roster sizes and training rates per unit type (Builder/Guard/Militia/Hero) — needs tuning once the Task Force system is implemented.

## Notes for the implementing agent (Godot)

- **Data-driven units and recipes.** Units, fusion recipes, fort/tower stats, and map layouts should all be Resource (`.tres`) definitions, not hardcoded scenes — this is what makes "one overlord now, more later" and "map-creator eventually" affordable.
- **Separate simulation from presentation.** A pure-logic autoload (round resolution, suspicion, economy) that emits events; a separate scene tree consumes those events to animate. This mirrors the prototype's `advanceRound()` function directly and keeps the simulation testable headlessly.
- **State machine for enemy AI**, matching the suspicion escalation diagram above — each tier is a state with its own entry action (spawn response unit) and transition conditions (unit returns / doesn't / times out).
- **Fog-of-war as a data flag, not a rendering trick.** Each structure/unit has a `revealed: bool` (or `revealed_until: round`) that Scout presence sets; rendering just checks the flag. Keeps stealth and hero "see invisibility" trivial to add later as another reveal condition.
- **Port the prototype's balance numbers as starting defaults** (unit costs, fort hp/dmg, alarm increment, hero stats) rather than re-deriving them — they've already had six rounds of tuning.
- Treat the live HTML prototype as the reference implementation for exact current behavior when anything in this doc is ambiguous — it's the ground truth for what's been validated.

# Breach — Design Addendum: Calendar, Weather, and World Modifiers

*Addendum to the base spec, "Unified Combat Resolution," and "Unit AI and Tactical Space." Assumes the Combatant/Encounter model, node grid coordinates, and the continuous cluster-path model from the latter.*

## Tick = round, calendar derived, not simulated

One tick is one round — no second clock to keep in sync. Calendar state is *derived* from the existing round counter, not separately simulated:

- Starting cadence: **4 ticks/day** (named Dawn / Day / Dusk / Night, not just numbered — gives dawn/dusk transition texture for free rather than a hard day/night toggle), **3 days/season**. `phase = PHASES[round % 4]`, `day = (round // 4) % days_per_season`.
- **Season is per-map and authored, not persistent across the campaign, for v1.** A mission is simply tagged "early winter" and lives entirely within it. Cross-map persistent seasons are the richer version — real added state (does revisiting a map reflect elapsed time, does the Lair need a calendar too) — worth deferring for the same reason multi-army playstyles and the live map-creator were deferred earlier.
- **Full moon is a specific calendar date** (e.g. the last Night tick of a season), not a random roll — consistent with the rest of this spec's general aversion to unmotivated randomness; combat is the one place probability is welcome.

## Calendar override modes (map authoring)

Every calendar dimension (phase, day, season, moon) supports three modes, so a map can express everything from "normal cycling" to a hard static override without bespoke logic per case:

| Mode | Behavior | Example |
| --- | --- | --- |
| Derived (default) | Computed from round count via the standard formula | Ordinary day/night cycling |
| Offset | Same formula, seeded from an authored starting value | "Start on a full moon," then cycle normally from there |
| Pinned | Locked to one value for the whole map, ignores round count entirely | "Eternal night" |

## WorldContext: persistent world state vs. per-unit modifiers

Two different things, kept deliberately separate:

- **Persistent world state** — current calendar config, global weather, the list of currently-active localized zones. This genuinely persists and accumulates across rounds, managed centrally as one `WorldContext` object updated once per round.
- **Per-unit effective modifiers** — never stored on a Combatant. Recomputed fresh every round from (Combatant type + current `WorldContext` + Combatant's current position). A torch effect or a chill from standing in snow shouldn't "stick" once the condition that caused it is no longer true.

This adds exactly one new step to the Encounter procedure already specced: **resolve effective stats**, run before engagement checks, folding any currently-applicable modifiers onto a Combatant's base stats for that round only.

## Scripted per-round events (map authoring)

A map's authoring data gets a **Map Script**: an ordered list of `{trigger, action}` entries, evaluated each round.

```
{ trigger: { round: 3 },
  action: spawn_zone,
  zone: { type: "tornado", center: {x, y}, radius: 2, duration: 4,
          modifiers: [...] } }
```

Actions cover `spawn_zone`, `remove_zone`, and `set_calendar_override` (any of the three modes above, applied mid-map if wanted). This isn't a new authoring concept — it's the same pattern as the base spec's preset structure slots and preset weather, generalized into one authored timeline instead of several separate static lists.

## Zone application timing: continuous position, tile-blanket as the cheap case

A unit gains a zone's modifier the moment its position enters that zone — this reuses the exact path-vs-area intersection check already specced for a ranged Structure's "entered threat radius" trigger, just applied to weather/effect zones instead of turret range.

Zone boundaries come in two forms, with different costs:

- **`tiles: [node ids]`** — a blanket assignment to whole tiles. Cheap: a unit's current/destination node is either in the list or it isn't, no geometry required. The right default for most weather.
- **`shape: {center, radius}`** (or polygon) — precise, doesn't align to tile boundaries (the tornado example). Requires the full continuous path-intersection test, exactly as already specced for threat radius.

Default behavior is symmetric and non-persistent: a modifier applies exactly while a unit's position is within the zone and is removed the instant it exits — no lingering effect unless a specific modifier explicitly opts into a linger duration.

## Mapping the original examples onto this

All of these are the same mechanism (a modifier, gated on a `WorldContext` condition, resolved fresh each round) — no example below needs its own system:

- **Torches/sight** → reuses the suspicion system's detection range. No torch at Night reduces it; carrying one restores it but raises the carrier's own detectability.
- **Vampiric weakness** → a Day-phase stat penalty on that Combatant type.
- **Werewolf bonus** → gated specifically on the Full Moon date, not "Night" generally.
- **Fear/morale** → a Night-phase morale penalty, layered onto the per-unit-type morale floors already specced (hits Peasants harder than Knights for free).
- **Hot/cold** → season-gated stat deltas.
- **Seasonal food/timber** → a season multiplier on the existing `HARVEST_RATE` table from the economy addendum.

## Note for implementation

Entirely additive: one `WorldContext` object updated once per round, one new "resolve effective stats" step in the already-specced Encounter procedure, and a Map Script list for authored timeline events. No changes to existing Combatant fields, movement, or economy mechanics — everything here is inputs to systems that already exist.

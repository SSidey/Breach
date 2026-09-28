# Breach — Design Addendum: Unified Combat Resolution

*Addendum to "Breach — Reverse Tower Defense: Design Spec." Standalone: everything needed to implement this is below, but it assumes the base spec's economy, lane/node model, and the "Combat depth" additions (detection/sortie, armor/ward, penetration, siege, morale) as prior context.*

## The problem this solves

As specced across several conversations, combat was on track to become three quietly-different systems: a lane cluster fighting a fort's forward blocker, a hero party fighting a lane cluster, and (newly) a garrison sortieing to intercept or an interior squad fighting inside a breached structure. Each was reasonable in isolation but they don't share code, which means they *will* drift in behavior during implementation even if the spec says they shouldn't.

**The fix: one Combatant shape, one Encounter procedure.** Whether it's unit-vs-unit in an open lane, unit-vs-structure at a fort gate, or unit-vs-garrison inside a breached wall, it is always the same function resolving the same kind of list against another kind of list. Nothing about *where* a fight happens changes *how* it's resolved — only which Combatants are in it.

## The Combatant schema

Every entity capable of fighting — a Raider, a Knight, a Hero Party, a Fort, a Garrison — is the same data shape:

| Field | Meaning | Notes |
| --- | --- | --- |
| `hp` / `max_hp` | Current and maximum health | Structures use this too |
| `dmg` | Damage dealt per exchange | |
| `armor` / `ward` | Flat reduction to incoming Physical / Magical damage | 0 for units with none |
| `pen: bool` | Ignores target's Armor/Ward entirely | Per base combat-depth spec |
| `siege_bonus` | Damage multiplier when target is a Structure | 1.0 for non-siege units |
| `engage_range` | Nodes away this Combatant can still deal damage (0 = melee) | |
| `morale` / `rout_threshold` | Current morale and the point at which this Combatant withdraws | Structures: `null` — they don't rout, they only break |
| `mobile: bool` | Can this Combatant change position (advance, sortie, retreat)? | False for Forts and stationary Garrisons; true for everything else, including a sortieing Knight |
| `side` | Attacker or Defender | |
| `is_structure: bool` | Gates siege_bonus and rout-immunity | |

A **Structure** (Fort, resource garrison-guard, wall segment) is just a Combatant with `mobile: false`, `morale: null`, and usually high `armor`/`ward` — it is not a special case in the resolver, only in what values it's populated with.

## The Encounter procedure

Whenever Attacker-side Combatants and Defender-side Combatants occupy the same place — a lane node, a fort's gate, the interior of a breached structure — that's one **Encounter**, resolved identically regardless of which of those three it is:

1. **Engagement check.** A Combatant participates this round only if a valid target is within its `engage_range`. Melee (`engage_range: 0`) needs direct adjacency; ranged can act from further back while melee in the same group closes the distance (per the base combat-depth spec).
2. **Damage computation**, per attacking Combatant against its target: `raw = dmg * (is_structure(target) ? siege_bonus : 1.0)`, then `effective = pen ? raw : max(0, raw - target.armor_or_ward)`, then `target.hp -= effective`.
3. **Morale update.** Any Combatant that took casualties or damage this round loses morale proportional to it. Structures skip this step (`morale: null`).
4. **Resolution.** Combatants at `hp <= 0` are removed (destroyed). Combatants at or below `rout_threshold` are removed from this Encounter but not destroyed — they withdraw (see Garrisons, below). Everyone else remains for the next round.
5. **Advance/carry-over.** If the Defender side of the Encounter is fully empty (all destroyed or routed) and the Attacker side still has `mobile` Combatants, they advance into that position — this is the existing lane-advance logic from the base spec, now just phrased as "the Encounter ended with the lane open."

That's the entire system. Nothing here differs between an open-lane skirmish, a siege, and an interior fight — only the Combatant lists handed to it differ.

## Structures as Combatants

- A Fort/garrison-guard's destruction (`hp <= 0`) is exactly a Combatant's death — it triggers the existing capture-choice logic (Fortify/Dismantle, Harvester/Ravage) from the base spec, unchanged.
- `siege_bonus` is the only stat that treats Structure-vs-unit differently, and it lives on the *attacking* Combatant, not as special-case code in the resolver.
- A Structure never routs. If a garrison is stationed *at* it, that garrison is a **separate Combatant** (see below) — the wall and the people behind it have independent HP pools and independent fates.

## Garrisons as Combatants

- A garrisoned unit (Knight, Archer, Militia) is an ordinary mobile-capable Combatant tied to a Structure's location.
- **Sortie** (`sortie: true`, from the base combat-depth spec) means: when a hostile Combatant list comes within detection range, this Garrison Combatant becomes `mobile: true` for one Encounter, moves out to intercept at a node short of the Structure, fights, and — if it survives — returns to being stationary at the Structure afterward.
- **Rout**, for a Garrison Combatant, means it withdraws into the Structure it defends (if the Structure still stands) or back toward the core's roster (per the Task Force system in the base spec) if the Structure has fallen. Either way, it is removed from the current Encounter without being destroyed — exactly step 4 above, no special code.

## Interior combat, concretely

Once a Structure Combatant reaches `hp <= 0`, if it had a live Garrison Combatant list associated with it that did *not* already rout or die, a **new Encounter** immediately opens between the Attacker's Combatants (now at that position) and the Garrison's Combatants — this is the interior breach fight from the cutaway-view discussion, and it is nothing more than another call to the same Encounter procedure, with the Structure's armor/siege modifiers no longer in play (the wall is gone) and raw unit stats deciding it.

## Mapping from the old, separate systems

| Old concept (base spec / prototype) | Now expressed as |
| --- | --- |
| Cluster vs. a Fort's forward blocker | An Encounter: Attacker cluster's Combatants vs. one Structure Combatant |
| Hero party vs. an attacker cluster | An Encounter: two mobile Combatant lists, same procedure |
| Garrison sortie (new) | A Garrison Combatant temporarily flagged `mobile`, same Encounter |
| Interior breach fight (new) | An Encounter opened at the same position, immediately after the Structure Combatant dies |
| Harvester automatic income (base spec) | A Worker Combatant's round-trip; payload only banked on arrival, lost if the Worker is destroyed en route |
| Garrison-only rout-to-Structure (earlier addendum draft) | Generalized to any `mobile` Combatant, on rout or voluntary order, targeting the nearest friendly Structure |

## Retreat: a general capability, not just an automatic rout response

The earlier rule — "a routed Garrison withdraws into the Structure it defends" — generalizes: **any `mobile` Combatant, on either side, can retreat to the nearest friendly Structure.** Two triggers, same destination logic:

- **Automatic**, when morale crosses the rout threshold (unchanged from the base combat-depth spec, just no longer Garrison-specific).
- **Voluntary**, as a deliberate order — the player pulling an overextended cluster back, or the defender AI choosing to withdraw a threatened sortie before it's destroyed rather than waiting for morale to force the issue.

Mechanically this is nothing new: a retreating Combatant is `mobile: true` moving toward a target position, which means it can be caught in an Encounter along the way exactly like an advancing one — a fleeing cluster isn't safe just because it's going backward. Arriving intact returns it to its owner's roster (Task Force system), per the base rule.

The payoff for the rest of the spec: a Fortified forward position (from the base spec's capture-choice mechanic) is no longer only useful for blocking hero parties — it's also a rally point that shortens the retreat distance for a failed push, giving Fortify a second reason to be worth its cost beyond pure defense.

## Physical supply lines: Workers as Combatants

Resource extraction was specced as a flag-and-timer (own a Harvester, collect income each round). That's fine for a spreadsheet but doesn't hold up next to everything else in this system, which is explicitly built so that *anything providing value has to survive contact to keep providing it*. Extraction should follow the same rule, for reasons that matter beyond flavor:

- **It reuses the Encounter system instead of adding a parallel one.** A Worker is just a Combatant with `dmg: 0` — the existing Encounter procedure already resolves "unarmed Combatant meets a hostile one" as a loss with no special-casing required. Economic warfare and military warfare become the same system, which is the whole thesis of this addendum.
- **It gives "cutting a lane" a second meaning.** Right now blocking forward advance is the only lever on a lane. If resources have to physically travel from node to home, the *rear* of a held lane becomes contestable too — a Worker's round-trip route is real ground, not an abstraction, so a small force that slips past the frontier can do damage without ever contesting it head-on.
- **It turns "silence" from a fiction into a fact.** The suspicion system already treats a settlement's silence as a trigger. If delivery requires a Worker to actually complete the trip, silence stops being a timer nobody caused and starts being literally true — the resource didn't arrive because the Worker carrying it is dead. Same trigger, now with a real cause behind it.
- **It applies symmetrically, which is what makes "get behind enemy lines" a real option.** The defender's own settlements need to move resources to their core, exactly like the messenger system already models on the information side — this is the same route, carrying materiel instead of a report. A Worker Combatant has no combat stats, so the challenge in intercepting one is never winning a fight — it's reaching it *past the defender's forward garrisons and sorties*, which is precisely the job Infiltrators already have. No new unit type is required to make "raid their supply line" viable; it falls out of stealth-bypass and low-stat Workers already existing on both sides.

Mechanically:

- **Worker Combatant**: `hp` low, `dmg: 0`, `armor/ward: 0`, `mobile: true`, carries a `payload` (resource type + amount) while en route.
- **Extraction now means**: a Harvester's yield doesn't accrue automatically each round — a Worker Combatant travels from the resource node to the owning side's home/core, and the payload is only banked on arrival.
- **Interception means**: if a Worker's Encounter ends in its destruction, its `payload` is simply lost (not looted, for v1 — looting is worth flagging as a later option rather than deciding now).
- **Capacity is now physical, not a rate on a spreadsheet**: throughput is bounded by how many Workers are assigned to a route and how long the round trip takes, which is exactly why a Fortified waypoint partway down a lane (already in the base spec) has a second use — it shortens the exposed leg of the journey, same logic as the retreat rally-point above.
- Workers are part of the same finite roster as Builders/Guards/Militia/Heroes (Task Force system) — killing enough of them is a real economic hit, not a respawn-for-pennies inconvenience.

## Note for implementation

This means exactly one function — call it `resolve_encounter(attacker_combatants, defender_combatants)` — is the entire combat engine. Everything else in the game (lane advancement, fort sieges, sorties, interior fights, even the base hero-party logic) is reduced to: *assemble the right two lists, call this function, read the result.* Building anything as a bespoke combat path outside this function is the thing to avoid.

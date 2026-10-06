# Spec 28: Unit levers

Decisions 41 (tech trees), 47 (weapons), 52 (discipline), 54 (sizes, traits), 64 (rated
traits), 77 and 79 (items, damage types, breaking); round 1: Decisions 117 to 123.

## Purpose

The user wants a design session on "the available levers for units re. design,
progression and variation". Units already differ by traits, items, size, speed and
preferred band. Skills or abilities, gained through each unit's tech, would sit beside
traits: bonuses and new capabilities that plug into the same pairs.

## Status

**Round 1 agreed (Decisions 117 to 123), plan below; not yet built.** Spec 30 is built
and merged, so what a unit needs for the fights it now has is clear. Round 1 took stock of
the unit as built and the placeholders it leans on, and the user answered with the unit
they want; the original agenda (kept below) is folded in.

## The unit as built

`UnitDef` today, with the six units in `content/units/`:

| Group | Fields | Notes |
|---|---|---|
| Body | `hp`, `footprint_depth`, `footprint_width`, `height` | Mass for bodies is footprint area (Decision 106); no armour, no resistances |
| Movement | `speed`, `turn_rate`, `backward_pace` | Turn rate and backward pace are placeholders (Decision 95) |
| Mind | `courage`, `discipline`, `initiative`, `leadership`, `tactics` | Initiative is 10 for all; discipline 30 rank and file, 60 drilled |
| Senses | `detection_range` | 40 cells for all |
| Fighting | `weapons` (`WeaponDef`: `damage`, `damage_type`, `attack_range`, `traits`), `dmg` | `dmg` is only a fallback for a unit with no weapons; every unit has weapons |
| Formation | `preferred_position`, `position_priority` | Band and claim (Decision 46) |
| Cost | `cost_food`, `build_seconds` | |

Missing beside the Decisions that ask for them:
- **Traits on units.** Rated traits (Decision 64) live on materials and weapons, not on
  `UnitDef`; climber, darksight, horde and mob (Decision 83), bleed and medic have nowhere
  to go.
- **Armour or resistances.** Damage types (Decision 79) have no effect on units.
- **Skill.** Every blow lands; there is no melee or ranged skill (agenda item 3).
- **Stamina.** Nothing tires (agenda item 12).

## The placeholders

Numbers marked as placeholders in the code, by where they belong:

| Belongs to | Placeholders |
|---|---|
| **A unit** (its sheet) | turn rate and backward pace, detection, initiative, discipline 30/60 |
| **A weapon** | the damage band ±25% (`FormationField.DAMAGE_BAND`, Decision 93); the attack interval, one for all (`ATTACK_INTERVAL_SECONDS`) |
| **Damage steps** | flank ×1.5 (`FormationCombat.FLANK_BONUS`), high ground ×1.25 (`FormationMelee.HIGH_GROUND`), blows by morale band 100/80/60% (`FormationMorale.BLOW_SHARE`) |
| **The contest** | the die, 0 to 10 (`ScrumContest.DIE`) |
| **Morale** | shock (side 15, rear 30, wing 10, a fallen unit 4, a fallen leader 10 a point), pressure 3/9/18, recovery 2, bands at 50 and 25, 10 a point of leadership |
| **Discipline** | meets threats at 50, re-form pace 0.4 to 1.5, pursuit leash 16/32/64/128/unleashed, breaking ranks 75/50/25% |
| **Routs** | crush 2 a cell, panic 5, seen rout 5, rally reach and times, re-formed morale 30, fan 45° and 6 cells |
| **Terrain** | slope 10% a quarter, wading ×0.6 and ×0.3, cliff at a cell |
| **Movement and bodies** | the scrum leash 16 cells, anticipation 12, steering look 3, body resistance ×4, brush 0.05, trade after 0.5 s, wheel lag |

## Round 1 agenda

Each item has a recommendation; answer, change or reject it.

1. **One sheet, grouped.** Recommend `UnitDef` grouped as body, movement, mind, senses,
   skill, items, traits and cost, and `dmg` retired: a unit with no weapon fights with a
   natural one (fists, bite), as every unit already does.
2. **Traits on units (Decision 64).** Recommend a rated `traits` dictionary on `UnitDef`,
   meeting the same ability-and-demand pairs as materials: climber, burrower, darksight,
   swimmer, horde N and mob N (Decision 83), bleed resistance, medic, and the tactics
   (`pursues`, `cautious`, `coordinated`) folded in as leader traits.
3. **Items: weapons, armour, tools (Decisions 47, 54, 79).** Recommend items of three
   kinds on one list: weapons deal damage of a type; **armour** gives a resistance per
   damage type (as a material's weakness or resistance shifts its hardness) and may slow
   or tire; tools grant trait levels (a shovel, burrower 1). Unwieldy items strike more
   slowly (Decision 79): the **attack interval moves onto the weapon**.
4. **Skill (agenda item 3).** Recommend one **melee skill** and one **ranged skill** per
   unit, 0 to 100. A blow is a contest: the striker's skill plus the weapon's handling
   against the target's defence (its skill, plus a shield); the seeded die (Decision 93)
   decides how close ones go. Outmatched by a margin, a blow is sure; otherwise it lands
   **glancing** (half) or is parried (none). Morale bands and conditions shift skill
   rather than damage, replacing the blow shares by band.
5. **Damage steps (agenda item 5).** Recommend a **step = ×1.25**, applied by one helper.
   High ground is one step (as now), a flank two (×1.56, near today's ×1.5), the rear
   three; resistance and weakness are steps down and up.
6. **Variance (agenda item 9).** Recommend the band moves onto the weapon (a club varies
   more than a spear) and narrows with skill; the die stays seeded (Decision 93).
7. **Initiative and the contest (agenda item 8).** Recommend initiative stays a unit stat
   that decides contested slots, the die stays one size for all, and blows stay
   simultaneous within a tick (no ordering by initiative: fairness, Decision 97).
8. **Stamina (agenda item 12).** Recommend a **stamina** pool per unit: drained by moving
   faster than a walk (pursuing, fleeing, charging), by fighting, and by heavy armour;
   recovered standing or walking. Tired units lose speed and skill; a chase ends when the
   chasers tire, as well as at the leash. Units differ by **endurance**.
9. **Morale inputs (agenda item 4).** Recommend courage per type now; tolerances (cold,
   heat, wet) as rated traits; conditions (fed, rested, comfortable) waiting for the
   systems that make them (stores, weather) - only rested comes now, from stamina.
10. **Bleed and healing (agenda item 10).** Recommend **bleed N** as a weapon trait (N
    damage a second for a few seconds, not stacking past the strongest) and **medic N** as
    a unit trait healing nearby friends N a second while the squad holds out of contact,
    a leader's leadership adding to it.
11. **Leaders (agenda item 7).** Recommend the three tiers keep one sheet: a
    **commander** is built with rolled tactic traits, a **hero** is promoted from a veteran
    unit (item 12) and rolls one, a **lord** is authored. Leadership N stays the one
    number; tactics are traits.
12. **Progression and variation (agenda items 6 and 11).** Recommend tech unlocks per
    unit type are **item loadouts and trait levels**, never raw stat edits; **veterancy**
    raises skill and discipline with fights survived; variation within a type is its
    loadout, painted per stand in the wave painter. What a map grants (a captured node's
    unlock) is a tech unlock like any other.
13. **Where the numbers live.** Recommend every placeholder above that isn't a unit's or
    an item's moves into one **battle tuning** resource (`content/tuning/`), so tuning is
    data, edited without code and named in one place.
14. **Order of work.** Recommend round 1 builds the sheet, unit traits and items with
    armour (1 to 3), then the damage step, skill and variance (4 to 6), then stamina
    (8) and the tuning resource (13); bleed and healing, leaders and progression (10 to 12)
    in a round 2.

## Round 1 answers

The user's own list of what a unit needs, with the gaps found between it and the agenda:

1. **The sheet (Decision 117):** archetype tags (human, martial, cavalry, archer) for tech
   to target, beside the unit type; five attributes - **strength, agility, constitution,
   willpower, wits** - and stats derived from them, shown not set; mind stats (courage,
   discipline, leadership); senses (sight, hearing, special ones such as heartsense);
   speed per movement mode (march, swim, climb, fly, burrow); turn speed; rated traits;
   body (footprint, height, mass); band; cost. `dmg` retires.
2. **A blow (Decision 118):** one seeded opposed roll, skill against defence, its margin
   read as parried, dodged, grazed, hit or critical (×1.5 baseline, a stat). High ground
   adds to the striker's margin; a flank denies the target its parry, the rear its dodge
   too; being surrounded lowers defence. A parry doesn't counter: riposte is an ability.
3. **Damage (Decision 119):** the weapon's range, skill raising its floor and spilling into
   crits; strength scaling per weapon over its requirement; weakness ×1.5, resistance
   ×0.5, immunity ×0; then armour (mundane blows) or ward (magical ones) flat. Magic is a
   source, not a type: a magical flag on any type (fire and magic fire are both fire), and
   arcane for pure magic.
4. **Items (Decision 120):** one group; slots per item and per unit type; weight; strength
   requirement; proficiency tags; the weapon's attack interval scaled by the unit's attack
   speed; carry and wield limits from strength, encumbrance in four stages, a hauler trait
   raising the limit.
5. **HP, wounds and death (Decision 121):** the blow that reaches 0 HP stops there and the
   unit is downed, a body on the ground (an obstacle by mass, haulable); struck again it
   enters death's door, constitution deep; a blow past minus its constitution kills
   outright. Units kill or capture the downed once no standing foe is near - send a
   messenger (a leader's trait) lets one go as a morale blow to its side. A caught router
   may surrender in place, by a seeded chance from courage, morale and disposition.
   Regeneration is HP only, runs through damage (traits may stop it, or keep it running
   while downed), with a limit per rest.
6. **Pools, abilities, status effects (Decision 122):** pools with their own gain;
   abilities as trigger, condition, effect, cost and cooldown, passive or activated; status
   effects with duration, stacking and resistance. Attack shapes belong to weapons and
   abilities (spec 32).
7. **Progression and tuning (Decision 123):** tech can change anything, in a fixed modifier
   order; subtypes inherit their parent's upgrades; experience fills ranks tech unlocks;
   everything persists for the map, a rest resetting some of it; named leaders persist
   across maps, and for now rank and file too; one tuning file.

**Still open:**
- Whether rank and file should carry over between maps: yes for now, to be judged in play.
- Each derived stat's formula, and the starting numbers for the six units: set while
  building, judged by the mirror trials.

## Round 1 plan

Stacked PRs, each within the 11-file limit; the mirror trials both ways round on every
part that moves outcomes:

| Part | What |
|---|---|
| 1 | The tuning file: every placeholder in `content/tuning/`, read by the simulation |
| 2 | The sheet: tags, attributes, derived stats, mind and senses, movement modes, traits; `dmg` retired |
| 3 | Items: one item group, slots, weight, proficiency tags, the weapon's attack interval and the unit's attack speed |
| 4 | The blow: skill and defence, the opposed roll and its bands, crits; high ground and flanks shift the roll |
| 5 | Damage: weapon range and skill, strength scaling, weakness, resistance and immunity, armour and ward |
| 6 | HP and wounds: downed, death's door, bodies on the ground, kill or capture, surrender; regeneration and its per-rest limit |
| 7 | Load and stamina: encumbrance, stamina drain and recovery, tiredness slowing and weakening |

Round 2: abilities, pools and status effects (bleed, medic, riposte), experience and ranks,
the tech modifier order and subtypes, persistence and rest, leaders as named characters.

## The original agenda (folded into round 1)

1. **The levers there are today:** stats, traits, items, size, band, discipline. What each
   is for, and where they overlap.
2. **Skills and abilities:** what they are beside traits, and how a unit gains them (tech
   per unit type, veterancy, items).
3. **Melee skill:** a sure-hit rule (parries, outmatching) that unwieldy items (Decision
   79), morale bands and conditions (Decision 82) feed, kept deterministic.
4. **Morale inputs:** courage, comfort ranges, tolerances, likes and dislikes (Decision
   82); which are per type and which vary per unit.
5. **Damage steps:** what "a step more damage" means (Decisions 79, 82, 83, 85 use it
   as a placeholder): a flat amount, a fraction, or levels of damage.
6. **Progression:** what the overlord's tech unlocks per unit type, and what a map grants.
7. **Leaders:** commanders (built, rolled tactic traits), heroes (promoted from regular
   units, rolled tactic traits) and lords (named, authored); leadership N and tactic
   traits (Decision 81); how leadership scales a squad's cohesion when it meets contact
   (Decision 88).
8. **Initiative and contests:** initiative as a stat, the contest die size (a unit's
   seeded variance), and whether initiative also orders blows within a tick (Decision 88).
   Formation initiative from leadership (deciding) and discipline (carrying out), and
   discipline as a unit stat (Decision 92).
9. **Variance:** how damage and other rolls vary by unit (skill, weapons, conditions),
   replacing the ±25% placeholder (Decision 93).
10. **Damage over time and healing:** a bleed trait on weapons (damage over time); medics
    or a medic trait that heals over time, perhaps needing a halt and helped by
    leadership.
11. **Variation:** how two units of one type can differ (loadouts, upgrades), and how the
   wave painter shows it.
12. **Fatigue:** pursuers and the pursued tiring over a chase, so pursuit wears off by
    itself as well as by its discipline leash (Decisions 107 and 109). From spec 30 round
    2's feel test: an unleashed line chased a retreating wave to the player's end and was
    cut up there - with fatigue "they ought not pursue that far, or if they can then fair
    enough they do".

## Rounds

Round 1 agreed (above); not yet built.

# Spec 32: Impact and attack shapes

Draft, to agree. It builds on Decisions 47 (weapons), 79 (damage types), 88 (the scrum,
flank blows), 92 (discipline), 95 (movement by facing), 102 and 106 (bodies and spaces,
pushing by mass) and spec 30 (continuous positioning).

## Purpose

Bodies (Decision 106) push apart only to clear an overlap: no speed, no momentum, and foes
never push each other. The user wants weight to tell: a charge that knocks a line back and
sends small units flying, a brute whose blows scatter grems, explosions that throw bodies
outward - and attacks that resolve over the shape they sweep, not just from one body to
another.

## Status

**Draft (not agreed).** Raised during spec 30 round 1; to follow spec 30 round 2.

## Proposed

### Impact: one rule for charges, blows and blasts

- **Every impact is a vector:** a push with a direction and a strength, applied to a body
  as a velocity that decays over a few ticks (placeholder: halves each 0.1 s). A unit
  being thrown is out of control: it keeps only its body (Decision 106), can't strike,
  and walks back to its place or the scrum once it stops.
- **Strength against mass:** the throw is strength / mass, so the same blow sends a grem
  much further than a brute. Below a threshold it is a stagger (a brief halt); above a
  second, a knockdown (on the ground for a moment, every blow on it a flank blow).
- **Bracing:** a unit in control, steady and facing the impact squarely resists it, by its
  formation's discipline (Decision 92); one struck on a flank or the rear, turning, or
  shaken gets none. (Spears set against a charge are bracing.)
- **Sources, all the same rule:**
  - **Body to body (charge):** momentum at contact - mass times the speed it closes at -
    is the strength, along its line of travel; the charger loses what it gives. A unit
    that has been running builds it; one standing has none.
  - **Blows:** a weapon carries an impact strength, along the line from striker to
    target (a brute's club scatters grems; a grem's claws don't move a brute).
  - **Blasts:** an explosion's strength falls off from its centre, outward from it.
- **Friends too:** an impact throws any body it reaches; a thrown body striking others
  passes on what it keeps (a knocked man knocks others), by the same mass rule.

### Attack shapes

An attack is a **shape** where it resolves, **delivered** one of a few ways. Two shape
primitives cover what's proposed, and every attack is one of them:

- **Sector:** a centre, a facing, a reach (inner and outer radius) and an arc.
  - a thrust or a bite: a narrow sector (one target, as today);
  - a sweep or cleave: a wide arc in front (a brute's swing hits every grem in it);
  - a cone: breath, a blunderbuss, a spray;
  - a circle (arc 360): a stomp, a whirl, an explosion centred on a point.
- **Band:** a line from one point to another with a width - a lance or spear's reach
  through a rank, a beam, a trampling path, a charge's swathe.

Delivery:
- **Struck:** the shape is placed on the striker (melee).
- **Thrown:** a projectile flies to a point and the shape resolves there (a bomb, a
  boulder); it can be dodged or blocked on the way.
- **Shot:** a band from shooter outward, stopped at the first body (an arrow), or passing
  through (a bolt) by the weapon's penetration.

Each shape carries: which bodies it can hit (foes only, or friends too), how many at most,
damage by distance from its centre or along its band (falloff), and its impact (strength
and the direction: away from the striker, along the band, or out from the centre).

## Agenda for round 1

1. **Impact model:** decaying velocity on bodies, stagger and knockdown thresholds, and
   their numbers (placeholders until spec 28's unit levers).
2. **Charges:** when a unit is charging (speed, distance run), what bracing takes away,
   and the charger's own loss; a formation charging as one (Total War's charge bonus).
3. **Blows with impact:** which weapons carry impact, and whether a cleave's impact is
   split among those it hits.
4. **Shapes:** sector and band as the only primitives, or others (a ring, a chain that
   jumps between targets, a wall); how many targets a shape may take, and in what order
   (nearest first, then the unit's own frame, then a draw: Decision 97).
5. **Friendly fire:** blasts and throws reaching friends (by shape, always, or never).
6. **Damage over a shape:** falloff from a blast's centre, along a band, through a cone.
7. **Terrain:** thrown into a wall, off a cliff, into water; impact on structures
   (Decision 77's digging and breaking).
8. **Feel test:** a brute in a grem scrum, a charge into a line (braced and not), a bomb
   in a crowd.
9. **Fairness:** shapes resolve from one snapshot, impacts apply together (Decision 97);
   the mirror trials and the no-handedness test (spec 30) run throughout.

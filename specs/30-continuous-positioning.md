# Spec 30: Continuous positioning

Decisions 102 (continuous footprints, rotated rectangles, any facing), 105 (free
bearings, sweeping round bends, pushing apart by size) and 106 (a body and a space). It builds on
Decisions 74 and 75 (squads on routes), 84 (claimed cells, overtaking), 85 (terrain per
cell), 88 (seeking contact), 95 (movement by facing), 97 (no ids or order in outcomes)
and 100 (one unit to a cell).

## Purpose

The formation sim places units continuously already: a loose unit's point, contact as
touching footprints. But it keeps them apart, seeks foes and settles routers by grid
cells, and a formation's frame faces only the four cardinal ways. On a diagonal route
(the field's route C, and player-drawn routes to come) a formation marches with its front
at 45 degrees to its way. The user chose to drop cell positioning, as Total War does:
every unit keeps its footprint clear of every other's, moving or still, and a formation
faces its route's true heading.

## Status

**Round 1 built (Decisions 102, 105 and 106); round 2 to agree.** The spec 27 stack is
merged. Round 1 is built as stacked PRs, in the order under "Round 1 plan".

## Agreed

- **Bodies and spaces (Decision 106):** a unit's body is the circle inscribed in its
  footprint (a grem 1 across, a brute 2); its space is the footprint rectangle turned to
  its bearing. No two bodies overlap, ever: they push apart by mass, and units stop short
  of foes. A unit in control keeps its space; a router keeps only its body and shoves
  through, crushing as it goes.
- **Facing:** a formation's frame faces any angle, the route's heading where it is. Its
  places are laid out in that turned frame. Units keep turning at their turn rate
  (Decision 95), and their bearings turn freely (Decision 105).
- **Terrain stays a grid,** read at a unit's position and the ground ahead of it
  (Decision 85).
- **One rule everywhere:** no cell-only exceptions at rest or in transit (Decision 96).

## What changes

| Today (cells) | Becomes |
|---|---|
| `SquadFrame.unit_rect`, 4 facings | a frame turned to any angle; places as points plus a heading |
| `ScrumPaths` occupancy and cell paths | footprint separation and steering to a point |
| `ScrumContest`: contested cells | contested points: a slot beside an enemy, claimed by the same key |
| `ScrumSpacing`, `RoutSettle`, `RoutFlight.part`: one unit to a cell | nudge apart until footprints clear |
| `ScrumReach`: axis-aligned touching | turned-rectangle touching, same reach and front arc |
| `FormationNarrowing`: gap measured in cells across a cardinal front | gap measured across the frame's heading |

## Agenda for round 1

1. **Separation:** the steering rule that keeps footprints clear (push apart, slide
   along, wait), and its cost each tick for a full field.
2. **Slots beside a foe:** how many units fit round an enemy's footprint, and how they
   are offered and claimed (Decisions 88 and 97).
3. **Unit bearings:** keep 8 steps, or turn freely?
4. **The frame on bends:** how a formation's facing follows a curving route (turn as a
   re-form at each bend, Decision 92, or sweep with the route).
5. **Ties in the unit's own frame:** whenever two points or slots are equally good, the
   tie goes by the unit's own frame (most ahead along its bearing, then nearest its
   place, then its seeded draw), never by a world direction or a scan order. A
   mirror-geometry test checks it: the same battle reflected left to right must give
   reflected results. The reversed-lists tests can't see a world-direction bias. (From
   #91, closed: the cell-scan ties it found, in `ScrumPaths.path`,
   `ScrumSpacing._free_near` and `RoutSettle.free_spot`, go with the cells.)
6. **Retire the old combat modes:** move the one-lane scene (`FormationLane`,
   `FormationBattle`, spec 22) onto the scrum, then remove the wrap, edge and walking-wing
   modes (`FormationEdges`, `FormationWings`, `FormationMelee._lines`). The field, the
   trials and the rehearsals already use the scrum. (From #92, closed: a second attacker
   reaching an edge already held is locked on but not recorded, fights as if frontal and
   is never released; it exists only in the edge mode.)
7. **Tests to carry over:** which cell-exact tests become footprint tests, and the
   fairness checks (mirrors both ways round, reversed lists) to run throughout.

## Round 1 answers

1. **Separation (Decision 105):** after every unit has moved, each pair of overlapping
   friends is pushed apart the shortest way, the push split by footprint area. All
   pushes are worked out from one snapshot, then applied together, a few passes a tick
   (placeholder 3). A unit steering to a goal slides along a friend: it keeps the part of
   its step that doesn't close on it. Foes are never pushed: a unit's step stops short of
   touching an enemy's footprint. Pairs are found through a bucket grid two cells wide,
   so a full field costs about the number of units, not its square.
2. **Slots beside a foe:** round an enemy's footprint, in its own frame, a slot a
   seeker's width apart along each face and one off each corner, at touching distance.
   A grem round a grem has 8, as the cells gave; round a brute it has 12. Slots are
   claimed by the same contest key (Decision 88), arrival time first.
3. **Bearings turn freely** (Decision 105).
4. **The frame sweeps round bends** at its wheel rate (Decision 105).
5. **Ties in the unit's own frame:** as the agenda says. The mirror test is built with
   part 7.
6. **The old combat modes go first** (part 1), so nothing built on cells needs porting
   twice: the one-lane scene moves onto the scrum, then the wrap, edge and walking-wing
   modes are removed.
7. **Tests:** each part converts the cell-exact tests it touches into footprint tests,
   and runs the mirror trials both ways round and the reversed-lists tests.

## Round 1 plan

Each part is a PR, stacked on the one before. No part opens more than 11 existing files.

| Part | What |
|---|---|
| 1 | Retire the wrap, edge and walking-wing modes; the scrum is the only fight. |
| 2 | Free bearings (`UnitMotion`): an angle turned at the turn rate. |
| 3 | The turned frame (`SquadFrame`): a heading, swept round bends at the wheel rate. |
| 4 | Turned footprints (`UnitFootprint`): a unit's space. |
| 5 | Bodies: one push step by mass for scrum, rout and withdrawal (`ScrumSpacing`, `RoutSettle`, `RoutFlight.part`). |
| 6 | Slots round a foe's body, and contact between bodies (`ScrumPaths`, `ScrumContest`, `ScrumReach`). |
| 7 | Narrowing across the heading; the scene draws turned units; the mirror test; trials. |

## Round 1 built

Stacked PRs #99 to #108 on `main`:

| PR | Part |
|---|---|
| #99 | Decisions 105 and 106, this plan |
| #100 to #102 | 1: the scrum is the only fight; the wrap, edge-blow and walking-wing modes go |
| #103 | 2: free bearings |
| #104 | 3: the turned frame, sweeping round bends at its wheel rate |
| #105 | 4: turned footprints (`UnitFootprint`), a unit's space |
| #106 | 5: bodies push apart by mass (`UnitBodies`) |
| #107 | 6: slots round a foe's body (`ScrumSlots`, `ScrumSeek`), contact between bodies |
| #108 | 7: narrowing across the heading, bodies drawn, no handedness |

**To feel-test:**
- The scrum is fluid: more of a wave wraps a line's ends than cells let it. A frontal
  attack still doesn't rout the field's line, but it now costs it about half its units
  (it kept about 9 of 12).
- Head-on mirror battles are quicker (about 120 ticks, from 170) and end in a mutual
  rout more often (about 15%, from 5%).
- Routers shove through their own ranks, crushing as they go; a friend they shove past
  catches them.
- A formation on a bend sweeps round it without halting; one on a slanting route faces
  it square on.

**Fairness:** head-on mirror, 300 seeds each way round, the side spawned first winning.
Part 6's 53% over 1,012 battles is within 2 standard deviations; it is the one to watch.

| Part | One way | The other |
|---|---|---|
| 1 (100 seeds) | 45 of 93 | 47 of 96 |
| 2 and 3 | 147 of 287 | 138 of 291 |
| 5 | 139 of 282 | 144 of 285 |
| 6 (600 seeds) | 271 of 504 | 263 of 508 |

**Found on the way:**
- A rout that re-formed round its own leader crashed the scrum's settling (fixed in part 1).
- The scrum turned squads' units in list order, which would have mattered once footprints
  turn with their units (fixed in part 4).
- Vector2 is float32: bodies just touching measured a hair apart or overlapping depending
  on where on the field they stood. Tolerances are now 0.001 cell (part 7).
- Exact mirror runs can't match: a seeker facing a mirror-symmetric choice must pick a
  hand, and a reflection flips it. The test checks no hand is preferred instead.

## Agenda for round 2

1. **What still reckons in four ways:** a disciplined line's stance (`ScrumStance`) turns
   to the nearest of four ways and re-lays in that frame; flank locks (`FormationEdges`,
   `SquadEdges`) are by four edges; `SquadGeometry`, `FormationContact` and
   `FormationMarch.pace` read the facing nearest the heading. Each moves onto the heading.
2. **Spaces kept by control:** a unit in control keeps its space (Decision 106); today
   only the frame keeps places, and a pushed unit in its frame leaves it to walk back.
   Whether loose units in control should hold their spaces against friends is open.
3. **Seeking round bodies:** seekers walk straight to their slot and bodies part round
   them; one blocked by an enemy between it and its slot can stall. A steering rule
   (round the nearer side) may be needed.
4. **Cost:** `UnitBodies` runs three passes a tick over bucketed pairs; measure a full
   field.
5. **Tidy:** `State.TURNING`, `turn_to`-era checks, `FormationRout._reform`'s four-way
   facing and the router's grem-sized catch reach (`CAUGHT_REACH`).

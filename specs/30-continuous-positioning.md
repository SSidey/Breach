# Spec 30: Continuous positioning

Decision 102 (continuous footprints, rotated rectangles, any facing). It builds on
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

**Agreed (Decision 102); not started.** To be built after the list-order audit's
follow-ups, on top of the spec 27 stack (#90).

## Agreed

- **Footprints:** a unit is a rectangle its own width by depth (a grem 1 x 1, a brute
  2 x 2), turned to its bearing. No two footprints overlap, ever: moving units steer
  round friends and stop short of foes; a unit at rest is never inside another.
- **Facing:** a formation's frame faces any angle, the route's heading where it is. Its
  places are laid out in that turned frame. Units keep turning at their turn rate
  (Decision 95); whether their bearings stay 8 steps or go free is settled in round 1.
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

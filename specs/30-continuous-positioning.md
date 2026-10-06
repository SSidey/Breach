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

**Round 1 built, feel-tested and merged (Decisions 102 and 105 to 113); round 2 built and
feel-tested (Decisions 114 to 116), stacked PRs #120 to #127 (below).** The user's order
after it: spec 28 (unit levers), spec 32 (impact and attack shapes), spec 31 (posts and
garrisons), then the structure work still to come (damage and collapse in play, spec 24;
fighting at structures). A dedicated pass on unit movement is wanted later (see Round 2's
feel test).

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
Parts 6 and 7 leaned to the first-spawned side on seeds 1 to 300 (part 7: 142 to 107, 2.2
standard deviations); a swapped run mirrors its twin exactly, so the outcome follows the
ids' draws within a battle, as it should. The draws for the pairs that meet were tested
directly and are even, and 700 fresh seeds (301 to 1000) on part 7 came out 282 to 290:
424 to 397 over 1,000, within 1 standard deviation. No bias; seeds 1 to 300 were a
fluctuation.

| Part | One way | The other |
|---|---|---|
| 1 (100 seeds) | 45 of 93 | 47 of 96 |
| 2 and 3 | 147 of 287 | 138 of 291 |
| 5 | 139 of 282 | 144 of 285 |
| 6 (600 seeds) | 271 of 504 | 263 of 508 |
| 7 (1,000 seeds, one way) | 424 of 821 | (mirror) |

**Found on the way:**
- A rout that re-formed round its own leader crashed the scrum's settling (fixed in part 1).
- The scrum turned squads' units in list order, which would have mattered once footprints
  turn with their units (fixed in part 4).
- Vector2 is float32: bodies just touching measured a hair apart or overlapping depending
  on where on the field they stood. Tolerances are now 0.001 cell (part 7).
- Exact mirror runs can't match: a seeker facing a mirror-symmetric choice must pick a
  hand, and a reflection flips it. The test checks no hand is preferred instead.

## Round 1 feel test

The user feel-tested round 1 with the action log and replay built for it, sending logs
of what looked wrong; each became a fix with its log as a regression test.

| PR | What |
|---|---|
| #110 | The action log, Copy and Replay in the feel test, the tick counter; framed units hold their places against another squad's loose units, so waves meeting at the crossroads regroup |
| #111 | Units with no slot open wait by the fight (Decision 108); a pursuit is leashed by discipline (Decision 107), its leash shown |
| #112 | One unit per place (stepping up waits for moves under way); a framed unit holds against a brush; a unit its own ranks hold off trades places with a like friend (Decision 110) |
| #113 | Every formation pursues to its leash; its units roll to break ranks and chase to their own (Decision 109) |
| #114 | Any standing squad may be engaged; only one not getting away seeks combat (Decision 111) |
| #115 | A formation doesn't wait for its runaways; a leader steadies its units (Decision 112) |
| #116 | A withdrawal turns with its route at a bend |
| #117 | A pursuit takes its quarry's road (Decision 113), sweeps round its bends, its units free of their places; a fleeing unit finds the ford again |

**Decisions made:**
- **107:** a pursuit is leashed by discipline: 32, 64, 128 cells from its post, or none,
  by share of an expected maximum discipline of 100.
- **108:** a unit with no slot open waits a body's breadth behind the nearest, not back in
  its place.
- **109:** every formation pursues a retreating enemy as a body (unless ordered not to);
  leash steps 16 to none, a leader's "pursues" tactic a step out, "cautious" a step in;
  units near the enemy may break ranks and chase to their own leash.
- **110:** a unit its own ranks hold off its place trades places with an interchangeable
  friend (one kind, one band), or takes its own place.
- **111:** any standing squad may be engaged - what to attack is the attacker's choice -
  but only one not retreating or routing seeks combat; retreaters strike what's in front
  of them, routers only flee.
- **112:** a formation marches on without its runaways, who make their own way back; a
  leader's bonus steadies its units against breaking ranks.
- **113:** a route is a way to travel, not a formation's own: a formation travels to its
  target by the nearest route that paths to it; a pursuit takes its quarry's road.

**To feel-test after merging:**
- Retreats are costly: a pursuing line and its runaways often destroy a wave before it
  gets home; a captain keeps his line together, and "Line won't pursue" holds it.
- A pursuer follows its quarry's road (C or B) and returns along it to its post; the
  status line reads "pursuing x/y cells" and its post is ringed at its leash.
- Routers are run down by any squad that reaches them (fewer reach a friend to crush or
  rally there).

**Fairness:** head-on mirror, 300 seeds each way round, after each change: the swapped
run mirrors its twin exactly and the totals sit within 2 standard deviations (600 seeds:
262 to 229, 1.5); flank mirror 100 to 0 for the flanker both ways round.

**Found on the way:**
- A unit given no share of a push still went loose, so squads whose places overlapped
  churned for ever (#110).
- Closing up after a swap stepped units onto places other swaps were heading for: two
  units shared a place (#112).
- A pursuit gave up only when the enemy got 16 cells ahead of its units; an equally fast
  pursuer never did (#111).
- Withdrawing units at a bend took the leg leaving it, and ran off the field (#116).
- A front lock also locked its target back, which would have turned routers into
  fighters under Decision 111 (#114).
- `ocp-shotgun-surgery` counts every pre-existing file a PR changes: run pre-commit with
  `--all-files` and the stack's base as `BASE_REF`, and split a PR before it passes 11.

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
6. **Replay as a record of play:** the feel test's action log (`FormationFieldActions`)
   replays a battle tick for tick (Decision 93). The user would keep it for whole games:
   a standard command vocabulary (who, which order, what target) in place of the feel
   test's words, a versioned header, and a structured format, made robust where needed.

## Round 2 answers

1. **Four ways:** the mechanical move - everything that reads the facing nearest the
   heading (`ScrumStance`, `SquadEdges` and `FormationEdges`, `SquadGeometry`,
   `FormationContact`, `FormationMarch.pace`, the rout's re-forming) reckons from the
   heading itself.
2. **Spaces kept by control:** settled in round 1's feel test: a framed unit holds its
   place against another squad's loose units and against a brush from its own (#110,
   #112), and a unit its own ranks hold off trades places (Decision 110). Closed.
3. **Steering (Decision 114):** a unit whose straight way to its goal is blocked by a body
   steps round it on the side nearer its goal, a seeded draw breaking a dead-centre tie;
   one rule for seekers, regrouping units and stragglers.
4. **Cost:** measured on a full field; optimised only if it needs it.
5. **Tidy:** `State.TURNING` and its checks, `turn_to`-era checks, the rout's four-way
   re-forming, and the router's catch reach measured by bodies, not a grem's size.
6. **Replay (Decision 115):** the record of play is structured now: a versioned header and
   one command per line - its tick, who gives it, the order and its target - with the feel
   test's words mapped onto it and old logs still replaying. The vocabulary grows as real
   orders come (spec 31).

## Round 2 plan

Stacked PRs on `main`, each within the 11-file limit:

| Part | What |
|---|---|
| 1 | The tidy (item 5) |
| 2 | Edges, geometry, contact and the march reckon from the heading (item 1) |
| 3 | Stance, regrouping, routs and pursuit reckon from the heading (item 1) |
| 4 | Steering round bodies (item 3, Decision 114) |
| 5 | The structured record of play (item 6, Decision 115) |
| 6 | A formation moves no faster than its units can walk (Decision 116, from the feel test) |
| 7 | The cost of bodies on a full field (item 4), and this spec's round 2 write-up |

## Round 2 built

Stacked PRs #120 to #127:

| PR | Part |
|---|---|
| #120 | Decisions 114 and 115, this round's answers and plan |
| #121 | 1: the tidy - `State.TURNING` retired, routs re-form on the route's true heading, a router caught by bodies |
| #122 | 2: geometry, edges, contact and the march reckon from the heading |
| #123 | 3: stance, regrouping, morale and pursuit reckon from the heading |
| #124 | 4: steering round bodies that won't part (`UnitSteer`); a routing squad met where its units are |
| #125 | 5: the structured record of play (`FormationRecord`) |
| #126 | 6: a formation moves no faster than its units can walk (`FormationWheel`, Decision 116) |
| #127 | 7: the cost of bodies, this write-up; `FormationRoute.facing_at` retired |

On quarter headings parts 2 and 3 change nothing (the mirror trials matched the base
exactly); on a slant a squad now reckons at its true angle. Steering and the wheel moved the
mirror trials within noise: head-on 135/119 and 122/127 swapped, flank 300/0 both ways
(300 seeds each).

## Round 2 feel test

- **Pursuit depth:** with no leash short of the field, a pursuing line chased B to the
  player's end and was cut up there by B and the wave behind it. The user: fine for now;
  once fatigue or stamina comes in (spec 28, agenda item 12) they ought not to pursue that
  far - or if they can, fair enough.
- **Pursuit by route C:** as expected.
- **A wheel looks like one board turning:** its outer file was hurrying round the arc.
  Decision 116 holds every unit to its own pace, the inner files stepping shorter, so a
  wheel takes about twice as long. Units still stand on their places: the formation turns
  as a drilled line, not as units each finding their way.
- **Wanted later, in a dedicated pass on unit movement** (the user's words: "the overall
  unit movement could use some work re. turning or reforming for gaps"):
  - **Pouring through a gap:** "when we get to forts and the door is 2 wide, I don't expect
    my formation to line up into 2 lines before entering" - a formation pours through a
    gap and gathers beyond it, rather than narrowing into files first (today's
    `FormationNarrowing`).
  - **Wheeling and re-forming as units:** each unit finding its own way to its place
    (Decision 116's rejected first approach), which first needs every move of a frame to
    say whether it walks or is set (placing, joining and re-forming set it).
  - **Taking the downed** (spec 28, Decisions 121 and 124): units walking out from their
    formation after a fight to finish or capture downed foes - "units must either kill or
    capture" - and bodies on the ground slowing units loose in a fight. Until this pass,
    only a foe already beside a body takes it, so a wave that marches on leaves its
    downed foes lying.

## Round 2: the cost of bodies

Measured headless (one core, 10 ticks a second: a 100 ms budget a tick):

| Field | A step, average | Worst | `UnitBodies` (3 passes) |
|---|---|---|---|
| The feel test, both waves sent (about 40 units) | 2.3 ms | 20 ms | 0.35 ms |
| A clash, 20 a side | 0.7 ms | 1.3 ms | 0.14 ms |
| 40 a side | 2.9 ms | 4.1 ms | 0.56 ms |
| 80 a side | 12 ms | 21 ms | 5.1 ms |
| 160 a side | 46 ms | 105 ms | 15 ms |

Steering (`UnitSteer`) is about a sixth of a crowded step (160 a side: 39 ms without it).
Not optimised: it isn't needed at the feel test's scale. Where to start if the game needs
more: steering looks at every body (bucket it as `UnitBodies` does), a dense scrum gives
the bodies' 2-cell buckets many pairs, and the pair search runs three times a tick.


# Spec 27: Formations in 2D

Decisions 73 (the formation model is the game's simulation), 70 (stands), 52 (squads on a
2D cell grid), 69 (light control, unit AI), 74 (position and facing), 75 (routes) and 78 (contact and fronts), 81 (flanks, leadership), 82 (morale, shock, rout), 83 (stands, horde and mob), 84 (crowding and passing), 85 (terrain), 86 (the feel test) and 87 (coordination and signals).

## Purpose

The formation model places squads along one line: a lane's distance, with ranks behind a
front and columns across it. Fights are front to front, with flank wrap at the ends. With
64-cell tiles (Decision 68), node areas (Decision 68) and fire across tiles (Decision 71),
squads need real 2D positions:
- facing
- more than one front
- flanks that can be walked round

Wave templates are painted in stands (Decision 70).

## Status

**Design conversation done.** All eight agenda subjects are agreed (see Agreed below).
Round 1 is being planned.

## Agreed

1. **Position and facing (Decision 74, a baseline to feel-test).**
   - A squad's position is the centre of its front edge, in cells. Units keep their
     painted (rank, column) in the squad's frame, turned to its facing.
   - Four facings (N, E, S, W). A squad marching at an angle sidles, keeping the facing
     nearest its heading.
   - A quarter turn wheels on the front centre, taking the time the outer end needs to
     march its quarter arc at the slowest unit's speed.
   - An about-face turns in place after a short pause (placeholder 1 s); the back rank
     becomes the front and the re-form shuffle moves front-preferrers forward.
   - Turns rotate, never mirror: the left flank stays left.
   - A turning squad neither advances nor strikes, and blows on it count as flank blows.
   - Units face their squad's way (individual turning is subject 3).
2. **Paths (Decision 75).**
   - A route is a path of cells, pathfound between waypoints; its corridor is the lane's
     combat width either side.
   - The player assigns routes to lanes and moves their waypoints. How many routes the
     player may run is set per map and grows with progression (an overlord upgrade, or
     buildings and tech). Routes can be locked.
   - Detouring round a fort is allowed; its long-ranged defences are the cost.
   - Only the units' AI leaves a route (contact, objectives, obstacles, flanking), within
     a leash of 16 cells scaled by discipline, rejoining at the nearest point ahead.
   - Underground routes (Decision 76): drawn in plan, depth set on a side-on profile,
     relative to the surface by default. The profile shows only known strata, so there is
     no projected dig time. Digging is attacking cells (Decision 77). Both come with the
     underground work, not round 1. Damage types and breaking: Decision 79.
3. **Contact and fronts (Decision 78).**
   - Any of a squad's four edges can be a front; it can fight on several at once.
   - Units on a struck side or rear edge turn in place; the flank bonus applies for the
     first interval. A free squad about-faces to a rear hit but doesn't wheel to a side
     hit.
   - Step-up runs inward per fighting edge; band rules hold. Corner units take blows
     from both edges and strike back at one.
   - A unit in melee uses only melee weapons unless a trait allows otherwise.
   - Two or more fronts strain discipline.
   - Digging logistics, light and a lone sneaking unit: Decision 80. Workers and
     logistics have their own agenda in spec 29.
4. **Flanks and wrap (Decision 81).**
   - Overlapping units form a wing that walks round the line's end to the side edge; only
     overlap units wrap, at in-fight speed, and the wing re-forms into its squad after.
   - Discipline sets reach: side for all, rear only for the highly disciplined.
   - A formation's leadership is its best living leader's; losing that leader drops it
     at once, with a morale hit.
   - Flanking with whole waves is a leader's tactic trait, not a lane order. Commanders
     and heroes roll tactic traits; lords have authored ones.
   - Morale, shock and rout (Decision 82): a morale pool per formation from courage,
     leadership, support and condition; impact and pressure shock; a rout is a panicked
     flight with crush casualties, spreading panic, pursuit and rally.
5. **Stands in 2D (Decision 83).**
   - Stands are for painting and deploying only; deployed units act per cell.
   - horde N (enough units of any kind) and mob N (enough of one type; grems mob 16)
     give a bonus while the formation holds that many.
6. **Crowding and passing (Decision 84).**
   - Within a squad the rules are unchanged, in the squad's own frame.
   - One unit per cell, claimed ahead; earlier claim wins, ties to the lower squad id.
   - Friends overtake within the corridor or queue; at crossings, first claim goes.
   - Only routers (crush damage) and tiny units pass through friends.
7. **Terrain (Decision 85).**
   - Speed per cell from ground (`move_cost`), slope (uphill slower) and liquid depth in
     bands of unit height (under ¼ free, to ½ wading, to 1 slow wading, deeper swims).
   - A squad keeps the pace of its worst leading cell.
   - Cliffs need climbing; capped ground, structures and deep liquid block non-swimmers.
   - High ground gives a melee bonus (its size waits for spec 28's damage steps).
   - Gaps narrow a squad into a column, front band first; oversized units go round.
8. **The feel test (Decision 86).** One scene, a flank attack on a held line (128 × 64
   cells, routes A over grass and B through a wood, a hill and a ford), growing by
   round:
   1. 2D positions, facings, turning, routes; today's frontal combat
   2. fronts on four edges, wings, step-up per edge
   3. morale, shock, rout, leadership
   4. terrain speed, slope, liquids, narrowing
   5. later: stands in the painter, horde and mob, tactic traits

## Agenda for the design conversation

1. **Position and facing.** A squad has a 2D position (cells) and a facing. Does a squad
   turn as a block (wheel, about-face), and how fast compared with marching? Does it hold
   its painted shape while turning?
2. **Paths.** Squads follow a lane's route as a 2D path rather than a distance. What leaves
   the route (flanking, going round an enemy, entering a node's area), and who decides,
   given unit AI and light control?
3. **Contact and fronts.** Contact happens wherever units meet, not only front to front.
   - A squad hit from the side or rear: do the units there turn to face it, or does the
     squad wheel?
   - Does a squad fight on more than one front at once, and how does step-up work per
     front?
4. **Flanks and wrap.** Today's flank wrap becomes real movement round the ends of a line.
   How far will units go to wrap, and does discipline (Decision 52) limit it?
5. **Stands in 2D.** A stand is 2 × 2 cells that may hold fewer units. Is a stand a unit
   of movement and facing, or only of painting, with units moving on their own once
   deployed?
6. **Crowding and passing.** Passing through friends (Decision 46) and lateral spread
   (Decision 51) in 2D: is the rule unchanged, just applied in two axes?
7. **Terrain.** Is speed per cell affected by ground and slope? Are there impassable cells
   (water, walls) and chokepoints, and how do squads squeeze through a gap narrower than
   their width?
8. **The feel test.** What scenario shows this best: a flank attack, a fight at a
   crossroads, or reinforcement from two directions?

## Rounds

Decision 86's table sets what each round adds to the one feel-test scene.

### Round 1: squads in 2D (built; feel test pending)

A squad keeps its distance along its own route (Decision 75) and takes its 2D place and
facing from it. On a straight east-west route, turning by facing gives exactly the lane's
numbers (the west-facing squad's mirror included), so the one-lane feel test and its tests
are unchanged. Squads on different routes meet through 2D geometry. Four stacked PRs:
1. **Building blocks** (PR #56): `FormationRoute` (a path of cells; point, heading and
   nearest facing at a distance; corridor), `SquadFrame` (four facings; a unit's cells
   from the front centre, turned not mirrored; lateral interval; gap along a facing) and
   `SquadTurn` (wheel time from the outer end's quarter arc; the about-face pause;
   reversing ranks and columns). New files only.
2. **Squads on routes:** squads gain a route, facing and position; contact and stop-behind
   measured along the facing in cells, frontal only (opposite facings); units gain a 2D
   position.
3. **Turning:** a turning state; wheels at bends; about-face on retreat and on advancing
   again; a turning squad neither advances nor strikes, and blows on it are flank blows.
4. **The 2D scene:** `FormationField` (one sim, routes A and B, the kingdom line holding on
   A) and a top-down scene. In round 1, route B rejoins A before the line so its wave
   reinforces from behind; round 2 redraws it onto the line's side.

Run it with `godot --path . res://presentation/skirmish/formation_2d/formation_field.tscn`:
Send A / Send B (or Auto) and watch the waves march, wheel at the bends and meet the
line. With the content's grems and militia an 8-grem wave just loses to the 8-wide
militia line (the one-lane balance); route B's longer way means it arrives after A's
wave has fallen unless both are sent together. Feel-testing in a window is for the user
or the local agent.

### Round 2: fronts, wings and coordination (built; feel test pending)

Decision 86's round 2 plus Decision 87, in four stacked PRs:
1. **Fronts on four edges** (Decision 78): `SquadEdges` and `FormationEdges`. A squad whose
   front reaches a hostile's side or rear locks onto that edge; the edge's units turn and
   strike back; the first interval's blows are flank blows; a corner strikes back at one
   foe; the edge is whoever is outermost on it, and the attacker re-engages as it falls
   back. Advancers stop at sides and rears instead of passing through.
2. **Wings** (Decision 81): `FormationWings`, on with `walk_wings` (the one-lane test keeps
   its wrap). Front units past a narrower line's end walk round onto its sides, one per
   rank of its depth, strike on arrival (flank for one interval), draw the edge round, and
   walk back after. Side reach only until discipline.
3. **Coordination** (Decision 87): a detection range per unit type (`FormationSight`);
   hold-until staging (`FormationStaging`: sees partner, sees fight, fallback go or back);
   planned rendezvous (`FormationRendezvous`: the march predicted as run, wheels included).
4. **The scene:** route B runs through the wood and south onto the line's north side; the
   line is 6 wide so an 8-wide wave sends wings; "B waits for A" stages B in the wood
   until it sees a friend fighting; "Send together" times both to reach the line at once.

Signals beyond sight come with the tech work; morale, shock and leadership are round 3.

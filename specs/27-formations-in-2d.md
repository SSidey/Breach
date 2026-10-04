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

**Design conversation done.** All eight agenda subjects are agreed (see Agreed below), and
the round 4 feel test's follow-ups (Decisions 88-91). Rounds 1 to 5 are built; the feel
test of the whole stack is next.

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
9. **After the round 4 feel test (Decisions 88–91).**
   - Both sides seek contact: a unit with no enemy in reach moves to the nearest open
     cell next to an enemy, diagonals included. The order sets the leash; contested
     cells go by `(arrival time, roll + initiative, initiative, speed, unit's draw)`.
     Leadership sets cohesion (reacting sooner, shifting as a line), not restraint.
     Facing is per unit. This replaces the position rules of subjects 3 and 4.
   - Leaderless routers rally to a steady friendly formation they pass (Decision 89).
   - Merging needs a merge order at a shared node, led by the best leader (Decision 90).
   - A tile is its ground plus cover features, which spill with soft edges and clearings
     (Decision 91).
   - A formation's discipline, bolstered by leadership, decides whether it re-forms to
     meet a flank closing in (marching or holding) and how long re-forming takes; a turn
     is a re-form (Decision 92).
   - Battles vary by a battle seed (damage rolls ±25% as a placeholder); a Monte Carlo
     runner measures the spread (Decision 93).
   - Tactical over strategic: combat, then the route, then re-forming, then the player's
     order; a formation halted without an order moves to a fight nearby or back to its
     march (Decision 94).

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

### Round 3: morale, rout and leaders (built; feel test pending)

Decisions 81, 82 and 87, in four stacked PRs (numbers are placeholders, morale 0 to 100):
1. **Morale and shock** (`FormationMorale`): a ceiling of mean courage plus 10 per point of
   the best leader's leadership; side (15), rear (30) and wing (10) impact; 4 per own loss,
   10 per point of a fallen leader's leadership; pressure each second by sides fought on
   (two 3, three 9, four 18), less where a friend covers a side; recovery out of contact.
   Shaken squads send no wings; wavering ones strike half again more slowly.
2. **Rout** (`FormationRout`): at 0 a formation breaks; its units flee home along the
   route, strike nothing and are struck from behind; they crush friends they run through
   (and panic them), rally into a led formation, or re-form round their own leader with no
   enemy near; routers reaching home leave the field (the player's return to the reserve).
3. **Leaders**: units gain tactics; the grem chieftain (leadership 3, coordinated). A
   coordinated leader waiting to see its partner times its departure to arrive with it.
4. **The scene**: the kingdom's reserve holds on the hill; route B's wave carries a
   chieftain; "B waits for A" waits to see A's wave and lets the chieftain time the flank;
   morale bars, leaders and faded routers are drawn.

With the content's grems, militia and chieftain (12-militia line, 6-militia reserve):

| Case | Line left | Reserve left | Grems died | Outcome |
|---|---|---|---|---|
| A alone | 10 | 6 | 8 | A loses; the line holds |
| B alone (flank only) | 7 | 6 | 3 | a slow grind, unfinished |
| B waits, chieftain times it | 0 | 0 | 7 | the line routs into its reserve, which breaks too |
| Sent together | 0 | 0 | 6 | the same |

### Round 4: terrain (built; feel test pending)

Decision 85 and Decision 87's woods, in four stacked PRs (numbers are placeholders):
1. **Pace** (`FormationTerrain`): cells with a move cost, a height in quarters, a liquid
   depth and whether they block sight. Pace is the cost, less 10% per quarter-cell risen
   (more than a cell is a cliff), and slower in liquid by bands of the unit's height
   (under a quarter free, to a half 0.6, to its height 0.3, deeper impassable). A squad
   keeps the pace of the worst cell its front rank steps into; one that can't go on halts
   ("blocked").
2. **Sight and high ground**: a sight line crossing more than two sight-blocking cells is
   blocked (a wood's edge sees out; its depths hide); a striker higher than its target
   hits x1.25.
3. **Narrowing** (`FormationNarrowing`): a squad wider than the passable run ahead folds
   into a column that fits (front band first), holds a second, passes, and widens back to
   its painted places; a unit too wide for the gap halts it ("too_wide").
4. **The field**: the wood (half pace, blocks sight), route B along its southern edge, a
   stream too deep for grems with a 4-cell ford on route B, and the hill under the
   reserve. B's 8-wide wave narrows through the ford; it waits at the wood's edge where it
   can see out. Planned rendezvous and coordinated leaders predict marches over terrain,
   narrowing included.

The comparison holds on terrain: A alone loses and the line holds; B alone grinds; B
waiting (chieftain-timed) or both sent together break the line into its reserve, for 6
grems.

### Round 5: after the round 4 feel test (built; feel test pending)

The fixes and Decisions 88 and 89, raised by the user's round 4 feel test, in four
stacked PRs:
1. **The ford** (bug): a partial wave keeps its painted columns, so a single unit could
   stand off to one side of a ford it is narrower than, and halt at deep water. Narrowing
   now checks that the line lies within the gap, not only that it is narrower.
2. **Contact-seeking** (`FormationScrum`, Decision 88; on in the field, off on the one
   lane):
   - In a fight every unit walks to the nearest open cell next to an enemy, diagonals
     included, round friends and never through an enemy (`ScrumPaths`), within the
     route's leash of its place (16 cells), so the far end of a flanked line comes to
     meet the flank, whatever its order. Front-band units seek; back-band units too once
     no front-band unit is left. A wavering squad stops seeking.
   - Contested cells go by `(arrival, roll + initiative, initiative, speed, draw)`
     (`ScrumContest`; a die of 10 and initiative 10 as placeholders).
   - Each unit strikes one enemy it touches, its front first, and turns to it; a blow
     from outside the target's front is a flank blow (`ScrumBlows`, `ScrumReach`).
   - Units start seeking 1.5 s after the fight begins, divided by one plus leadership.
   - A led squad with a free front that sees an enemy coming at another face turns its
     line to meet it before contact (`ScrumStance`), from 4 cells plus 4 per point of
     leadership.
   - A fight where nobody on either side has touched or sought a foe for 2 s is released,
     so it can't freeze (the lone-flank freeze); after a fight units regroup before the
     squad moves on.
3. **Rally** (Decision 89): a router running into a steady leaderless friend (within a
   cell, after crushing) is caught there and joins its rear after 3 s; a shaken friend
   doesn't stop it.
4. **The field and scene**: "Line has a captain" restarts with a kingdom captain
   (leadership 2) in the line's second rank; each unit's front mark shows its own facing.

The comparison (1500 ticks after sending; line /12, reserve /6, grems lost):

| Case | Round 4 | Round 5, leaderless line | Round 5, captained line |
|---|---|---|---|
| A alone | line 10, 8 lost | line 10, 8 lost | line 10, 8 lost |
| B alone | **froze**: line 7, 3 lost | line 5, 9 lost | line 10, 9 lost |
| B waits (chieftain) | line broken, reserve routed, 6 lost | line broken, reserve 3, 8 lost | line broken, reserve 5, 8 lost |
| Sent together | line broken, reserve routed, 6 lost | line broken, reserve 7 (2 rallied), 9 lost | line broken, reserve 6, 9 lost |

- Coordinated attacks still break the line, but cost more: the whole line now fights, and
  the reserve catches its routers instead of being swept away by them.
- A lone B flank no longer freezes; it loses to a line half again its size. A captained
  line meets it as a line and loses only two.

### Round 6: after the round 5 feel test (built; feel test pending)

The fixes and Decisions 92 and 93, raised by the user's round 5 feel test, in four
stacked PRs:
1. **Fixes:**
   - a partial wave is centred on its route; it no longer marches in its painted columns
     beside the line
   - with contact-seeking, squads whose units come within a cell of each other fight,
     whatever their faces (`ScrumEngage`)
   - a waiting wave ignores waves on its own route as partners
   - a squad closes ranks over its dead when its fight ends (`SquadRanks`)
   - a squad re-forms only for an enemy closing in, not one holding its ground; this
     fixes the merged B stuck facing the reserve
2. **Variance** (Decision 93):
   - every random draw comes from the battle seed
   - each blow's damage rolls ±25% (placeholder)
   - `BattleTrials` and `tools/formation_trials.gd` fight a scenario once per seed and
     report the spread, including mirror scenarios
3. **Discipline** (Decision 92):
   - units have discipline (placeholder 30); a formation's is its mean plus 10 per point
     of leadership
   - at 50 or more it re-forms as a whole to meet an enemy closing in within 12 cells,
     marching or holding
   - nothing waits before acting; re-forming runs at 40% to 150% of the march pace by
     discipline
   - a turn is a re-form: the squad takes its new facing and its units walk to their new
     places (`ScrumTurn`)
4. **The scene** (`FormationFieldHud`):
   - Reset, with a battle seed typed in or random, keeping the ticked options
   - the seed in the status row
   - leaders counted apart ("B 8/8 + leader 1/1")
   - "A goes via C": a slanted route (2 across for every 3 up) onto A's lane

Trials (30 seeds each, ±25% damage). Losses in the field are counted until the line
breaks:

| Scenario | Wins (player / kingdom) | Player lost | Kingdom lost |
|---|---|---|---|
| 8 v 8 head-on | 13 / 15 (2 both wiped out) | 6.8 ± 1.5 | 7.0 ± 1.3 |
| 8 onto the side of a line of 8 | 30 / 0 | 2.9 ± 1.1 | 8.0 |
| Field: A alone | 0 / 30 | 8.0 | 3.4 ± 0.7 |
| Field: B alone | 4 / 26 | 8.9 ± 0.3 | 8.6 ± 2.7 |
| Field: B alone, line captained | 0 / 30 | 9.0 | 3.6 ± 0.9 |
| Field: B waits | 30 / 0 | 6.8 ± 1.0 | 8.9 ± 2.3 |
| Field: together | 30 / 0 | 1.8 ± 1.2 | 7.9 ± 0.5 |

- Head-on mirrors are even. A flank on a line that doesn't turn to meet it wins every time
  for a third of the losses. That is the measure of the flank, and the case for discipline.
- On the slant, a squad keeps its nearest facing and steps sideways along the route; more
  facings wait on the feel test.
- Not built yet: planned rendezvous still times a turn as a wheel (off by up to half a
  second), and formation contests (Decision 92) have no case in the field yet.

### Round 7: tactical over strategic (built; feel test pending)

Decision 94, raised by the round 6 feel test: a disciplined B re-forming at its corner as
A engaged took the line (facing A, so "towards" B) for a threat closing in, turned to
meet it and stayed there, off its route.
- `FormationManoeuvre`: every formation always has a current manoeuvre, the
  highest-priority one that applies, settled each tick (the user: no list of exceptions,
  "an army should always have a current manoeuvre"):
  0. **combat:** locked in melee, front or flank, or skirmishing with an enemy in range;
     contact mid-re-form goes straight here
  1. **route** and 2. **re-form:** its units walk back to their places on its route at
     its discipline's pace - after a fight, a turn, narrowing at a gap (now a re-form, not
     a fixed 1 s hold), or to face a threat
  3. **order:** march, hold, retreat or wait; it marches only on this
- Facing a threat is a re-form held only while that enemy keeps closing in (or, under a
  hold order, is still near); any formation lets go of it otherwise, so a wave re-forms
  and marches on rather than standing off its route.
- Open: whether a retreat order can pull a formation out of melee (today it disengages at
  once).

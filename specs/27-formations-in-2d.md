# Spec 27: Formations in 2D

Decisions 73 (the formation model is the game's simulation), 70 (stands), 52 (squads on a
2D cell grid), 69 (light control, unit AI) and 74 (position and facing).

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

**Design conversation under way.** The user takes design questions one subject at a
time. Subject 1 is agreed (see Agreed below); the rest of the agenda is a starting point,
not decided.

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

None yet. The first round is planned once the agenda is settled.

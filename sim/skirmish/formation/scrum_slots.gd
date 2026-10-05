class_name ScrumSlots
extends RefCounted
## Finding a place in the scrum (Decisions 88 and 106, spec 30 round 1): round each foe's
## body, the slots where a seeker's body would touch it - as many as fit round it (6 for a
## grem round a grem, 9 round a brute), laid out from the foe's own front, clockwise. A
## seeker makes for the nearest open slot within the leash of its place (Decision 75): one
## no other body stands on, no seeker nearer in the contest (ScrumContest) has claimed, and
## on ground it can cross. Equally near slots go by the seeker's own frame - the one most
## ahead of it, then the one nearest its place - then by the foes' draws (Decision 97). It
## walks straight there, bodies parting round it (UnitBodies). Pure; cells.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

## Cells a unit may go from its place (Decision 75's leash; placeholder).
const LEASH := 16.0
const EPSILON := 0.000001


## [[where, radius, unit], ...]: every living unit's body in standing squads.
static func bodies(squads: Array) -> Array:
	var out := []
	for squad in squads:
		if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		for unit in squad.living():
			out.append([ScrumReach.at(squad, unit), ScrumReach.radius(unit), unit])
	return out


## [[point, foe unit, foe squad, slot number], ...] round the foes ([[unit, squad], ...])
## for a seeker of body radius `radius`.
static func round_foes(foes: Array, radius: float) -> Array:
	var out := []
	for entry in foes:
		var foe: SkirmishUnit = entry[0]
		var centre := ScrumReach.at(entry[1], foe)
		var reach := ScrumReach.radius(foe) + radius
		var count := maxi(3, floori(PI * reach / radius + EPSILON))
		for slot in range(count):
			var way := UnitMotion.vector(foe.bearing + slot * 360.0 / count)
			out.append([centre + way * reach, foe, entry[1], slot])
	return out


## Cells from `at` to the nearest foe body's edge, less the seeker's own radius (0 if it
## touches one); INF with no foes.
static func gap_to(at: Vector2, radius: float, foes: Array) -> float:
	var least := INF
	for entry in foes:
		var edge := ScrumReach.at(entry[1], entry[0]).distance_to(at)
		least = minf(least, edge - ScrumReach.radius(entry[0]) - radius)
	return maxf(least, 0.0)


## The slot (as round_foes gives it) the seeker at `at` makes for, or [] if none is open.
## `ground` is [its place, the bodies, the claimed points, the terrain or null, the seed].
static func pick(seeker: SkirmishUnit, at: Vector2, slots: Array, ground: Array) -> Array:
	var ahead := UnitMotion.vector(seeker.bearing)
	var best := []
	var best_key := []
	for slot in slots:
		if not open(seeker, slot[0], ground):
			continue
		var key := [
			snappedf(at.distance_to(slot[0]), 0.000001),
			-snappedf((slot[0] - at).dot(ahead), 0.000001),
			snappedf(slot[0].distance_to(ground[0]), 0.000001),
			ScrumContest.draw(slot[1], ground[4]),
			slot[3],
		]
		if best.is_empty() or key < best_key:
			best = slot
			best_key = key
	return best


## True if the seeker may take the slot at `point`: within its leash, on ground it can
## cross, with no other body on it and no claim within a body's breadth of it.
static func open(seeker: SkirmishUnit, point: Vector2, ground: Array) -> bool:
	if point.distance_to(ground[0]) > LEASH:
		return false
	var terrain: FormationTerrain = ground[3]
	if terrain != null and terrain.factor(seeker.height, point, point) <= 0.0:
		return false
	var radius := ScrumReach.radius(seeker)
	for body in ground[1]:
		if body[2] != seeker and body[0].distance_to(point) < body[1] + radius - EPSILON:
			return false
	for claim in ground[2]:
		if claim.distance_to(point) < 2.0 * radius - EPSILON:
			return false
	return true

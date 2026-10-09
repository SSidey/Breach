class_name UnitSteer
extends RefCounted
## Steering round bodies (Decision 114, spec 30 round 2): a unit walking to a goal whose
## straight way there runs into a body that won't part for it - a foe's, or another squad's
## (its own squad's part: UnitBodies) - within a few cells (bodies_steer_look, BattleTuning)
## steps round the nearest such body, on the side the body leans least into its way - the
## side nearer its goal - aiming to graze it just clear; past it, it walks straight on. A
## body dead centre in its way is passed on the side a seeded draw picks (Decision 97: no
## handedness, never the list). A body standing on the goal itself is left to the bodies
## parting (UnitBodies). One rule for seekers, regrouping units and stragglers. Pure; cells.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const BodyGrid = preload("res://sim/skirmish/formation/body_grid.gd")
const DetMath = preload("res://sim/skirmish/formation/det_math.gd")

const EPSILON := 0.000001


## The point the unit at `at` heads for this step on its way to `goal`: the goal, or a
## point beside the body in its way. `bodies` = [[point, radius, unit], ...] (ScrumSlots);
## `crowd`, a BodyGrid.of_bodies over them if given, keeps the look to those near.
static func toward(
	unit: SkirmishUnit,
	at: Vector2,
	goal: Vector2,
	bodies: Array,
	fight_seed: int,
	crowd: Dictionary = {}
) -> Vector2:
	var way := goal - at
	var length := way.length()
	if length < EPSILON:
		return goal
	var ahead := way / length
	var across := ahead.orthogonal()
	var own := ScrumReach.radius(unit)
	var best := []
	var look := BattleTuning.current().bodies_steer_look
	for body in _near(bodies, crowd, at, at + ahead * minf(length, look), own):
		if body[2].squad_id == unit.squad_id:
			continue  # itself, or its own squad's: they part for it
		var clearance: float = own + body[1]
		if body[0].distance_to(goal) < clearance - EPSILON:
			continue  # it stands on the goal: bodies part (UnitBodies)
		var along: float = (body[0] - at).dot(ahead)
		var aside: float = (body[0] - at).dot(across)
		if along <= EPSILON or along >= minf(length, look) or absf(aside) >= clearance - EPSILON:
			continue
		var key := snappedf(along, EPSILON)  # then the body's draw, weighed only on a tie
		if (
			best.is_empty()
			or key < best[0]
			or (key == best[0] and _drawn_first(body[2], best[1][2], fight_seed))
		):
			best = [key, body, aside, clearance]
	if best.is_empty():
		return goal
	var side := -signf(best[2])
	if absf(best[2]) < EPSILON:  # dead centre: a seeded draw picks the side
		var keys := [
			ScrumContest.draw(unit, fight_seed), ScrumContest.draw(best[1][2], fight_seed), "steer"
		]
		side = 1.0 if BattleRolls.uniform(fight_seed, keys) < 0.5 else -1.0
	return _round(
		at, best[1][0], best[3] + BattleTuning.current().bodies_steer_clear, across * side
	)


## True if `unit`'s draw goes before `other`'s.
static func _drawn_first(unit: SkirmishUnit, other: SkirmishUnit, fight_seed: int) -> bool:
	return ScrumContest.draw(unit, fight_seed) < ScrumContest.draw(other, fight_seed)


## The point where the unit's way from `at` grazes a circle of `reach` about `centre` on the
## `side` given (its tangent), or the point beside the centre that way if it is already
## that near.
static func _round(at: Vector2, centre: Vector2, reach: float, side: Vector2) -> Vector2:
	var to_centre := centre - at
	var gap := to_centre.length()
	if gap <= reach + EPSILON:
		return centre + side * reach
	var angle := DetMath.asin(reach / gap)
	var turned := DetMath.rotated(to_centre.normalized(), angle)
	var other := DetMath.rotated(to_centre.normalized(), -angle)
	if other.dot(side) > turned.dot(side):
		turned = other
	return at + turned * sqrt(gap * gap - reach * reach)


## The bodies that could stand within a body's breadth (`own` and theirs) of the way from
## `at` to `end`, in the list's order: all of them without a crowd.
static func _near(bodies: Array, crowd: Dictionary, at: Vector2, end: Vector2, own: float) -> Array:
	if crowd.is_empty():
		return bodies
	var out := []
	for found in BodyGrid.near(crowd, at, own + crowd["widest"] + 0.01, end):
		out.append(bodies[found])
	return out

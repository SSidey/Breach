class_name UnitBodies
extends RefCounted
## Bodies (Decision 106, spec 30 round 1): a unit's body is the circle inscribed in its
## footprint - a grem 1 cell across, a brute 2 - and no two bodies overlap. After every
## move each tick, each pair whose bodies overlap is pushed apart the shortest way:
## - **Friends** split the push by mass (footprint area): a brute moves a grem more than a
##   grem moves a brute. A unit in its formation's frame resists, RESIST times its mass,
##   but gives way: pushed, it leaves its place and walks back to it (its squad re-forms).
## - **Foes** are not pushed (Decision 105): two that overlap - one shoved into the other by
##   its friends - each step back half the overlap, so no one is pushed into an enemy.
## - **Two units both in their frames** are kept apart by the frames (their own places, and
##   friends queueing between squads: Decision 84).
## Pushes are worked out from one snapshot, then applied together, PASSES times a tick; a
## pair whose bodies lie exactly on each other parts along an angle seeded by the battle
## and the two units, never by a world direction or the list (Decision 97). Pure over the
## squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")

## How many times over a unit in its frame weighs, against being pushed (placeholder).
const RESIST := 4.0
const PASSES := 3
## Cells a bucket of the pair search spans: at least the widest body.
const BUCKET := 2.0
const EPSILON := 0.000001


## The body's radius in cells.
static func radius(unit: SkirmishUnit) -> float:
	return minf(unit.footprint_width, unit.footprint_depth) / 2.0


## Where the unit's body stands: its point in the scrum or in flight, or its place.
static func at(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	if squad.fleeing.has(unit.id):
		return FormationRout.where(squad, unit.id)
	if squad.loose.has(unit.id):
		return squad.loose[unit.id]["at"]
	return unit.position


## Pushes apart every pair of bodies that overlap.
static func step(squads: Array, fight_seed: int) -> void:
	for _pass in range(PASSES):
		var bodies := _bodies(squads, fight_seed)
		var moves := {}  # body index -> how far it is pushed
		for pair in _pairs(bodies):
			_push(bodies, pair, fight_seed, moves)
		if moves.is_empty():
			return
		for index in moves:
			_move(bodies[index], moves[index])


## [[squad, unit, where, its draw], ...] for every living unit of a standing squad, in the
## order of their draws (not the list's).
static func _bodies(squads: Array, fight_seed: int) -> Array:
	var out := []
	for squad in squads:
		if squad.state == SkirmishSquad.State.DESTROYED:
			continue
		for unit in squad.living():
			out.append([squad, unit, at(squad, unit), ScrumContest.draw(unit, fight_seed)])
	out.sort_custom(func(a, b): return a[3] < b[3])
	return out


## [[i, j], ...] for bodies near enough to overlap, i < j, found through buckets.
static func _pairs(bodies: Array) -> Array:
	var buckets := {}
	for index in range(bodies.size()):
		var key := Vector2i((bodies[index][2] / BUCKET).floor())
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(index)
	var out := []
	for index in range(bodies.size()):
		var home := Vector2i((bodies[index][2] / BUCKET).floor())
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for other in buckets.get(home + Vector2i(dx, dy), []):
					if other > index and not (_framed(bodies[index]) and _framed(bodies[other])):
						out.append([index, other])
	out.sort()
	return out


## True if the unit stands in its formation's frame (neither loose nor fleeing).
static func _framed(body: Array) -> bool:
	return not body[0].loose.has(body[1].id) and not body[0].fleeing.has(body[1].id)


## Adds the pair's push to `moves`: each body out along the line between them - friends
## by the other's share of their mass, foes half each.
static func _push(bodies: Array, pair: Array, fight_seed: int, moves: Dictionary) -> void:
	var a: Array = bodies[pair[0]]
	var b: Array = bodies[pair[1]]
	var apart: Vector2 = b[2] - a[2]
	var depth := radius(a[1]) + radius(b[1]) - apart.length()
	if depth <= EPSILON:
		return
	var way := apart.normalized()
	if apart.length() < EPSILON:
		way = Vector2.RIGHT.rotated(TAU * BattleRolls.uniform(fight_seed, [a[3], b[3], "part"]))
	var share := 0.5
	if a[0].faction_id == b[0].faction_id:
		share = _mass(b) / (_mass(a) + _mass(b))
	moves[pair[0]] = moves.get(pair[0], Vector2.ZERO) - way * depth * share
	moves[pair[1]] = moves.get(pair[1], Vector2.ZERO) + way * depth * (1.0 - share)


## What a body weighs against a push: its footprint's area, RESIST times over in its frame.
static func _mass(body: Array) -> float:
	var unit: SkirmishUnit = body[1]
	var area := float(unit.footprint_width * unit.footprint_depth)
	return area * RESIST if _framed(body) else area


## Moves the body by `push`: a router's flight, a loose unit's point, or - for one in its
## frame - out of its place, to walk back to it.
static func _move(body: Array, push: Vector2) -> void:
	var squad: SkirmishSquad = body[0]
	var unit: SkirmishUnit = body[1]
	if squad.fleeing.has(unit.id):
		squad.fleeing[unit.id]["offset"] += push
		return
	if not squad.loose.has(unit.id):
		squad.loose[unit.id] = {"unit": unit, "at": body[2], "goal": null, "next": body[2]}
	var entry: Dictionary = squad.loose[unit.id]
	var resting: bool = entry["next"] == entry["at"]
	entry["at"] += push
	if resting:
		entry["next"] = entry["at"]

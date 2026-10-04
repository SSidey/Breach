class_name ScrumSpacing
extends RefCounted
## One unit to a cell in the scrum (spec 27 round 9): after everyone has moved, a unit that
## has come to rest in a cell another unit stands in - not one stepping on to a cell it is
## seeking - steps towards the nearest free cell (ties going towards its own place) at the
## march pace. Only friends are parted (foes are kept apart by contact); the one nearer the
## cell's centre stays, an exact tie going by the units' draws (ScrumContest), never by
## spawn order. Units may pass through friends, but not stop on them. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumPaths = preload("res://sim/skirmish/formation/scrum_paths.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

## How far (cells, in rings) a unit looks for a free cell.
const RING := 2


## Moves units sharing a cell apart; `pace` is cells a tick at speed 1.
static func step(squads: Array, pace: float, fight_seed: int) -> void:
	var first := {}  # [cell, faction] -> the unit that keeps it
	var crowded := []  # [squad, unit]
	var units := []
	for squad in squads:
		if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		for unit in squad.living():
			units.append([squad, unit, _claim(squad, unit, fight_seed)])
	units.sort_custom(func(a, b): return a[2] < b[2])
	for pair in units:
		var spot := [ScrumReach.cell(ScrumReach.at(pair[0], pair[1])), pair[0].faction_id]
		if first.has(spot):
			crowded.append(pair)
		else:
			first[spot] = true
	if crowded.is_empty():
		return
	var cells := _held(squads)
	var taken := {}
	for pair in crowded:
		_step_aside(pair[0], pair[1], cells, taken, pace)


## cell -> how many standing units cover it.
static func _held(squads: Array) -> Dictionary:
	var out := {}
	for squad in squads:
		if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		for unit in squad.living():
			for spot in ScrumPaths.cells_of(ScrumReach.area(squad, unit)):
				out[spot] = out.get(spot, 0) + 1
	return out


## A unit's claim on the cell it stands in: lower is stronger.
static func _claim(squad: SkirmishSquad, unit: SkirmishUnit, fight_seed: int) -> Array:
	var at := ScrumReach.at(squad, unit)
	var off := snappedf(at.distance_to(ScrumReach.centre(ScrumReach.cell(at))), 0.001)
	return [off, ScrumContest.draw(unit, fight_seed)]


static func _step_aside(
	squad: SkirmishSquad, unit: SkirmishUnit, cells: Dictionary, taken: Dictionary, pace: float
) -> void:
	if not squad.loose.has(unit.id):
		return  # in its formation's frame: its places are its own cells
	var entry: Dictionary = squad.loose[unit.id]
	if entry.get("goal") != null or entry.get("touch", false):
		return  # passing through on its way to a cell it is seeking, or holding its foe
	var at: Vector2 = entry["at"]
	var ahead := UnitMotion.vector(unit.bearing)
	var others := cells.duplicate()  # its own body never blocks the cell it looks for
	for own in ScrumPaths.cells_of(ScrumReach.area(squad, unit)):
		others[own] = others.get(own, 0) - 1
	var spot := _free_near(at, ScrumStance.anchor(squad, unit), ahead, others, taken)
	entry["at"] = at.move_toward(spot, unit.speed * pace)
	entry["next"] = entry["at"]


## The centre of a free cell next to `at` (`cells`: cell -> other units covering it), or
## `at` if none: the nearest, ties going to the one nearest the unit's own place, then the
## one furthest behind it (`ahead` is its bearing), so neither side steps towards the
## other by default.
static func _free_near(
	at: Vector2, place: Vector2, ahead: Vector2, cells: Dictionary, taken: Dictionary
) -> Vector2:
	var home := ScrumReach.cell(at)
	var best := at
	var best_key := [INF, INF, INF]
	for dy in range(-RING, RING + 1):
		for dx in range(-RING, RING + 1):
			var spot := home + Vector2i(dx, dy)
			if cells.get(spot, 0) > 0 or taken.has(spot):
				continue
			var centre := ScrumReach.centre(spot)
			var key := [
				maxi(absi(dx), absi(dy)),
				snappedf(centre.distance_to(place), 0.001),
				snappedf(Vector2(dx, dy).dot(ahead), 0.001)
			]
			if key < best_key:
				best_key = key
				best = centre
	taken[ScrumReach.cell(best)] = true
	return best

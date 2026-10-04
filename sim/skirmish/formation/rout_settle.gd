class_name RoutSettle
extends RefCounted
## One unit to a cell for routers coming to rest (spec 27 round 9): with contact-seeking, a
## router caught by a steady friend steps to the nearest free cell rather than standing
## inside a friend, and one that joins a formation walks from where it stands to its place
## in the ranks rather than appearing there. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumPaths = preload("res://sim/skirmish/formation/scrum_paths.gd")

## How far (cells, in rings) a caught router looks for a free cell.
const LOOK := 3


## The centre of the nearest cell to `at` that no standing unit covers and no other
## settling router has taken (`taken` is updated); `at` itself if none is free near.
static func free_spot(at: Vector2, cells: Dictionary, taken: Dictionary) -> Vector2:
	var home := ScrumReach.cell(at)
	var best := at
	var best_gap := INF
	for dy in range(-LOOK, LOOK + 1):
		for dx in range(-LOOK, LOOK + 1):
			var spot := home + Vector2i(dx, dy)
			if cells.has(spot) or taken.has(spot):
				continue
			var gap := ScrumReach.centre(spot).distance_to(at)
			if gap < best_gap:
				best_gap = gap
				best = ScrumReach.centre(spot)
	taken[ScrumReach.cell(best)] = true
	return best


## Caught routers step towards the nearest free cell. `where` (squad, unit id) -> Vector2
## gives a router's point (FormationRout.where).
static func settle(squad: SkirmishSquad, squads: Array, pace: float, where: Callable) -> void:
	var cells := {}
	var taken := {}
	for unit in squad.living():
		var entry: Dictionary = squad.fleeing[unit.id]
		if entry.get("caught", 0) <= 0:
			continue
		if cells.is_empty():
			cells = ScrumPaths.occupancy(squads)
		var at: Vector2 = where.call(squad, unit.id)
		var spot := free_spot(at, cells, taken)
		entry["offset"] += at.move_toward(spot, unit.speed * pace) - at
		entry["settled_at"] = where.call(squad, unit.id)


## A rallied unit joins `leader` where it stands and walks to its place (its re-form).
static func walk_in(leader: SkirmishSquad, unit: SkirmishUnit, at: Vector2) -> void:
	leader.loose[unit.id] = {"unit": unit, "at": at, "goal": null, "next": at}

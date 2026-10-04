class_name RoutSettle
extends RefCounted
## One unit to a cell for routers coming to rest (spec 27 round 9): with contact-seeking, a
## router caught by a friend steps to the nearest free cell behind that friend rather than
## standing inside it, and one that joins a formation walks from where it stands to its place
## in the ranks rather than appearing there. Every routing formation's caught routers
## settle together: the one nearest its cell's centre picks its cell first, a tie going to
## the units' seeded draws - never to the order they are listed in (Decision 97). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumPaths = preload("res://sim/skirmish/formation/scrum_paths.gd")
const RoutCatch = preload("res://sim/skirmish/formation/rout_catch.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")

## How far (cells, in rings) a caught router looks for a free cell.
const LOOK := 3


## The centre of the nearest cell to `at` that no standing unit covers and no other
## settling router has taken (`taken` is updated), and that `allowed` (centre -> bool)
## accepts if given; `at` itself if none is free near.
static func free_spot(
	at: Vector2, cells: Dictionary, taken: Dictionary, allowed: Callable = Callable()
) -> Vector2:
	var home := ScrumReach.cell(at)
	var best := at
	var best_gap := INF
	for dy in range(-LOOK, LOOK + 1):
		for dx in range(-LOOK, LOOK + 1):
			var spot := home + Vector2i(dx, dy)
			if cells.has(spot) or taken.has(spot):
				continue
			if allowed.is_valid() and not allowed.call(ScrumReach.centre(spot)):
				continue
			var gap := ScrumReach.centre(spot).distance_to(at)
			if gap < best_gap:
				best_gap = gap
				best = ScrumReach.centre(spot)
	taken[ScrumReach.cell(best)] = true
	return best


## The `routing` squads' caught routers step towards the nearest free cell. `where`
## (squad, unit id) -> Vector2 gives a router's point (FormationRout.where).
static func settle(
	routing: Array, squads: Array, pace: float, where: Callable, fight_seed: int = 0
) -> void:
	var caught := []  # [key, squad, unit, where it stands]
	for squad in routing:
		for unit in squad.living():
			if squad.fleeing[unit.id].get("caught", 0) <= 0:
				continue
			var at: Vector2 = where.call(squad, unit.id)
			var off := snappedf(at.distance_to(ScrumReach.centre(ScrumReach.cell(at))), 0.001)
			caught.append([[off, ScrumContest.draw(unit, fight_seed)], squad, unit, at])
	if caught.is_empty():
		return
	caught.sort_custom(func(a, b): return a[0] < b[0])
	var cells := ScrumPaths.occupancy(squads)
	var taken := {}
	for entry in caught:
		var unit: SkirmishUnit = entry[2]
		var fleeing: Dictionary = entry[1].fleeing[unit.id]
		var at: Vector2 = entry[3]
		var spot := free_spot(at, cells, taken, _behind_holder(entry[1], fleeing, squads))
		fleeing["offset"] += at.move_toward(spot, unit.speed * pace) - at
		fleeing["settled_at"] = where.call(entry[1], unit.id)


## Accepts a cell centre behind the formation holding the router (RoutCatch.behind), so
## it settles at the friend's back, not its front; any cell if none holds it.
static func _behind_holder(squad: SkirmishSquad, fleeing: Dictionary, squads: Array) -> Callable:
	for friend in squads:
		if friend.id == fleeing.get("held_by") and not friend.living().is_empty():
			return func(centre: Vector2) -> bool:
				return friend.living().all(
					func(u): return RoutCatch.behind(squad, centre, ScrumReach.at(friend, u))
				)
	return Callable()


## A rallied unit joins `leader` where it stands and walks to its place (its re-form).
static func walk_in(leader: SkirmishSquad, unit: SkirmishUnit, at: Vector2) -> void:
	leader.loose[unit.id] = {"unit": unit, "at": at, "goal": null, "next": at}

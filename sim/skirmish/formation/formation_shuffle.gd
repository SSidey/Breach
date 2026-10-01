class_name FormationShuffle
extends RefCounted
## Re-forming (Decisions 46 and 49, specs/22-formation-feel-test.md): after a reinforcement
## or a death, units move toward the places their band prefers.
## - **Into free space first.** A front-preferring unit behind the front takes the nearest
##   free place in the front rank, moving sideways or diagonally if need be.
## - **Otherwise through.** A unit with a stronger claim (its band further forward, or the
##   same band and a higher priority) moves forward a rank past the units directly ahead in
##   its columns. Passed units that fit take its back row; any too wide or too deep move
##   back, through the formation, to the nearest free space that fits them.
## - **How long:** as far as the furthest unit travels, at the slowest involved unit's
##   speed, slowed by crowding while the squad fights (and later by terrain).
## - **No ground ceded mid-move:** until a move completes everyone keeps their place, and
##   keeps fighting. A death of anyone involved cancels it.
## A squad re-forms until no further move can start. Pure over the squad it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")

## How terrain changes the speed units pass one another at; 1 until lanes carry terrain.
const TERRAIN_FACTOR := 1.0
## Moving within a fighting squad is slowed by the crush (Decision 48).
const CROWDING := 0.2
## How far behind its place a passed unit may look for free space.
const SEARCH_RANKS := 64
const EPSILON := 0.000001


## True if `unit` has the stronger claim to a forward place than `other`.
static func stronger(unit: SkirmishUnit, other: SkirmishUnit) -> bool:
	if unit.preferred_position != other.preferred_position:
		return unit.preferred_position < other.preferred_position
	return unit.position_priority > other.position_priority


## One tick: active moves cancel, count down or complete; then a re-forming squad starts
## every move it can, and stops re-forming once nothing is moving. Returns "swapped" events.
static func step(
	squad: SkirmishSquad, tick_seconds: float, travel_scale: float, tick: int
) -> Array:
	var events := []
	for index in range(squad.swaps.size() - 1, -1, -1):
		var swap: Dictionary = squad.swaps[index]
		if swap["to"].keys().any(func(u): return not u.is_alive()):
			squad.swaps.remove_at(index)
			continue
		swap["ticks"] -= 1
		if swap["ticks"] > 0:
			continue
		for unit in swap["to"]:
			unit.rank = swap["to"][unit].x
			unit.column = swap["to"][unit].y
		squad.swaps.remove_at(index)
		var ids: Array = swap["passed"].map(func(u): return u.id)
		events.append(
			FormationEvents.unit_event("swapped", tick, squad, swap["mover"], {"passed": ids})
		)
	if squad.reforming and not _start_moves(squad, tick_seconds, travel_scale):
		squad.reforming = not squad.swaps.is_empty()
	return events


## How far a unit is through a move: Vector2(ranks forward, columns across).
static func offset(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	for swap in squad.swaps:
		if swap["to"].has(unit):
			var progress := 1.0 - float(swap["ticks"]) / float(swap["total"])
			var from: Vector2i = swap["from"][unit]
			var to: Vector2i = swap["to"][unit]
			return Vector2((from.x - to.x) * progress, (to.y - from.y) * progress)
	return Vector2.ZERO


static func _start_moves(squad: SkirmishSquad, tick_seconds: float, travel_scale: float) -> bool:
	var claimed := {}  # Vector2i cell -> true: cells a planned move will occupy
	var busy := []
	for swap in squad.swaps:
		busy.append_array(swap["to"].keys())
		for unit in swap["to"]:
			_claim(claimed, swap["to"][unit], unit)
	var front_first := squad.living()
	front_first.sort_custom(
		func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.column < b.column)
	)
	var started := false
	for unit in front_first:
		if unit.rank == 0 or busy.has(unit):
			continue
		var plan := _into_free_front(squad, unit, claimed)
		if plan.is_empty():
			plan = _through(squad, unit, busy, claimed)
		if plan.is_empty():
			continue
		var involved: Array = plan["to"].keys()
		var slowest: float = involved.reduce(func(least, u): return minf(least, u.speed), INF)
		if slowest <= 0.0:
			continue
		var crowding := CROWDING if squad.state == SkirmishSquad.State.FIGHTING else 1.0
		var pace := travel_scale * slowest * TERRAIN_FACTOR * crowding
		var seconds: float = plan["distance"] * SkirmishSquad.RANK_DEPTH / pace
		var ticks := maxi(1, ceili(seconds / tick_seconds - EPSILON))
		plan.merge({"ticks": ticks, "total": ticks, "from": _places(involved)})
		squad.swaps.append(plan)
		busy.append_array(involved)
		for moving in plan["to"]:
			_claim(claimed, plan["to"][moving], moving)
		started = true
	return started


## A front-preferring unit's move to the nearest free place in the front rank; {} if none.
static func _into_free_front(
	squad: SkirmishSquad, unit: SkirmishUnit, claimed: Dictionary
) -> Dictionary:
	if unit.preferred_position != 0:
		return {}
	var best := {}
	for column in range(squad.width - unit.footprint_width + 1):
		var place := Vector2i(0, column)
		if not _free(squad, place, unit, [unit], claimed):
			continue
		var distance := maxi(unit.rank, absi(column - unit.column))
		if best.is_empty() or distance < best["distance"]:
			best = {"mover": unit, "passed": [], "to": {unit: place}, "distance": distance}
	return best


## Moving forward a rank past weaker units ahead; {} if it can't (Decision 49).
static func _through(
	squad: SkirmishSquad, unit: SkirmishUnit, busy: Array, claimed: Dictionary
) -> Dictionary:
	var ahead := _ahead(squad, unit)
	if ahead.is_empty() or ahead.any(func(a): return busy.has(a) or not stronger(unit, a)):
		return {}
	var to := {unit: Vector2i(unit.rank - 1, unit.column)}
	var back_row := unit.rank + unit.footprint_depth - 1
	var moving := ahead + [unit]
	var taken := claimed.duplicate()
	_claim(taken, to[unit], unit)
	var distance := 1
	for passed in ahead:
		var place := Vector2i(back_row, passed.column)
		if not _fits_back_row(unit, passed):
			place = _nearest_free_behind(squad, passed, moving, taken)
			if place.x < 0:
				return {}
			distance = maxi(distance, maxi(place.x - passed.rank, absi(place.y - passed.column)))
		to[passed] = place
		_claim(taken, place, passed)
	return {"mover": unit, "passed": ahead, "to": to, "distance": distance}


## The nearest place behind `unit` where its whole footprint is free; (-1, -1) if none.
static func _nearest_free_behind(
	squad: SkirmishSquad, unit: SkirmishUnit, moving: Array, claimed: Dictionary
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_key := Vector3i(1 << 30, 0, 0)
	for rank in range(unit.rank + 1, unit.rank + SEARCH_RANKS):
		for column in range(squad.width - unit.footprint_width + 1):
			var place := Vector2i(rank, column)
			var lateral := absi(column - unit.column)
			var key := Vector3i(maxi(rank - unit.rank, lateral), lateral, rank)
			if key < best_key and _free(squad, place, unit, moving, claimed):
				best = place
				best_key = key
	return best


## The living units in the row directly ahead of `unit`, across its columns.
static func _ahead(squad: SkirmishSquad, unit: SkirmishUnit) -> Array:
	var row := unit.rank - 1
	return squad.living().filter(
		func(other):
			return (
				other != unit
				and other.rank <= row
				and row < other.rank + other.footprint_depth
				and other.column < unit.column + unit.footprint_width
				and unit.column < other.column + other.footprint_width
			)
	)


## A passed unit fits the row the mover leaves: one rank deep, directly ahead, within its
## columns.
static func _fits_back_row(unit: SkirmishUnit, passed: SkirmishUnit) -> bool:
	return (
		passed.footprint_depth == 1
		and passed.rank == unit.rank - 1
		and passed.column >= unit.column
		and passed.column + passed.footprint_width <= unit.column + unit.footprint_width
	)


## True if `unit`'s footprint at `place` is free of everyone but the units `moving`, and of
## every cell a planned move claims.
static func _free(
	squad: SkirmishSquad, place: Vector2i, unit: SkirmishUnit, moving: Array, claimed: Dictionary
) -> bool:
	for rank in range(place.x, place.x + unit.footprint_depth):
		for column in range(place.y, place.y + unit.footprint_width):
			if claimed.has(Vector2i(rank, column)):
				return false
	for other in squad.living():
		if moving.has(other):
			continue
		var rows := (
			other.rank < place.x + unit.footprint_depth
			and place.x < other.rank + other.footprint_depth
		)
		var columns := (
			other.column < place.y + unit.footprint_width
			and place.y < other.column + other.footprint_width
		)
		if rows and columns:
			return false
	return true


static func _claim(claimed: Dictionary, place: Vector2i, unit: SkirmishUnit) -> void:
	for rank in range(place.x, place.x + unit.footprint_depth):
		for column in range(place.y, place.y + unit.footprint_width):
			claimed[Vector2i(rank, column)] = true


static func _places(units: Array) -> Dictionary:
	var out := {}
	for unit in units:
		out[unit] = Vector2i(unit.rank, unit.column)
	return out

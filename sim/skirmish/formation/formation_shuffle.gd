class_name FormationShuffle
extends RefCounted
## Re-forming (Decisions 46 and 49, specs/22-formation-feel-test.md): after a reinforcement
## or a death, units move toward the places their band prefers.
## - **Into free space first.** A front-preferring unit behind the front takes the nearest
##   free place in the front rank, moving sideways or diagonally if need be. In a fight, a
##   unit that joined as a reinforcement may take one beyond the squad's columns, widening
##   the line up to the combat width (Decision 51).
## - **Otherwise through.** A unit with a stronger claim (its band further forward, or the
##   same band and a higher priority) moves forward a rank past the units directly ahead in
##   its columns. Passed units that fit take its back row; any too wide or too deep move
##   back, through the formation, to the nearest free space that fits them.
## - **How long:** as far as the furthest unit travels, at the slowest involved unit's
##   speed, slowed by crowding while the squad fights (and later by terrain).
## - **No ground ceded mid-move:** until a move completes everyone keeps their place, and
##   keeps fighting. A death of anyone involved cancels it.
## A squad re-forms until no further move can start. Pure over the squad it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const SquadPlaces = preload("res://sim/skirmish/formation/squad_places.gd")

## How terrain changes the speed units pass one another at; 1 until lanes carry terrain.
const TERRAIN_FACTOR := 1.0
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
		_widen_to_fit(squad)
		var ids: Array = swap["passed"].map(func(u): return u.id)
		events.append(
			FormationEvents.unit_event("swapped", tick, squad, swap["mover"], {"passed": ids})
		)
		for moved in squad.compact():  # close the gaps the move left
			events.append(
				FormationEvents.unit_event("stepped_up", tick, squad, moved, {"rank": moved.rank})
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
	var occupied := SquadPlaces.occupancy(squad)  # no one moves while moves are planned
	var busy := []
	for swap in squad.swaps:
		busy.append_array(swap["to"].keys())
		for unit in swap["to"]:
			SquadPlaces.claim(claimed, swap["to"][unit], unit)
	var front_first := squad.living()
	front_first.sort_custom(
		func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.column < b.column)
	)
	var started := false
	for unit in front_first:
		if unit.rank == 0 or busy.has(unit):
			continue
		var plan := _into_free_front(squad, unit, claimed, occupied)
		if plan.is_empty():
			plan = _through(squad, unit, busy, claimed, occupied)
		if plan.is_empty():
			continue
		var involved: Array = plan["to"].keys()
		var slowest: float = involved.reduce(func(least, u): return minf(least, u.speed), INF)
		if slowest <= 0.0:
			continue
		var crowding := (
			BattleTuning.current().scrum_crowding
			if squad.state == SkirmishSquad.State.FIGHTING
			else 1.0
		)
		var pace := travel_scale * slowest * TERRAIN_FACTOR * crowding
		var seconds: float = plan["distance"] * SkirmishSquad.RANK_DEPTH / pace
		var ticks := maxi(1, ceili(seconds / tick_seconds - EPSILON))
		plan.merge({"ticks": ticks, "total": ticks, "from": SquadPlaces.places(involved)})
		squad.swaps.append(plan)
		busy.append_array(involved)
		for moving in plan["to"]:
			SquadPlaces.claim(claimed, plan["to"][moving], moving)
		started = true
	return started


## A front-preferring unit's move to the nearest free place in the front rank; {} if none.
static func _into_free_front(
	squad: SkirmishSquad, unit: SkirmishUnit, claimed: Dictionary, occupied: Dictionary
) -> Dictionary:
	if unit.preferred_position != 0:
		return {}
	var best := {}
	var spreading := (
		squad.state == SkirmishSquad.State.FIGHTING
		and squad.joined.has(unit)
		and squad.combat_width > 0
	)
	var reach := squad.combat_width if spreading else unit.footprint_width
	for column in range(-reach, squad.width + reach - unit.footprint_width + 1):
		var place := Vector2i(0, column)
		var inside := column >= 0 and column + unit.footprint_width <= squad.width
		if not inside and not _within_combat_width(squad, column, unit, claimed):
			continue
		if not SquadPlaces.vacant(occupied, place, unit, [unit], claimed):
			continue
		var distance := maxi(unit.rank, absi(column - unit.column))
		if best.is_empty() or distance < best["distance"]:
			best = {"mover": unit, "passed": [], "to": {unit: place}, "distance": distance}
	return best


## True if `unit` at `column` keeps the line, planned moves included, within the combat
## width, and no more than half a column past either edge of the lane (Decision 51).
static func _within_combat_width(
	squad: SkirmishSquad, column: int, unit: SkirmishUnit, claimed: Dictionary
) -> bool:
	if squad.combat_width <= 0:
		return false
	var left := mini(0, column)
	var right := maxi(squad.width, column + unit.footprint_width)
	for cell in claimed:
		left = mini(left, cell.y)
		right = maxi(right, cell.y + 1)
	var edge := squad.combat_width / 2.0 + 0.5
	var lateral := column - squad.width / 2.0 + squad.centre_shift
	return (
		right - left <= squad.combat_width
		and lateral >= -edge - EPSILON
		and lateral + unit.footprint_width <= edge + EPSILON
	)


## Takes in any columns units now stand in outside 0..width (a spread, Decision 51):
## renumbers every column, swaps under way included, and shifts the centre to match.
static func _widen_to_fit(squad: SkirmishSquad) -> void:
	var left := 0
	var right := squad.width
	for unit in squad.living():
		left = mini(left, unit.column)
		right = maxi(right, unit.column + unit.footprint_width)
	if left == 0 and right == squad.width:
		return
	squad.centre_shift += left + (right - left - squad.width) / 2.0
	for unit in squad.units:
		unit.column -= left
	for swap in squad.swaps:
		for key in ["from", "to"]:
			for unit in swap[key]:
				swap[key][unit] -= Vector2i(0, left)
	squad.width = right - left


## Moving forward a rank past weaker units ahead; {} if it can't (Decision 49).
static func _through(
	squad: SkirmishSquad, unit: SkirmishUnit, busy: Array, claimed: Dictionary, occupied: Dictionary
) -> Dictionary:
	var ahead := SquadPlaces.ahead(occupied, unit)
	if ahead.is_empty() or ahead.any(func(a): return busy.has(a) or not stronger(unit, a)):
		return {}
	var to := {unit: Vector2i(unit.rank - 1, unit.column)}
	var back_row := unit.rank + unit.footprint_depth - 1
	var moving := ahead + [unit]
	var taken := claimed.duplicate()
	SquadPlaces.claim(taken, to[unit], unit)
	var distance := 1
	for passed in ahead:
		var place := Vector2i(back_row, passed.column)
		if not _fits_back_row(unit, passed):
			place = _nearest_free_behind(squad, passed, moving, [taken, occupied])
			if place.x < 0:
				return {}
			distance = maxi(distance, maxi(place.x - passed.rank, absi(place.y - passed.column)))
		to[passed] = place
		SquadPlaces.claim(taken, place, passed)
	return {"mover": unit, "passed": ahead, "to": to, "distance": distance}


## The nearest place behind `unit` where its whole footprint is free; (-1, -1) if none.
## `held`: [the cells claimed, SquadPlaces.occupancy].
static func _nearest_free_behind(
	squad: SkirmishSquad, unit: SkirmishUnit, moving: Array, held: Array
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_key := Vector3i(1 << 30, 0, 0)
	for rank in range(unit.rank + 1, unit.rank + SEARCH_RANKS):
		for column in range(squad.width - unit.footprint_width + 1):
			var place := Vector2i(rank, column)
			var lateral := absi(column - unit.column)
			var key := Vector3i(maxi(rank - unit.rank, lateral), lateral, rank)
			if key < best_key and SquadPlaces.vacant(held[1], place, unit, moving, held[0]):
				best = place
				best_key = key
	return best


## A passed unit fits the row the mover leaves: one rank deep, directly ahead, within its
## columns.
static func _fits_back_row(unit: SkirmishUnit, passed: SkirmishUnit) -> bool:
	return (
		passed.footprint_depth == 1
		and passed.rank == unit.rank - 1
		and passed.column >= unit.column
		and passed.column + passed.footprint_width <= unit.column + unit.footprint_width
	)

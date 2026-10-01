class_name FormationShuffle
extends RefCounted
## Re-forming after a reinforcement (Decision 46, specs/22-formation-feel-test.md).
## - **Who moves:** a unit with a stronger claim to a forward place (its band further
##   forward, or the same band and a higher priority) steps forward one rank past the
##   units directly ahead in its columns. Each must be one rank deep and lie within its
##   columns; the passed units take its back row.
## - **How long:** a swap takes one rank at the slowest involved unit's speed (times a
##   terrain factor, 1 for now).
## - **No ground ceded:** until a swap completes everyone keeps their place - and keeps
##   fighting - so no cell is ever given up. A death on either side cancels it.
## A squad re-forms until no further swap can start. Pure over the squad it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")

## How terrain changes the speed units pass one another at; 1 until lanes carry terrain.
const TERRAIN_FACTOR := 1.0
const EPSILON := 0.000001


## True if `unit` has the stronger claim to a forward place than `other`.
static func stronger(unit: SkirmishUnit, other: SkirmishUnit) -> bool:
	if unit.preferred_position != other.preferred_position:
		return unit.preferred_position < other.preferred_position
	return unit.position_priority > other.position_priority


## One tick: active swaps cancel, count down or complete; then a re-forming squad starts
## every swap it can, and stops re-forming once nothing is moving. Returns "swapped" events.
static func step(
	squad: SkirmishSquad, tick_seconds: float, travel_scale: float, tick: int
) -> Array:
	var events := []
	for index in range(squad.swaps.size() - 1, -1, -1):
		var swap: Array = squad.swaps[index]
		var mover: SkirmishUnit = swap[0]
		if not mover.is_alive() or swap[1].any(func(u): return not u.is_alive()):
			squad.swaps.remove_at(index)
			continue
		swap[2] -= 1
		if swap[2] > 0:
			continue
		var back_row := mover.rank + mover.footprint_depth - 1
		mover.rank -= 1
		for passed in swap[1]:
			passed.rank = back_row
		squad.swaps.remove_at(index)
		var ids: Array = swap[1].map(func(u): return u.id)
		events.append(FormationEvents.unit_event("swapped", tick, squad, mover, {"passed": ids}))
	if squad.reforming and not _start_swaps(squad, tick_seconds, travel_scale):
		squad.reforming = not squad.swaps.is_empty()
	return events


## How far a unit is through a swap, in ranks forward (negative: being passed, moving back).
static func offset(squad: SkirmishSquad, unit: SkirmishUnit) -> float:
	for swap in squad.swaps:
		var progress := 1.0 - float(swap[2]) / float(swap[3])
		if swap[0] == unit:
			return progress
		if swap[1].has(unit):
			return -progress * swap[0].footprint_depth
	return 0.0


static func _start_swaps(squad: SkirmishSquad, tick_seconds: float, travel_scale: float) -> bool:
	var busy := []
	for swap in squad.swaps:
		busy.append(swap[0])
		busy.append_array(swap[1])
	var front_first := squad.living()
	front_first.sort_custom(func(a, b): return a.rank < b.rank)
	var started := false
	for unit in front_first:
		if unit.rank == 0 or busy.has(unit):
			continue
		var ahead := _ahead(squad, unit)
		if ahead.is_empty() or ahead.any(func(a): return busy.has(a) or not _passable(unit, a)):
			continue
		var slowest: float = ahead.reduce(func(least, a): return minf(least, a.speed), unit.speed)
		if slowest <= 0.0:
			continue
		var seconds := SkirmishSquad.RANK_DEPTH / (travel_scale * slowest * TERRAIN_FACTOR)
		var ticks := maxi(1, ceili(seconds / tick_seconds - EPSILON))
		squad.swaps.append([unit, ahead, ticks, ticks])
		busy.append(unit)
		busy.append_array(ahead)
		started = true
	return started


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


## `unit` may pass `other`: a stronger claim, and `other` is one rank deep, directly
## ahead and within `unit`'s columns.
static func _passable(unit: SkirmishUnit, other: SkirmishUnit) -> bool:
	return (
		stronger(unit, other)
		and other.footprint_depth == 1
		and other.rank == unit.rank - 1
		and other.column >= unit.column
		and other.column + other.footprint_width <= unit.column + unit.footprint_width
	)

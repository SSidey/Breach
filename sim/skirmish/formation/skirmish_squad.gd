class_name SkirmishSquad
extends RefCounted
## A wave in the field (specs/22-formation-feel-test.md, Decision 40): its units keep
## their formation places (rank, column) behind the squad's front distance, it moves as a
## block at its slowest unit's speed, and takes orders as a whole. Only the foremost unit
## of each column fights; when one falls the ranks behind step up (compact()).

enum State { MOVING, HOLDING, FIGHTING, ARRIVED, DESTROYED }

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

## Cells between one rank and the next.
const RANK_DEPTH := 0.3

var id: int
var faction_id: String
## +1 advances toward the kingdom's end, -1 toward the player's.
var direction: int
var home_distance: float
var front_distance: float
var width: int
var order: SkirmishUnit.Order = SkirmishUnit.Order.ADVANCE
var state: State = State.MOVING
## The squad this one is fighting; 0 = none.
var engaged_with: int = 0
var wait_ticks: int = 0
var units: Array[SkirmishUnit] = []


func _init(
	squad_id: int,
	faction: String,
	travel_direction: int,
	home: float,
	formation_width: int,
	members: Array[SkirmishUnit] = []
) -> void:
	id = squad_id
	faction_id = faction
	direction = travel_direction
	home_distance = home
	front_distance = home
	width = maxi(formation_width, 1)
	for unit in members:
		unit.squad_id = id
		units.append(unit)


func living() -> Array[SkirmishUnit]:
	return units.filter(func(u): return u.is_alive())


func is_destroyed() -> bool:
	return living().is_empty()


func speed() -> float:
	var slowest := INF
	for unit in living():
		slowest = minf(slowest, unit.speed)
	return 0.0 if slowest == INF else slowest


## Where a unit stands on the route: its rank's depth behind the squad's front.
func unit_distance(unit: SkirmishUnit) -> float:
	return front_distance - direction * unit.rank * RANK_DEPTH


## The unit's columns as a lateral span, centred on the lane. The squad facing the other
## way is mirrored, so both sides share one lateral axis.
func lateral_span(unit: SkirmishUnit) -> Vector2:
	var half := width / 2.0
	if direction > 0:
		return Vector2(unit.column - half, unit.column + unit.footprint_width - half)
	return Vector2(half - unit.column - unit.footprint_width, half - unit.column)


## The foremost living unit of each column (a wide unit counts once), left to right.
func fighters() -> Array[SkirmishUnit]:
	var out: Array[SkirmishUnit] = []
	for column in range(width):
		var best: SkirmishUnit = null
		for unit in living():
			var covers := unit.column <= column and column < unit.column + unit.footprint_width
			if covers and (best == null or unit.rank < best.rank):
				best = unit
		if best != null and not out.has(best):
			out.append(best)
	return out


## Step-up: living units move forward a rank while their whole footprint would be clear,
## until nothing more can move. Returns the units that moved.
func compact() -> Array[SkirmishUnit]:
	var moved: Array[SkirmishUnit] = []
	var any := true
	while any:
		any = false
		var order_by_place := living()
		order_by_place.sort_custom(
			func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.column < b.column)
		)
		for unit in order_by_place:
			if unit.rank > 0 and _clear_ahead(unit):
				unit.rank -= 1
				any = true
				if not moved.has(unit):
					moved.append(unit)
	return moved


func _clear_ahead(unit: SkirmishUnit) -> bool:
	var row := unit.rank - 1
	for other in living():
		if other == unit:
			continue
		var rows_overlap := other.rank <= row and row < other.rank + other.footprint_depth
		var columns_overlap := (
			other.column < unit.column + unit.footprint_width
			and unit.column < other.column + other.footprint_width
		)
		if rows_overlap and columns_overlap:
			return false
	return true

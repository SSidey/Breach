class_name SkirmishSquad
extends RefCounted
## A wave in the field (specs/22-formation-feel-test.md, Decision 40): its units keep
## their formation places (rank, column) behind the squad's front distance, it moves as a
## block at its slowest unit's speed, and takes orders as a whole. Only the foremost unit
## of each column fights; when one falls the ranks behind step up (compact()).

enum State { MOVING, HOLDING, FIGHTING, ARRIVED, DESTROYED, TURNING, ROUTING }

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")

## Tiles between one rank and the next: one cell (Decisions 48 and 68).
const RANK_DEPTH := 1.0 / MapLayoutDef.CELLS_PER_TILE

var id: int
var faction_id: String
## Which way the squad's front points along its route: +1 up it, -1 down it. An
## about-face flips it.
var direction: int
var home_distance: float
## Tiles along the route; setting it moves `position` with it.
var front_distance: float:
	set(value):
		front_distance = value
		_place()
## The route the squad follows (Decision 75); null is a straight lane along x.
var route: FormationRoute = null:
	set(value):
		route = value
		_place()
## Which way the squad faces (SquadFrame), and the centre of its front edge in cells.
var facing: int = SquadFrame.EAST
var position := Vector2.ZERO
var width: int
var order: SkirmishUnit.Order = SkirmishUnit.Order.ADVANCE
var state: State = State.MOVING
## The squad this one is fighting with its front; 0 = none.
var engaged_with: int = 0
## Hostile squads fighting it on its other edges (Decision 78): SquadEdges edge ->
## {"foe": squad id, "since": tick the contact began}.
var flank_contacts := {}
## The scrum (FormationScrum, Decision 88): its units' places while it fights (unit id ->
## {"at", "next", "goal"}), the line it re-faced to {"anchor", "facing"}, the tick its fight
## began (-1: none) and ticks with nobody able to strike.
var loose := {}
var stance := {}
var fight_since := -1
## Pursuit (ScrumPursuit, Decision 95): whether it is ordered to pursue a retreating enemy,
## and its units out chasing one (unit id -> {"unit", "foe", "until"}).
var pursues := false
var chasers := {}
## A pursuit under way (FormationPursuit): the enemy, the post it left, and how it held it.
var pursuit := {}
var stall_ticks := 0
## What it is doing (FormationManoeuvre.Kind, Decisions 94 and 99): 0 combat, 1
## withdrawing, 2 its route, 3 re-forming, 4 the player's order; it marches only on 4.
var manoeuvre := 4
## A withdrawal under way (FormationWithdraw): ticks it has felt safe; empty when none.
var withdraw := {}
## A hold-until order (FormationStaging, Decision 87); empty when it has none.
var staging := {}
## Its will to fight, 0 to 100 (FormationMorale, Decision 82); -1 until first read.
var morale := -1
## Routing (FormationRout): each fleeing unit's place, and ticks with no enemy near.
var fleeing := {}
var rally_ticks := 0
## Halted by ground it can't cross (FormationMarch.pace); reported once.
var blocked := false
## Narrowed through a gap (FormationNarrowing): its painted places (unit id -> [rank,
## column]), width and shift, and ticks left re-forming.
var painted := {}
var painted_width := 0
var painted_shift := 0.0
var narrow_ticks := 0
var wait_ticks: int = 0
## Re-forming after a reinforcement, and the swaps under way (Decision 46, FormationShuffle):
## [[mover, passed units, ticks left, ticks in all], ...].
var reforming := false
var swaps := []
var units: Array[SkirmishUnit] = []
## The lane's combat width: how wide joined units may spread the line in a fight (Decision
## 51); 0 keeps them within the squad's own columns.
var combat_width := 0
## Units that joined as reinforcements: only they spread beyond the painted columns.
var joined: Array[SkirmishUnit] = []
## Whether this wave merges into a friendly squad it catches up with on the march.
var merges := false
## How far the squad's columns sit off the lane's centre, so widening on one side moves no
## one on screen.
var centre_shift := 0.0


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
	facing = SquadFrame.EAST if direction > 0 else SquadFrame.WEST
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


## The unit's columns as a lateral span on the world axis across the squad's facing: turned
## from its (rank, column), never mirrored (Decision 74). On a straight lane both sides
## share the lane's lateral axis, centred on it (less any centre_shift).
func lateral_span(unit: SkirmishUnit) -> Vector2:
	var rect := SquadFrame.unit_rect(position, facing, width, centre_shift, unit)
	return SquadFrame.lateral_interval(rect, facing)


## The front rank, left to right: only it fights in melee (Decision 47). A column whose
## front cell is empty has no fighter, so the enemy facing it wraps onto the flank.
func fighters() -> Array[SkirmishUnit]:
	var out: Array[SkirmishUnit] = living().filter(func(u): return u.rank == 0)
	out.sort_custom(func(a, b): return a.column < b.column)
	return out


## Step-up: living units move forward a rank while their whole footprint would be clear,
## until nothing more can move - but only front-preferring units step into the front rank
## (Decision 47). If the whole front has fallen, the squad re-anchors: its foremost rank
## becomes rank 0 and front_distance moves back to match, so nobody moves on the route.
## Returns the units that stepped up.
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
			var into_front_ok := unit.rank > 1 or unit.preferred_position == 0
			if unit.rank > 0 and into_front_ok and _clear_ahead(unit):
				unit.rank -= 1
				any = true
				if not moved.has(unit):
					moved.append(unit)
	var remaining := living()
	if not remaining.is_empty() and not remaining.any(func(u): return u.rank == 0):
		var shift: int = remaining.reduce(func(least, u): return mini(least, u.rank), 1 << 30)
		for unit in remaining:
			unit.rank -= shift
		front_distance -= direction * shift * RANK_DEPTH
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


func _place() -> void:
	var cells := front_distance * MapLayoutDef.CELLS_PER_TILE
	position = route.point_at(cells) if route != null else Vector2(cells, 0.0)

class_name ScrumPaths
extends RefCounted
## Finding a place in the scrum (Decision 88): which cells units stand on, and the nearest
## open cell next to a foe, by a breadth-first walk on king's moves round friends (never
## through an enemy) within the leash of a unit's place. Pure; cells.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

## Cells a unit may go from its place (Decision 75's leash; placeholder).
const LEASH := 16
const STEPS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]


## cell -> faction for every cell a standing unit covers.
static func occupancy(squads: Array) -> Dictionary:
	var cells := {}
	for squad in squads:
		if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		for unit in squad.living():
			for spot in cells_of(ScrumReach.area(squad, unit)):
				cells[spot] = squad.faction_id
	return cells


static func cells_of(area: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from := ScrumReach.cell(area.position + Vector2(0.01, 0.01))
	var to := ScrumReach.cell(area.end - Vector2(0.01, 0.01))
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			out.append(Vector2i(x, y))
	return out


## Cells (king's moves) to the nearest foe cell, less the one it would stand next to.
static func nearest(from: Vector2i, foe_cells: Dictionary) -> float:
	var best := INF
	for spot in foe_cells:
		best = minf(best, maxi(absi(spot.x - from.x), absi(spot.y - from.y)) - 1)
	return maxf(best, 0.0)


## [goal cell, first step] of the nearest open cell next to a foe within the leash, by a
## breadth-first walk round friends (never through an enemy); [] if there is none.
## `cells` is occupancy(); `foe_cells` the cells the walker's foes stand on.
static func path(
	start: Vector2i,
	home: Vector2i,
	walker: SkirmishUnit,
	foe_cells: Dictionary,
	claimed: Dictionary,
	cells: Dictionary,
	terrain: FormationTerrain
) -> Array:
	var bound := maxi(LEASH, _distance(start, home))
	var first := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var here := queue[head]
		head += 1
		if here != start and _open_beside(here, home, foe_cells, cells, claimed):
			return [here, first[here]]
		for offset in STEPS:
			var next: Vector2i = here + offset
			if first.has(next) or _distance(next, home) > bound:
				continue
			if cells.get(next, walker.faction_id) != walker.faction_id:
				continue  # an enemy stands there
			if not _passable(terrain, walker, here, next):
				continue
			first[next] = next if here == start else first[here]
			queue.append(next)
	return []


static func _open_beside(
	spot: Vector2i, home: Vector2i, foe_cells: Dictionary, cells: Dictionary, claimed: Dictionary
) -> bool:
	if cells.has(spot) or claimed.has(spot) or _distance(spot, home) > LEASH:
		return false
	for offset in STEPS:
		if foe_cells.has(spot + offset):
			return true
	return false


static func _passable(
	terrain: FormationTerrain, walker: SkirmishUnit, here: Vector2i, next: Vector2i
) -> bool:
	if terrain == null:
		return true
	return terrain.factor(walker.height, ScrumReach.centre(here), ScrumReach.centre(next)) > 0.0


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

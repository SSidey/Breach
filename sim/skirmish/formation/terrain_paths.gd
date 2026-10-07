class_name TerrainPaths
extends RefCounted
## Paths over the terrain grid for a unit (spec 30 round 3; Decisions 75, 85 and 97): the
## quickest way at the walker's own pace on each cell - the pace the march uses
## (FormationTerrain.crossing): ground, slope, liquid bands by its height, swimming where
## it swims, cliffs where it climbs. A ford beats swimming, or a wood a detour, by cost
## alone. The leash (`paths_leash`, BattleTuning) bounds how far either side of the
## straight way the search looks for a way round; a way it finds may be far longer.
## Deterministic: ties go to geometry (PathFrontier), so the same ground gives the same
## path and the ground mirrored gives it mirrored. Not yet wired into movement. Pure.
##
##   TerrainPaths.cells(terrain, walker, from, to)  -> the cells of the way, or []
##   TerrainPaths.find(terrain, walker, from, to)   -> waypoints, straightened, or []
##   TerrainPaths.cost(terrain, walker, waypoints)  -> the seconds it takes at speed 1

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const PathSearch = preload("res://sim/skirmish/formation/path_search.gd")

## How finely (cells) a straight leg is sampled for its cost.
const SAMPLE := 0.2
## A straight leg replaces a stretch of the way only if it is no slower than that by more
## than this (seconds): float noise never decides.
const SLACK := 0.000001


## The cells of the quickest way for `walker` from the cell holding `from` to the cell
## holding `to`, both included; empty where there is none within `leash` cells of the
## straight way (negative: the tuned leash; INF: no bound) or either end is off the grid.
static func cells(
	terrain: FormationTerrain, walker: TerrainWalker, from: Vector2, to: Vector2, leash := -1.0
) -> Array[Vector2i]:
	var bound := BattleTuning.current().paths_leash if leash < 0.0 else leash
	var start := Vector2i(floori(from.x), floori(from.y))
	var goal := Vector2i(floori(to.x), floori(to.y))
	return PathSearch.new(terrain, walker, start, goal, bound).run()


## The way as waypoints from `from` to `to`, through the centres of the cells where it
## turns: a stretch is cut straight wherever the straight leg crosses nothing it can't and
## is no slower. Empty where `cells` finds no way.
static func find(
	terrain: FormationTerrain, walker: TerrainWalker, from: Vector2, to: Vector2, leash := -1.0
) -> PackedVector2Array:
	var way := cells(terrain, walker, from, to, leash)
	if way.is_empty():
		return PackedVector2Array()
	var points := PackedVector2Array()
	for cell in way:
		points.append(Vector2(cell) + Vector2(0.5, 0.5))
	points[0] = from
	points[points.size() - 1] = to
	return _straightened(terrain, walker, points)


## The time (seconds, at a speed of a cell a second) `walker` takes along `waypoints`,
## sampled every SAMPLE cells; INF if a leg crosses where it can't go.
static func cost(
	terrain: FormationTerrain, walker: TerrainWalker, waypoints: PackedVector2Array
) -> float:
	var total := 0.0
	for index in range(1, waypoints.size()):
		total += _leg(terrain, walker, waypoints[index - 1], waypoints[index])
	return total


## Each waypoint kept reaches as far along the way as a straight leg can: galloping out
## (2, 4, 8... points on), then halving back between the last leg that held and the
## first that didn't.
static func _straightened(
	terrain: FormationTerrain, walker: TerrainWalker, points: PackedVector2Array
) -> PackedVector2Array:
	var along := PackedFloat64Array([0.0])  # the time to each point along the way
	for index in range(1, points.size()):
		along.append(along[index - 1] + _leg(terrain, walker, points[index - 1], points[index]))
	var out := PackedVector2Array([points[0]])
	var at := 0
	var last := points.size() - 1
	while at < last:
		var held := at + 1
		var reach := 2
		while at + reach <= last and _holds(terrain, walker, points, along, at, at + reach):
			held = at + reach
			reach *= 2
		var failed := mini(at + reach, last + 1)
		while failed - held > 1:
			var middle := (held + failed) >> 1
			if _holds(terrain, walker, points, along, at, middle):
				held = middle
			else:
				failed = middle
		out.append(points[held])
		at = held
	return out


## Whether the straight leg from point `from` to point `to` is no slower than the way.
static func _holds(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	points: PackedVector2Array,
	along: PackedFloat64Array,
	from: int,
	to: int
) -> bool:
	var leg := _leg(terrain, walker, points[from], points[to])
	return leg <= along[to] - along[from] + SLACK


## The time along the straight leg from `start` to `end`: each sample's stretch at the
## pace into the cell it lies in from the last sample's. Samples fall mid-stretch, off
## the grid's lines; one crossing a corner needs both cells beside it enterable.
static func _leg(
	terrain: FormationTerrain, walker: TerrainWalker, start: Vector2, end: Vector2
) -> float:
	var length := start.distance_to(end)
	var count := maxi(1, ceili(length / SAMPLE))
	var total := 0.0
	var last := start
	for step in range(1, count + 1):
		var point := start.lerp(end, (step - 0.5) / count) if step < count else end
		var pace := terrain.crossing(walker, last, point)
		if pace <= 0.0 or not _corner_clear(terrain, walker, last, point):
			return INF
		total += (length / count) / pace
		last = point
	return total


## Whether a move from `last` to `point` passing diagonally between cells could enter both
## cells beside the corner it passes.
static func _corner_clear(
	terrain: FormationTerrain, walker: TerrainWalker, last: Vector2, point: Vector2
) -> bool:
	var was := Vector2i(floori(last.x), floori(last.y))
	var now := Vector2i(floori(point.x), floori(point.y))
	if was.x == now.x or was.y == now.y:
		return true
	var beside := [Vector2(now.x, was.y), Vector2(was.x, now.y)]
	for cell in beside:
		if terrain.crossing(walker, last, cell + Vector2(0.5, 0.5)) <= 0.0:
			return false
	return true

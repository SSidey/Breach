class_name TerrainPaths
extends RefCounted
## Paths over the terrain grid for a unit (spec 30; Decisions 75, 85 and 97): the quickest
## way at the walker's own pace on each cell - the pace the march uses (WalkerShares, from
## FormationTerrain.crossing): ground, slope, liquid bands by its height, swimming and
## climbing by its abilities. A ford beats swimming, or a wood a detour, by cost alone.
## There is no leash: a pathfinder plans on what it sees (PathSight) - seen cells at their
## real cost, unseen ones as open ground - and where the best plan runs out of sight it
## heads for that edge and plans again from there (PathSearch), remembering what it has
## seen (PathMemory, optional) so a wall felt along stays known. Deterministic: ties go to
## geometry (PathFrontier), so the same ground gives the same path and the ground mirrored
## gives it mirrored. Not yet wired into movement. Pure.
##
##   TerrainPaths.plan(terrain, walker, from, goal, sight)    -> {waypoints, reaches, cells}
##   TerrainPaths.rejoin(terrain, walker, from, route, sight) -> {..., along}
##   TerrainPaths.cells(terrain, walker, from, goal, sight)   -> the cells of the way, or []
##   TerrainPaths.cost(terrain, walker, waypoints)            -> seconds at speed 1

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const PathSearch = preload("res://sim/skirmish/formation/path_search.gd")
const PathSight = preload("res://sim/skirmish/formation/path_sight.gd")
const PathMemory = preload("res://sim/skirmish/formation/path_memory.gd")

## How finely (cells) a straight leg is sampled for its cost.
const SAMPLE := 0.2
## A straight leg replaces a stretch of the way only if it is no slower than that by more
## than this (seconds): float noise never decides.
const SLACK := 0.000001


## The cells of the quickest way for `walker` from the cell holding `from` to the cell
## holding `goal`, both included, planned on what `sight` sees (null: everything) and
## `memory` has seen - to the
## edge of sight where the best plan runs out of it; empty where there is no way.
static func cells(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	from: Vector2,
	goal: Vector2,
	sight: PathSight = null,
	memory: PathMemory = null
) -> Array[Vector2i]:
	return PathSearch.new(terrain, walker, _cell(from), sight, memory).to_cell(_cell(goal))


## The way planned from `from` towards `goal` on what `sight` sees: {"waypoints": from,
## the centres of the cells where it turns, and `goal` - or the cell on the edge of sight
## it heads for; "reaches": whether it reaches the goal; "cells": the way's cells}. The
## waypoints are empty where there is no way.
static func plan(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	from: Vector2,
	goal: Vector2,
	sight: PathSight = null,
	memory: PathMemory = null
) -> Dictionary:
	var search := PathSearch.new(terrain, walker, _cell(from), sight, memory)
	var way := search.to_cell(_cell(goal))
	var end := goal if search.reaches else Vector2.INF
	return _planned(terrain, walker, way, from, end, search.reaches)


## The way back onto `route` from `from` on what `sight` sees: to the cell on the route
## where the walk there plus the march along the route to its end is quickest - of those
## within path_rejoin_slack of it, the one back soonest (RouteRejoin) - its distance along
## the route "along"; or where that way leaves sight, to the edge of sight ("reaches"
## false, "along" -1). As plan() otherwise.
static func rejoin(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	from: Vector2,
	route: FormationRoute,
	sight: PathSight = null,
	memory: PathMemory = null
) -> Dictionary:
	var search := PathSearch.new(terrain, walker, _cell(from), sight, memory)
	var out := _planned(terrain, walker, search.to_route(route), from, Vector2.INF, search.reaches)
	var waypoints: PackedVector2Array = out["waypoints"]
	out["along"] = route.distance_of(waypoints[-1]) if search.reaches else -1.0
	return out


## The time (seconds, at a speed of a cell a second) `walker` takes along `waypoints`,
## sampled every SAMPLE cells; INF if a leg crosses where it can't go.
static func cost(
	terrain: FormationTerrain, walker: TerrainWalker, waypoints: PackedVector2Array
) -> float:
	var total := 0.0
	for index in range(1, waypoints.size()):
		total += _leg(terrain, walker, waypoints[index - 1], waypoints[index])
	return total


## The plan along `way`: from `from` to `end` (INF: the last cell's centre), straightened.
static func _planned(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	way: Array[Vector2i],
	from: Vector2,
	end: Vector2,
	reaches: bool
) -> Dictionary:
	var points := PackedVector2Array()
	for cell in way:
		points.append(Vector2(cell) + Vector2(0.5, 0.5))
	if not points.is_empty():
		points[0] = from
		if end != Vector2.INF and points.size() > 1:
			points[points.size() - 1] = end
		points = _straightened(terrain, walker, points)
	return {"waypoints": points, "reaches": reaches and not way.is_empty(), "cells": way}


static func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.y))


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

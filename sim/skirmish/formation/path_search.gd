class_name PathSearch
extends RefCounted
## One A* search over the terrain grid for a walker (TerrainPaths, spec 30 round 3): eight
## ways from each cell, a diagonal only where both cells beside it can be entered (no
## corner cut past what it can't cross); a step costs its length over the walker's pace
## into the cell it enters (FormationTerrain.crossing), so it finds the quickest way, not
## the shortest. The search keeps to the grid and to cells within `leash` cells of the
## straight way from start to goal. Its ties go to geometry (PathFrontier). Pure.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const PathFrontier = preload("res://sim/skirmish/formation/path_frontier.gd")

## Neighbours: the four sides, then the four diagonals.
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DIAGONALS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)
]
## A diagonal step's length.
const DIAGONAL_STEP := 1.4142135623730951
## A way must be quicker by more than this to replace one already found: float noise
## never decides.
const BETTER := 0.000001

## Cells taken off the frontier and expanded, for measuring.
var expanded := 0

var _terrain: FormationTerrain
var _walker: TerrainWalker
var _start: Vector2i
var _goal: Vector2i
var _leash: float
var _width: int
var _best := PackedFloat64Array()
var _parent := PackedInt32Array()
var _closed := PackedByteArray()
var _asides := PackedFloat32Array()  # each cell's distance aside, worked out when first asked
var _open := PathFrontier.new()


func _init(
	terrain: FormationTerrain, walker: TerrainWalker, start: Vector2i, goal: Vector2i, leash: float
) -> void:
	_terrain = terrain
	_walker = walker
	_start = start
	_goal = goal
	_leash = leash
	_width = terrain.size.x


## The cells of the quickest way from start to goal, both included; empty if there is none
## within the leash.
func run() -> Array[Vector2i]:
	var grid := Rect2i(Vector2i.ZERO, _terrain.size)
	if not grid.has_point(_start) or not grid.has_point(_goal):
		return []
	var count := _terrain.size.x * _terrain.size.y
	_best.resize(count)
	_best.fill(INF)
	_parent.resize(count)
	_parent.fill(-1)
	_closed.resize(count)
	_asides.resize(count)
	_asides.fill(-1.0)
	var start := _index(_start)
	_best[start] = 0.0
	_open.push(start, _estimate(_start), _aside(_start), _estimate(_start))
	var goal := _index(_goal)
	while not _open.is_empty():
		var index := _open.pop()
		if _closed[index] == 1:
			continue
		_closed[index] = 1
		expanded += 1
		if index == goal:
			return _trace(goal)
		_expand(index)
	return []


## Offers each neighbour of the cell at `index` the way through it.
func _expand(index: int) -> void:
	var cell := _cell(index)
	var here := _centre(cell)
	var sides := PackedFloat32Array()
	for side in SIDES:
		var pace := _pace(here, cell + side)
		sides.append(pace)
		if pace > 0.0:
			_relax(index, cell + side, 1.0 / pace)
	for diagonal in DIAGONALS:
		var across := 0 if diagonal.x > 0 else 2
		var along := 1 if diagonal.y > 0 else 3
		if sides[across] <= 0.0 or sides[along] <= 0.0:
			continue  # it would cut the corner of a cell it can't enter
		var pace := _pace(here, cell + diagonal)
		if pace > 0.0:
			_relax(index, cell + diagonal, DIAGONAL_STEP / pace)


## The walker's pace from `here` into `cell`: 0 off the grid, beyond the leash or where it
## can't go.
func _pace(here: Vector2, cell: Vector2i) -> float:
	if cell.x < 0 or cell.y < 0 or cell.x >= _terrain.size.x or cell.y >= _terrain.size.y:
		return 0.0
	if cell != _goal and _aside(cell) > _leash:
		return 0.0
	return _terrain.crossing(_walker, here, _centre(cell))


func _relax(from: int, cell: Vector2i, step: float) -> void:
	var index := _index(cell)
	if _closed[index] == 1:
		return
	var through := _best[from] + step
	if through >= _best[index] - BETTER:
		return
	_best[index] = through
	_parent[index] = from
	var remaining := _estimate(cell)
	_open.push(index, through + remaining, _aside(cell), remaining)


## The least time from `cell` to the goal at full pace on open ground: the octile
## distance (a step's pace is never above 1).
func _estimate(cell: Vector2i) -> float:
	var apart := (cell - _goal).abs()
	return maxi(apart.x, apart.y) + (DIAGONAL_STEP - 1.0) * mini(apart.x, apart.y)


## How far the cell's centre lies from the straight way between start and goal.
func _aside(cell: Vector2i) -> float:
	var index := _index(cell)
	if _asides[index] < 0.0:
		var centre := _centre(cell)
		var nearest := Geometry2D.get_closest_point_to_segment(
			centre, _centre(_start), _centre(_goal)
		)
		_asides[index] = centre.distance_to(nearest)
	return _asides[index]


func _trace(goal: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var index := goal
	while index >= 0:
		out.append(_cell(index))
		index = _parent[index]
	out.reverse()
	return out


func _cell(index: int) -> Vector2i:
	return Vector2i(index % _width, index / _width)


func _index(cell: Vector2i) -> int:
	return cell.y * _width + cell.x


static func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)

class_name PathSearch
extends RefCounted
## One A* search over the terrain grid for a walker (TerrainPaths, spec 30): eight ways
## from each cell, a diagonal only where both cells beside it can be entered (no corner
## cut past what it can't cross); a step costs its length over the walker's pace into the
## cell it enters (WalkerShares), so it finds the quickest way, not the shortest. It keeps
## to the grid. Its ties go to geometry (PathFrontier).
##
## Planning on what is seen: given a sight (PathSight), the cells it sees or has seen
## (PathMemory, which it adds to) cost what they cost; cells it can't see count as open
## ground (share 1). It finds the quickest way to the goal on that understanding and keeps
## the stretch in sight: the whole way if the goal is in sight and reached (`reaches`),
## else up to the edge of sight where the way leaves it - the frontier cell with the least
## cost so far plus optimistic cost on. The walker heads there and plans again as more
## comes into view, so a wall is felt along. With no sight it sees the whole grid. The goal
## is a cell, or a route: rejoining it where the way to the route's end, walked to it and
## marched along it, is quickest (RouteRejoin, which settles ties within its slack). Pure.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const PathFrontier = preload("res://sim/skirmish/formation/path_frontier.gd")
const PathSight = preload("res://sim/skirmish/formation/path_sight.gd")
const PathMemory = preload("res://sim/skirmish/formation/path_memory.gd")
const WalkerShares = preload("res://sim/skirmish/formation/walker_shares.gd")
const RouteRejoin = preload("res://sim/skirmish/formation/route_rejoin.gd")

## A diagonal step's length.
const DIAGONAL_STEP := 1.4142135623730951
## A way must be quicker by more than this to replace one already found: float noise
## never decides.
const BETTER := 0.000001
## A cell is on a route when its centre lies within this many cells of the route's line.
const ON_ROUTE := 0.5
## What the search knows of a cell's visibility.
const UNKNOWN := 0
const SEEN := 1
const UNSEEN := 2

## Cells taken off the frontier and expanded, for measuring.
var expanded := 0
## Whether the way found reaches the goal (false: it ends on the edge of sight).
var reaches := false

var _terrain: FormationTerrain
var _walker: TerrainWalker
var _shares: WalkerShares
var _sight: PathSight
var _memory: PathMemory
var _count: int
var _start: Vector2i
var _goal := Vector2i(-1, -1)
var _route: FormationRoute
var _rejoin: RouteRejoin
var _toward: Vector2  # where the straight way runs, for ties
var _width: int
var _best := PackedFloat64Array()
var _parent := PackedInt32Array()
var _closed := PackedByteArray()
var _visible := PackedByteArray()
var _remaining := PackedFloat32Array()  # each cell's estimate, worked out when first asked
var _asides := PackedFloat32Array()  # each cell's distance aside, likewise
var _open := PathFrontier.new()


## The cells of the quickest way from start to `goal`, or to the edge of sight where the
## best plan runs out of it; empty if there is none.
func to_cell(goal: Vector2i) -> Array[Vector2i]:
	_goal = goal
	_toward = _centre(goal)
	if not Rect2i(Vector2i.ZERO, _terrain.size).has_point(goal):
		return []
	return _run()


## The cells of the way from start onto `route` (to a cell within ON_ROUTE of its line)
## that RouteRejoin chooses, or to the edge of sight where that way leaves it; empty if
## there is none.
func to_route(route: FormationRoute) -> Array[Vector2i]:
	_route = route
	_rejoin = RouteRejoin.new(_terrain, _walker, route)
	_toward = _rejoin.end
	return _run()


func _run() -> Array[Vector2i]:
	if not Rect2i(Vector2i.ZERO, _terrain.size).has_point(_start):
		return []
	var count := _terrain.size.x * _terrain.size.y
	_best.resize(count)
	_best.fill(INF)
	_parent.resize(count)
	_parent.fill(-1)
	_closed.resize(count)
	_visible.resize(count)
	_remaining.resize(count)
	_remaining.fill(-1.0)
	_asides.resize(count)
	_asides.fill(-1.0)
	var start := _index(_start)
	_best[start] = 0.0
	_open.push(start, _estimate(start), _aside(start), _estimate(start))
	while not _open.is_empty():
		var index := _open.pop()
		if _closed[index] == 1:
			continue
		if _rejoin != null and _rejoin.settled(_best[index] + _estimate(index)):
			break
		_closed[index] = 1
		expanded += 1
		if _is_goal(index):
			if _rejoin == null:
				return _in_sight(_trace(index))
			_rejoin.offer(index, _centre(_cell(index)), _best[index])
		_expand(index)
	var chosen := -1 if _rejoin == null else _rejoin.chosen()
	return [] if chosen < 0 else _in_sight(_trace(chosen))


## Offers each neighbour of the cell at `index` the way through it.
func _expand(index: int) -> void:
	var cell := _cell(index)
	var sides := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for step in WalkerShares.STEPS.size():
		var next: Vector2i = cell + WalkerShares.STEPS[step]
		var diagonal := step >= 4
		if diagonal:
			var across := 0 if WalkerShares.STEPS[step].x > 0 else 2
			var along := 1 if WalkerShares.STEPS[step].y > 0 else 3
			if sides[across] <= 0.0 or sides[along] <= 0.0:
				continue  # it would cut the corner of a cell it can't enter
		var pace := _shares.into(index, step)  # 0 off the grid
		var inside := Rect2i(Vector2i.ZERO, _terrain.size).has_point(next)
		var seen := not inside or _sees(_index(next))
		if inside and not seen:
			pace = 1.0  # what it can't see counts as open ground
		if not diagonal:
			sides[step] = pace
		if pace > 0.0:
			_relax(index, next, (DIAGONAL_STEP if diagonal else 1.0) / pace)


func _relax(from: int, cell: Vector2i, step: float) -> void:
	var index := _index(cell)
	if _closed[index] == 1:
		return
	var through := _best[from] + step
	if through >= _best[index] - BETTER:
		return
	_best[index] = through
	_parent[index] = from
	var remaining := _estimate(index)
	_open.push(index, through + remaining, _aside(index), remaining)


func _is_goal(index: int) -> bool:
	if _route == null:
		return index == _index(_goal)
	var centre := _centre(_cell(index))
	return centre.distance_to(_on_route(centre)) <= ON_ROUTE


func _sees(index: int) -> bool:
	if _sight == null:
		return true
	if _visible[index] == UNKNOWN:
		var known := _memory != null and _memory.knows(index, _count)
		var seen := known or _sight.sees(_centre(_cell(index)))
		if seen and _memory != null:
			_memory.learn(index, _count)
		_visible[index] = SEEN if seen else UNSEEN
	return _visible[index] == SEEN


## The least time from the cell at `index` to the goal at full pace on open ground: the
## octile distance to a goal cell; for a route, the straight distance to its end less
## ON_ROUTE (RouteRejoin; a step's pace is never above 1).
func _estimate(index: int) -> float:
	if _remaining[index] < 0.0:
		var cell := _cell(index)
		if _route == null:
			var apart := (cell - _goal).abs()
			_remaining[index] = (
				maxi(apart.x, apart.y) + (DIAGONAL_STEP - 1.0) * mini(apart.x, apart.y)
			)
		else:
			_remaining[index] = _rejoin.estimate(_centre(cell), ON_ROUTE)
	return _remaining[index]


## How far the cell's centre lies from the straight way from start towards the goal.
func _aside(index: int) -> float:
	if _asides[index] < 0.0:
		var centre := _centre(_cell(index))
		var nearest := Geometry2D.get_closest_point_to_segment(centre, _centre(_start), _toward)
		_asides[index] = centre.distance_to(nearest)
	return _asides[index]


func _on_route(point: Vector2) -> Vector2:
	return _route.point_at(_route.distance_of(point))


## The way as far as it stays in sight: the whole way if it does (`reaches`), else up to
## the last cell it sees before the way leaves its sight - the edge of sight it heads for.
func _in_sight(way: Array[Vector2i]) -> Array[Vector2i]:
	for at in way.size():
		if not _sees(_index(way[at])):
			reaches = false
			return way.slice(0, maxi(at, 1))
	reaches = true
	return way


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


func _init(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	start: Vector2i,
	sight: PathSight = null,
	memory: PathMemory = null
) -> void:
	_terrain = terrain
	_walker = walker
	_shares = WalkerShares.of(terrain, walker)
	_start = start
	_sight = sight
	_memory = memory
	_count = terrain.size.x * terrain.size.y
	_width = terrain.size.x

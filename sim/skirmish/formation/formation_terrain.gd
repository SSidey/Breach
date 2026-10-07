class_name FormationTerrain
extends RefCounted
## The ground a formation fight is on (Decision 85, spec 27 round 4): a grid of cells, each
## with a move cost, a height (in quarters of a cell), a liquid depth (in cells), how fast
## its liquid flows, the climb difficulty of its faces and whether it blocks sight. Outside
## the grid is open, level ground. A unit's pace into a cell (`crossing`, for a
## TerrainWalker) is the product of:
## - **ground:** the cell's move cost (a wood 0.5)
## - **slope:** each quarter-cell risen costs a share of the pace; downhill is no faster; a
##   rise past the cliff height is a cliff, climbed
## - **liquid,** in bands of the unit's own height: under a quarter free, to a half wading,
##   to its height slow wading, deeper swum
## Climbing and swimming are movement modes (TerrainWalker): the mode's base pace times
## Decision 64's pair rule, the walker's climber or swimmer level against the cell's climb
## difficulty or flow (spec 30).
## The shares and heights are BattleTuning's (`ground_*`). Pure; the field paints it, the
## simulation and TerrainPaths read it.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")

var size: Vector2i

var _cost := PackedFloat32Array()
var _height := PackedInt32Array()
var _depth := PackedFloat32Array()
var _blocks := PackedByteArray()
var _climb := PackedInt32Array()
var _flows := PackedInt32Array()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	var count := size.x * size.y
	_cost.resize(count)
	_cost.fill(1.0)
	_height.resize(count)
	_depth.resize(count)
	_blocks.resize(count)
	_climb.resize(count)
	_climb.fill(BattleTuning.current().ground_climb_demand)
	_flows.resize(count)


## Sets the cells of `area`: any of "cost", "height" (quarters), "depth" (cells), "flows"
## (its liquid's flow), "climb" (the climb difficulty of a cliff rising into them) and
## "blocks_sight".
func paint(area: Rect2i, props: Dictionary) -> void:
	var clipped := area.intersection(Rect2i(Vector2i.ZERO, size))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var index := y * size.x + x
			_cost[index] = props.get("cost", _cost[index])
			_height[index] = props.get("height", _height[index])
			_depth[index] = props.get("depth", _depth[index])
			_climb[index] = props.get("climb", _climb[index])
			_flows[index] = props.get("flows", _flows[index])
			if props.has("blocks_sight"):
				_blocks[index] = 1 if props["blocks_sight"] else 0


## The height (quarters) of the cell holding a point.
func height_at(at: Vector2) -> int:
	var index := _index(at)
	return 0 if index < 0 else _height[index]


func blocks_sight(at: Vector2) -> bool:
	var index := _index(at)
	return index >= 0 and _blocks[index] == 1


## How fast a unit `unit_height` cells tall that neither swims nor climbs goes stepping
## from `from` into `to`, as a share of its speed on open level ground; 0 where it can't go.
func factor(unit_height: float, from: Vector2, to: Vector2) -> float:
	return crossing(TerrainWalker.grounded(unit_height), from, to)


## How fast `walker` goes stepping from `from` into `to`, as a share of its speed on open
## level ground; 0 where it can't go.
func crossing(walker: TerrainWalker, from: Vector2, to: Vector2) -> float:
	var index := _index(to)
	if index < 0:
		return 1.0
	var tuning := BattleTuning.current()
	var share: float = _cost[index] * _rise_share(walker, _height[index] - height_at(from), index)
	var depth: float = _depth[index] / maxf(walker.height, 0.01)
	if depth >= 1.0:
		return (
			share
			* _mode_share(walker.swims, tuning.ground_swim_pace, walker.swimmer, _flows[index])
		)
	if depth >= 0.5:
		return share * tuning.ground_slow_wading
	if depth >= 0.25:
		return share * tuning.ground_wading
	return share


## The movement mode of `walker` stepping from `from` into `to`: climbing a cliff, else
## swimming water at least its height deep, else walking (spec 30).
func mode(walker: TerrainWalker, from: Vector2, to: Vector2) -> TerrainWalker.Mode:
	var index := _index(to)
	if index < 0:
		return TerrainWalker.Mode.WALKING
	if _height[index] - height_at(from) > BattleTuning.current().ground_cliff_quarters:
		return TerrainWalker.Mode.CLIMBING
	if _depth[index] >= walker.height:
		return TerrainWalker.Mode.SWIMMING
	return TerrainWalker.Mode.WALKING


## True if `from` stands at least a quarter-cell higher than `to`: a striker there has
## the high ground (Decision 85).
func high_ground(from: Vector2, to: Vector2) -> bool:
	return height_at(from) > height_at(to)


## The share of its pace a rise of `rise` quarters into cell `index` leaves `walker`: a
## slope's toll, or a cliff's climb by the pair rule.
func _rise_share(walker: TerrainWalker, rise: int, index: int) -> float:
	var tuning := BattleTuning.current()
	if rise > tuning.ground_cliff_quarters:
		return _mode_share(walker.climbs, tuning.ground_climb_pace, walker.climber, _climb[index])
	return maxf(0.1, 1.0 - tuning.ground_slope_cost * maxi(rise, 0))


## A movement mode's share of the pace: its base pace times the pair rule, `ability`
## against `demand`; 0 for a walker that may not use it.
static func _mode_share(allowed: bool, pace: float, ability: int, demand: int) -> float:
	return pace * TerrainWalker.meets(ability, demand) if allowed else 0.0


func _index(at: Vector2) -> int:
	var cell := Vector2i(floori(at.x), floori(at.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	return cell.y * size.x + cell.x

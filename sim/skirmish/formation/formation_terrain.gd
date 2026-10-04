class_name FormationTerrain
extends RefCounted
## The ground a formation fight is on (Decision 85, spec 27 round 4): a grid of cells, each
## with a move cost, a height (in quarters of a cell), a liquid depth (in cells) and
## whether it blocks sight. Outside the grid is open, level ground. A unit's pace into a
## cell is the product of:
## - **ground:** the cell's move cost (a wood 0.5)
## - **slope:** each quarter-cell risen costs 10%; downhill is no faster; a rise of more
##   than a cell is a cliff, impassable until climbers come
## - **liquid,** in bands of the unit's own height: under a quarter free, to a half 0.6
##   (wading), to its height 0.3 (slow wading), deeper impassable until swimmers come
## All numbers placeholders. Pure; the field paints it, the simulation reads it.

const CLIFF_QUARTERS := 4
const SLOPE_COST := 0.1
const WADING := 0.6
const SLOW_WADING := 0.3

var size: Vector2i

var _cost := PackedFloat32Array()
var _height := PackedInt32Array()
var _depth := PackedFloat32Array()
var _blocks := PackedByteArray()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	var count := size.x * size.y
	_cost.resize(count)
	_cost.fill(1.0)
	_height.resize(count)
	_depth.resize(count)
	_blocks.resize(count)


## Sets the cells of `area`: any of "cost", "height" (quarters), "depth" (cells) and
## "blocks_sight".
func paint(area: Rect2i, props: Dictionary) -> void:
	var clipped := area.intersection(Rect2i(Vector2i.ZERO, size))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var index := y * size.x + x
			_cost[index] = props.get("cost", _cost[index])
			_height[index] = props.get("height", _height[index])
			_depth[index] = props.get("depth", _depth[index])
			if props.has("blocks_sight"):
				_blocks[index] = 1 if props["blocks_sight"] else 0


## The height (quarters) of the cell holding a point.
func height_at(at: Vector2) -> int:
	var index := _index(at)
	return 0 if index < 0 else _height[index]


func blocks_sight(at: Vector2) -> bool:
	var index := _index(at)
	return index >= 0 and _blocks[index] == 1


## How fast a unit `unit_height` cells tall goes stepping from `from` into `to`, as a share
## of its speed on open level ground; 0 where it can't go.
func factor(unit_height: float, from: Vector2, to: Vector2) -> float:
	var index := _index(to)
	if index < 0:
		return 1.0
	var rise := _height[index] - height_at(from)
	if rise > CLIFF_QUARTERS:
		return 0.0
	var share: float = _cost[index] * maxf(0.1, 1.0 - SLOPE_COST * maxi(rise, 0))
	var depth: float = _depth[index] / maxf(unit_height, 0.01)
	if depth >= 1.0:
		return 0.0
	if depth >= 0.5:
		return share * SLOW_WADING
	if depth >= 0.25:
		return share * WADING
	return share


## True if `from` stands at least a quarter-cell higher than `to`: a striker there has
## the high ground (Decision 85).
func high_ground(from: Vector2, to: Vector2) -> bool:
	return height_at(from) > height_at(to)


func _index(at: Vector2) -> int:
	var cell := Vector2i(floori(at.x), floori(at.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	return cell.y * size.x + cell.x

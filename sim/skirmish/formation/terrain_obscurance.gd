class_name TerrainObscurance
extends RefCounted
## How much each cell of the ground hides what lies beyond it (spec 30): one rule for
## sight. Each cell has an obscurance - what a cell of distance through it costs a sight
## line - and `fog`, the field's weather, adds its own to every cell, on the grid or off
## it. A sight line sums the obscurance cell by cell, each cell's by the distance the line
## runs through it, and sight ends where the sum passes the looker's sight budget
## (BattleTuning.sight_budget). A wood (sight_wood_obscurance) is seen a few cells into,
## then nothing; fog (sight_fog_obscurance, painted or as weather) shortens sight rather
## than blocking it. The sum is the same either way along a line and mirrored with the
## ground: a line running along a cell edge takes the mean of the cells either side, and
## a corner it only touches costs nothing.
##
## PathSight plans by it. FormationSight's detection (a line crossing more than
## MAX_SCREEN cells that block sight is blocked) will move to it too: `clear(from, to,
## budget)` in place of FormationSight.clear, the field's wood painted with obscurance
## alone, and "blocks_sight" retired, so detection and planning see alike. Pure.

## A sum within this of the budget still sees: float noise never decides.
const SLACK := 0.000001

## The weather's obscurance, added to every cell's.
var fog := 0.0

var _size: Vector2i
var _cells := PackedFloat32Array()
var _bounds := Rect2()  # the cells with an obscurance of their own all lie within
var _any := false  # whether any does


## The obscurance of the cell holding `at` (the mean of the cells either side where it
## lies on a cell edge), with the fog.
func at(point: Vector2) -> float:
	var cell := Vector2i(floori(point.x), floori(point.y))
	if cell.x != point.x and cell.y != point.y:
		return _own(cell) + fog
	var xs := _sides(point.x)
	var ys := _sides(point.y)
	var total := 0.0
	for x in xs:
		for y in ys:
			total += _own(Vector2i(x, y))
	return total / (xs.size() * ys.size()) + fog


## The obscurance summed along the sight line from `from` to `to`: each cell's times the
## distance the line runs through it, cell by cell. It stops counting once past `limit`.
func along(from: Vector2, to: Vector2, limit: float = INF) -> float:
	var length := from.distance_to(to)
	if length <= 0.0:
		return 0.0
	if not _any or not Rect2(from, Vector2.ZERO).expand(to).intersects(_bounds, true):
		return fog * length
	var x_edge := _first_edge(from.x, to.x)
	var y_edge := _first_edge(from.y, to.y)
	var total := 0.0
	var done := 0.0  # how far along the line (0 to 1) it has summed
	while done < 1.0:
		var x_cut := _share(from.x, to.x, x_edge)
		var y_cut := _share(from.y, to.y, y_edge)
		var cut := minf(minf(x_cut, y_cut), 1.0)
		if cut > done:
			total += at(from.lerp(to, (cut + done) * 0.5)) * (cut - done) * length
			if total > limit:
				return total
		if cut == x_cut:
			x_edge += 1 if to.x > from.x else -1
		if cut == y_cut:
			y_edge += 1 if to.y > from.y else -1
		done = cut
	return total


## Whether a looker with sight budget `budget` at `from` sees `to`.
func clear(from: Vector2, to: Vector2, budget: float) -> bool:
	return along(from, to, budget + SLACK) <= budget + SLACK


## Sets the obscurance of the cell at `index` on the grid.
func set_cell(index: int, value: float) -> void:
	_cells[index] = value
	if value == 0.0:
		return
	var cell := Rect2(index % _size.x, index / _size.x, 1, 1)
	_bounds = _bounds.merge(cell) if _any else cell
	_any = true


func _own(cell: Vector2i) -> float:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return 0.0
	return _cells[cell.y * _size.x + cell.x]


## The cells (along one axis) a coordinate lies in: both where it is on an edge.
static func _sides(coordinate: float) -> Array[int]:
	var cell := floori(coordinate)
	if cell == coordinate:
		return [cell - 1, cell]
	return [cell]


## The first cell edge (on one axis) a line from `start` to `end` crosses after leaving.
static func _first_edge(start: float, end: float) -> int:
	return floori(start) + 1 if end > start else ceili(start) - 1


## Where (0 to 1 along the line) a line from `start` to `end` on one axis crosses `edge`;
## INF if it never does.
static func _share(start: float, end: float, edge: int) -> float:
	if start == end:
		return INF
	var share := (edge - start) / (end - start)
	return share if share > 0.0 else INF


func _init(grid_size: Vector2i) -> void:
	_size = grid_size
	_cells.resize(grid_size.x * grid_size.y)

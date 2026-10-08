class_name WalkerShares
extends RefCounted
## Each cell's speed share for one kind of walker (spec 30): the pace stepping into a cell
## from each of its eight neighbours (FormationTerrain.crossing), worked out the first time
## it is asked and kept, so a path search looks it up. Walkers of one kind - the same
## height, abilities and modes (TerrainWalker.kind) - share one, held on the terrain and
## dropped when it is painted. Off the grid a share is 0: paths keep to the grid. Pure.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")

## The eight steps from a cell: the four sides, then the four diagonals.
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
]
## A share not yet worked out.
const UNKNOWN := -1.0

var _terrain: FormationTerrain
var _walker: TerrainWalker
var _width: int
var _shares := PackedFloat32Array()


## The shares for `walker`'s kind on `terrain`, shared by every walker of that kind.
static func of(terrain: FormationTerrain, walker: TerrainWalker) -> WalkerShares:
	var kind := walker.kind()
	if not terrain.walker_shares.has(kind):
		terrain.walker_shares[kind] = WalkerShares.new(terrain, walker)
	return terrain.walker_shares[kind]


## The share of its pace stepping from the cell at `index` by STEPS[`step`]: 0 off the
## grid or where it can't go.
func into(index: int, step: int) -> float:
	var at := index * STEPS.size() + step
	var share := _shares[at]
	if share == UNKNOWN:
		var cell := Vector2i(index % _width, index / _width)
		var next := cell + STEPS[step]
		share = 0.0
		if Rect2i(Vector2i.ZERO, _terrain.size).has_point(next):
			var centre := Vector2(0.5, 0.5)
			share = _terrain.crossing(_walker, Vector2(cell) + centre, Vector2(next) + centre)
		_shares[at] = share
	return share


func _init(terrain: FormationTerrain, walker: TerrainWalker) -> void:
	_terrain = terrain
	_walker = walker
	_width = terrain.size.x
	_shares.resize(terrain.size.x * terrain.size.y * STEPS.size())
	_shares.fill(UNKNOWN)

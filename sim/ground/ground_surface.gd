class_name GroundSurface
extends RefCounted
## The ground's surface, per Decision 56 and specs/23-ground-model.md (round 2). Each tile
## has an elevation in cells at its centre; a cell column's surface is interpolated
## between tile centres (level beyond the outermost ones), so ground slopes smoothly
## across tile edges.
## - The **surface cell** is the highest cell holding any ground. Its shape is its four
##   corner heights in quarters of a cell (NW, NE, SE, SW): 4 is full, 0 is empty.
## - Units walk on the surface; a step of more than one cell between neighbouring columns
##   is a **cliff**, which needs climbing (Decision 54).
## - Digging the surface cell removes only what is left of it (dig_fraction).
## - Ground at or above the map's ceiling is **capped**: impassable and unsimulated.
## - On the tile shape go each terrain's seeded **relief** (GroundRelief) and the map's
##   carved **channels** (GroundChannels), which may hold a liquid (Decision 59).
## Cells are global: column x runs across the map, TILE_CELLS per tile. Pure.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const GroundRelief = preload("res://sim/ground/ground_relief.gd")
const GroundChannels = preload("res://sim/ground/ground_channels.gd")

## Cells along a tile's edge (Decision 68).
const TILE_CELLS := MapLayoutDef.CELLS_PER_TILE

var ceiling: int

var _cols: int
var _rows: int
var _seed: int
var _elevations := PackedInt32Array()  # per tile, row-major
var _reliefs := []  # per tile: Vector2i(amplitude, scale)
var _channels: GroundChannels


func _init(layout: MapLayoutDef) -> void:
	_cols = maxi(layout.cols, 1)
	_rows = maxi(layout.rows, 1)
	ceiling = layout.ceiling
	_seed = layout.seed
	_channels = GroundChannels.new(layout)
	_elevations.resize(_cols * _rows)
	for row in range(_rows):
		for col in range(_cols):
			_elevations[row * _cols + col] = layout.elevation_at(Vector2i(col, row))
			var terrain = (
				layout.terrain_library.terrain(layout.terrain_id_at(Vector2i(col, row)))
				if layout.terrain_library
				else null
			)
			_reliefs.append(
				Vector2i(terrain.relief_amplitude, terrain.relief_scale) if terrain else Vector2i()
			)


## The level (cells up from 0) of the column's surface cell.
func surface_level(column: Vector2i) -> int:
	var top := 0
	for quarters in _corner_quarters(column):
		top = maxi(top, quarters)
	return ceili(top / 4.0) - 1


## The surface cell's corner heights in quarters (NW, NE, SE, SW), 0 to 4.
func surface_shape(column: Vector2i) -> PackedInt32Array:
	var floor_quarters := surface_level(column) * 4
	var shape := PackedInt32Array()
	for quarters in _corner_quarters(column):
		shape.append(clampi(quarters - floor_quarters, 0, 4))
	return shape


## The column's mean ground height, in cells.
func surface_height(column: Vector2i) -> float:
	var total := 0
	for quarters in _corner_quarters(column):
		total += quarters
	return total / 16.0


## The part of a cell left to dig in the column's surface cell: 1 when it is full.
func dig_fraction(column: Vector2i) -> float:
	var total := 0
	for quarters in surface_shape(column):
		total += quarters
	return total / 16.0


## True if the step between two neighbouring columns is more than one cell.
func is_cliff(from: Vector2i, to: Vector2i) -> bool:
	return absf(surface_height(to) - surface_height(from)) > 1.0


## {"material", "level"} of the liquid a channel holds over the column, if its level is
## above the ground there; {} otherwise.
func liquid_at(column: Vector2i) -> Dictionary:
	var centre := Vector2(column) + Vector2(0.5, 0.5)
	var held := _channels.liquid(centre, _ground_at(centre))
	if held.is_empty() or held["level"] <= surface_height(column):
		return {}
	return held


## True if the column's ground reaches the ceiling.
func is_capped(column: Vector2i) -> bool:
	return surface_height(column) >= ceiling


## The column's four corner heights, rounded to quarters of a cell.
func _corner_quarters(column: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		out.append(roundi(_height_at(column + corner) * 4.0))
	return out


## Ground height at a cell corner: the tile shape and relief, less any channel cut.
func _height_at(corner: Vector2i) -> float:
	var point := Vector2(corner)
	return _ground_at(point) - _channels.carve(point)


## The uncarved ground at a point: tile elevations and each tile's relief, blended between
## tile centres (level beyond the outermost ones).
func _ground_at(point: Vector2) -> float:
	var u := clampf(point.x / TILE_CELLS - 0.5, 0.0, _cols - 1.0)
	var v := clampf(point.y / TILE_CELLS - 0.5, 0.0, _rows - 1.0)
	var col := mini(floori(u), _cols - 2) if _cols > 1 else 0
	var row := mini(floori(v), _rows - 2) if _rows > 1 else 0
	var weights := {
		Vector2i(col, row): (1.0 - (u - col)) * (1.0 - (v - row)),
		Vector2i(col + 1, row): (u - col) * (1.0 - (v - row)),
		Vector2i(col, row + 1): (1.0 - (u - col)) * (v - row),
		Vector2i(col + 1, row + 1): (u - col) * (v - row),
	}
	var height := 0.0
	for tile in weights:
		var index := _index(tile)
		var relief: Vector2i = _reliefs[index]
		var bump := relief.x * GroundRelief.noise(point, relief.y, _seed)
		height += weights[tile] * (_elevations[index] + bump)
	return height


func _index(tile: Vector2i) -> int:
	return clampi(tile.y, 0, _rows - 1) * _cols + clampi(tile.x, 0, _cols - 1)

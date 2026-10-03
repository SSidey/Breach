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
## Cells are global: column x runs across the map, TILE_CELLS per tile. Pure.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

## Cells along a tile's edge (Decision 53).
const TILE_CELLS := 16

var ceiling: int

var _cols: int
var _rows: int
var _elevations := PackedInt32Array()  # per tile, row-major


func _init(layout: MapLayoutDef) -> void:
	_cols = maxi(layout.cols, 1)
	_rows = maxi(layout.rows, 1)
	ceiling = layout.ceiling
	_elevations.resize(_cols * _rows)
	for row in range(_rows):
		for col in range(_cols):
			_elevations[row * _cols + col] = layout.elevation_at(Vector2i(col, row))


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


## True if the column's ground reaches the ceiling.
func is_capped(column: Vector2i) -> bool:
	return surface_height(column) >= ceiling


## The column's four corner heights, rounded to quarters of a cell.
func _corner_quarters(column: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		out.append(roundi(_height_at(column + corner) * 4.0))
	return out


## Ground height at a cell corner, interpolated between tile centres.
func _height_at(corner: Vector2i) -> float:
	var u := clampf(corner.x / float(TILE_CELLS) - 0.5, 0.0, _cols - 1.0)
	var v := clampf(corner.y / float(TILE_CELLS) - 0.5, 0.0, _rows - 1.0)
	var col := mini(floori(u), _cols - 2) if _cols > 1 else 0
	var row := mini(floori(v), _rows - 2) if _rows > 1 else 0
	var fu := u - col
	var fv := v - row
	var top := lerpf(_tile(col, row), _tile(col + 1, row), fu)
	var bottom := lerpf(_tile(col, row + 1), _tile(col + 1, row + 1), fu)
	return lerpf(top, bottom, fv)


func _tile(col: int, row: int) -> float:
	return _elevations[clampi(row, 0, _rows - 1) * _cols + clampi(col, 0, _cols - 1)]

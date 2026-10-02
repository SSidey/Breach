class_name GroundRelief
extends RefCounted
## Seeded relief noise (Decision 59): smooth value noise in [-1, 1], varying over about
## `scale` cells and reproducible from the map's seed. GroundSurface scales it by each
## terrain's relief amplitude and blends between tiles. Pure.


## The noise at a point (in cells) for one scale; 0 when scale is 0.
static func noise(point: Vector2, scale: int, seed: int) -> float:
	if scale <= 0:
		return 0.0
	var grid := point / float(scale)
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	var fx := smoothstep(0.0, 1.0, grid.x - cell.x)
	var fy := smoothstep(0.0, 1.0, grid.y - cell.y)
	var top := lerpf(_value(cell, scale, seed), _value(cell + Vector2i(1, 0), scale, seed), fx)
	var bottom := lerpf(
		_value(cell + Vector2i(0, 1), scale, seed), _value(cell + Vector2i(1, 1), scale, seed), fx
	)
	return lerpf(top, bottom, fy)


## A lattice point's value in [-1, 1]: an integer hash, the same on every machine.
static func _value(lattice: Vector2i, scale: int, seed: int) -> float:
	var n := lattice.x * 374761393 + lattice.y * 668265263 + seed * 982451653 + scale * 144665
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 32767.5 - 1.0

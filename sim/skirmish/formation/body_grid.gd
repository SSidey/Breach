class_name BodyGrid
extends RefCounted
## Finding what is near a point without looking at everything (spec 30 round 3): points -
## bodies, slots, claims - bucketed by square cells CELL across, built once for a snapshot.
## A query gives the indices of every point in the cells it could reach, in the order the
## points were given, so a search over them keeps the list's order wherever it would have
## (a superset of what qualifies, never a different order: outcomes stay the same, Decision
## 97). Searches outward go ring by ring of cells, each no nearer than the one before.
## Pure; cells.

## Cells a bucket spans: about the widest body, so a touch is a neighbouring bucket away.
const CELL := 2.0


## {"cells": {Vector2i: [index, ...]}, "low", "high": the occupied cells' corners}.
static func build(points: Array) -> Dictionary:
	var cells := {}
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for index in range(points.size()):
		var cell := cell_of(points[index])
		var bucket: Array = cells.get(cell, [])
		if bucket.is_empty():
			cells[cell] = bucket
			low = low.min(cell)
			high = high.max(cell)
		bucket.append(index)
	return {"cells": cells, "low": low, "high": high}


## A grid over bodies ([[point, radius, unit], ...], ScrumSlots), with "widest": the
## largest radius among them, so a search for any body touching a point knows how far to
## look.
static func of_bodies(bodies: Array) -> Dictionary:
	var grid := build(bodies.map(func(body): return body[0]))
	var widest := 0.0
	for body in bodies:
		widest = maxf(widest, body[1])
	grid["widest"] = widest
	return grid


## The cell holding `point`.
static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


## Indices of the points in every cell within `reach` of `point` (and some just beyond),
## in ascending order.
static func near(grid: Dictionary, point: Vector2, reach: float) -> Array:
	var low: Vector2i = grid["low"]
	var high: Vector2i = grid["high"]
	var from := cell_of(point - Vector2(reach, reach)).max(low)
	var to := cell_of(point + Vector2(reach, reach)).min(high)
	var cells: Dictionary = grid["cells"]
	var out := []
	var buckets := 0
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var bucket = cells.get(Vector2i(x, y))
			if bucket != null:
				out.append_array(bucket)
				buckets += 1
	if buckets > 1:
		out.sort()
	return out


## Indices of the points in the cells exactly `ring` cells (Chebyshev) from `centre`; no
## point among them lies nearer a point in `centre` than floor_of(ring).
static func ring(grid: Dictionary, centre: Vector2i, ring_number: int) -> Array:
	var cells: Dictionary = grid["cells"]
	var out := []
	if ring_number == 0:
		out.append_array(cells.get(centre, []))
		return out
	for y in range(centre.y - ring_number, centre.y + ring_number + 1):
		var edge := absi(y - centre.y) == ring_number
		var step := 1 if edge else 2 * ring_number
		for x in range(centre.x - ring_number, centre.x + ring_number + 1, step):
			var bucket = cells.get(Vector2i(x, y))
			if bucket != null:
				out.append_array(bucket)
	return out


## The least distance from a point in the centre cell to any point in ring `ring_number`.
static func floor_of(ring_number: int) -> float:
	return maxf(0.0, (ring_number - 1) * CELL)


## The last ring round `centre` holding any cell that is occupied.
static func last_ring(grid: Dictionary, centre: Vector2i) -> int:
	if grid["cells"].is_empty():
		return -1
	var low: Vector2i = grid["low"]
	var high: Vector2i = grid["high"]
	var far := (low - centre).abs().max((high - centre).abs())
	return maxi(far.x, far.y)

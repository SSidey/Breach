class_name WaveTemplate
extends RefCounted
## A lane's wave, painted unit by unit (Decision 42, specs/22-formation-feel-test.md):
## a grid `max_width` columns by MAX_RANKS ranks, rank 0 the front. The painted units
## *are* the shape, so "front" means exactly what was drawn. Painting never uses more
## cells than `slot_limit` (the lane's share of the slot pool). Pure data.

const UnitDef = preload("res://content/definitions/unit_def.gd")

const MAX_RANKS := 4

var max_width: int
var slot_limit: int

var _placements := []  # [[UnitDef, Vector2i(rank, column)], ...]


func _init(width: int, slots: int) -> void:
	max_width = clampi(width, 1, 8)
	slot_limit = maxi(slots, 0)


func copy() -> WaveTemplate:
	var twin := WaveTemplate.new(max_width, slot_limit)
	twin._placements = _placements.duplicate()
	return twin


## Places a unit anchored at `cell` (its front-most rank, left-most column), replacing any
## units it overlaps. A footprint that would overhang the grid is pulled back inside.
## Refused (false, nothing changed) if `cell` is off the grid or the slots run out.
func paint(unit_def: UnitDef, cell: Vector2i) -> bool:
	var depth := unit_def.footprint_depth
	var width := unit_def.footprint_width
	if cell.x < 0 or cell.y < 0 or cell.x >= MAX_RANKS or cell.y >= max_width:
		return false
	if depth > MAX_RANKS or width > max_width:
		return false
	cell = Vector2i(mini(cell.x, MAX_RANKS - depth), mini(cell.y, max_width - width))
	var kept := _placements.filter(func(p): return not _overlaps(p, cell, depth, width))
	if _cells(kept) + depth * width > slot_limit:
		return false
	kept.append([unit_def, cell])
	_placements = kept
	return true


func occupied(cell: Vector2i) -> bool:
	return _placements.any(func(p): return _overlaps(p, cell, 1, 1))


## Removes the unit covering `cell`; false if there is none.
func erase(cell: Vector2i) -> bool:
	var before := _placements.size()
	_placements = _placements.filter(func(p): return not _overlaps(p, cell, 1, 1))
	return _placements.size() != before


## Placements front-first (rank, then column): the build and fold order.
func ordered() -> Array:
	var sorted := _placements.duplicate()
	sorted.sort_custom(func(a, b): return a[1].x < b[1].x or (a[1].x == b[1].x and a[1].y < b[1].y))
	return sorted


## Shrinks to a new slot limit by removing back-most units; returns the removed ones.
func trim_to(slots: int) -> Array:
	slot_limit = maxi(slots, 0)
	var removed := []
	while _cells(_placements) > slot_limit:
		var back: Array = ordered()[-1]
		_placements.erase(back)
		removed.append(back)
	return removed


## [squad width, placements] with the painted columns shifted to start at 0, for spawning.
func layout() -> Array:
	if _placements.is_empty():
		return [1, []]
	var first := max_width
	var last := 0
	for placement in _placements:
		first = mini(first, placement[1].y)
		last = maxi(last, placement[1].y + placement[0].footprint_width)
	var shifted := ordered().map(func(p): return [p[0], Vector2i(p[1].x, p[1].y - first)])
	return [last - first, shifted]


static func _overlaps(placement: Array, cell: Vector2i, depth: int, width: int) -> bool:
	var at: Vector2i = placement[1]
	var unit_def: UnitDef = placement[0]
	return (
		at.x < cell.x + depth
		and cell.x < at.x + unit_def.footprint_depth
		and at.y < cell.y + width
		and cell.y < at.y + unit_def.footprint_width
	)


static func _cells(placements: Array) -> int:
	var total := 0
	for placement in placements:
		total += placement[0].footprint_depth * placement[0].footprint_width
	return total

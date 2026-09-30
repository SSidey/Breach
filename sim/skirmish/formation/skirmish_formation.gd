class_name SkirmishFormation
extends RefCounted
## One wave's layout on a lane (specs/22-formation-feel-test.md, Decision 40): a grid
## `width` columns wide holding `slots` usable cells, filled front rank first. Rank 0 is
## the front. The last rank may be partial (7 slots at width 3 = ranks of 3, 3 and 1).
## Units occupy footprints of depth (ranks) x width (columns). Pure data.

const NO_ROOM := Vector2i(-1, -1)
## Decision 41: no lane is wider than the largest footprint (an 8x8 dragon).
const MAX_LANE_WIDTH := 8
## Ranks a lane's slot share can fill at most (feel-test cap).
const MAX_RANKS := 4

var width: int
var slots: int
var ranks: int

var _taken := {}  # Vector2i(rank, column) -> true


func _init(formation_width: int, slot_count: int) -> void:
	width = maxi(formation_width, 1)
	slots = maxi(slot_count, 0)
	ranks = ceili(float(slots) / float(width))


## The widest a lane's formation can be: the request, capped by the lane, the global
## maximum and the slots available (at least 1).
static func clamp_width(requested: int, lane_width: int, slot_count: int) -> int:
	return clampi(requested, 1, maxi(1, mini(mini(lane_width, MAX_LANE_WIDTH), slot_count)))


func is_usable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.y < width and cell.x * width + cell.y < slots


func can_fit(depth: int, footprint_width: int) -> bool:
	return _find(depth, footprint_width, false) != NO_ROOM


## Places a footprint and returns its (rank, column), or NO_ROOM. Front rank first, left
## to right; prefer_centre tries the front rank's centre before the left edge.
func place(depth: int, footprint_width: int, prefer_centre: bool = false) -> Vector2i:
	var at := _find(depth, footprint_width, prefer_centre)
	if at != NO_ROOM:
		for r in range(depth):
			for c in range(footprint_width):
				_taken[Vector2i(at.x + r, at.y + c)] = true
	return at


func _find(depth: int, footprint_width: int, prefer_centre: bool) -> Vector2i:
	if prefer_centre:
		var centre := Vector2i(0, (width - footprint_width) / 2)
		if _fits(centre, depth, footprint_width):
			return centre
	for r in range(ranks):
		for c in range(width - footprint_width + 1):
			if _fits(Vector2i(r, c), depth, footprint_width):
				return Vector2i(r, c)
	return NO_ROOM


func _fits(at: Vector2i, depth: int, footprint_width: int) -> bool:
	for r in range(depth):
		for c in range(footprint_width):
			var cell := Vector2i(at.x + r, at.y + c)
			if not is_usable(cell) or _taken.has(cell):
				return false
	return true

class_name FormationRoute
extends RefCounted
## A route as a path of cells across the map (Decision 75, specs/27-formations-in-2d.md):
## waypoints in cells, walked by distance along them. A squad keeps its distance along its
## route and takes its 2D place and facing from it (Decision 74). The corridor is how far
## either side of the centre line squads may spread. Pure; distances are in cells.

const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")

## Cells either side of the centre line squads may use (the lane's combat width, halved).
var corridor_half_width := 0.0

var _points := PackedVector2Array()


## A route running east from the origin: the one-lane feel test's lane.
static func straight(length: float, half_width: float = 0.0) -> FormationRoute:
	return FormationRoute.new(PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)]), half_width)


func _init(points: PackedVector2Array, half_width: float = 0.0) -> void:
	_points = points
	corridor_half_width = half_width


func length_cells() -> float:
	var total := 0.0
	for i in range(1, _points.size()):
		total += _points[i - 1].distance_to(_points[i])
	return total


## The point at a distance along the route, clamped to its ends.
func point_at(distance: float) -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	var remaining := maxf(distance, 0.0)
	for i in range(1, _points.size()):
		var leg := _points[i - 1].distance_to(_points[i])
		if remaining < leg:
			return _points[i - 1].lerp(_points[i], remaining / leg)
		remaining -= leg
	return _points[-1]


## The unit direction of travel at a distance; at a bend, the leg leaving it.
func heading_at(distance: float) -> Vector2:
	if _points.size() < 2:
		return Vector2.RIGHT
	var remaining := maxf(distance, 0.0)
	for i in range(1, _points.size()):
		var leg := _points[i - 1].distance_to(_points[i])
		if remaining < leg:
			return (_points[i] - _points[i - 1]).normalized()
		remaining -= leg
	return (_points[-1] - _points[-2]).normalized()


## The facing (SquadFrame) nearest the heading, for a squad travelling with (+1) or against
## (-1) the route. On an exact diagonal it keeps `current` (Decision 74).
func facing_at(distance: float, travel_sign: int, current: int) -> int:
	var heading := heading_at(distance) * travel_sign
	if is_equal_approx(absf(heading.x), absf(heading.y)):
		return current
	if absf(heading.x) > absf(heading.y):
		return SquadFrame.EAST if heading.x > 0.0 else SquadFrame.WEST
	return SquadFrame.SOUTH if heading.y > 0.0 else SquadFrame.NORTH

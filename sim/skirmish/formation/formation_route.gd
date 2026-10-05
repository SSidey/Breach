class_name FormationRoute
extends RefCounted
## A route as a path of cells across the map (Decision 75, specs/27-formations-in-2d.md):
## waypoints in cells, walked by distance along them. A squad keeps its distance along its
## route and takes its 2D place and heading from it (Decision 74). The corridor is how far
## either side of the centre line squads may spread. Pure; distances are in cells.

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


## The distance along the route of the point on it nearest `point`.
func distance_of(point: Vector2) -> float:
	var best := 0.0
	var best_gap := INF
	var walked := 0.0
	for i in range(1, _points.size()):
		var from := _points[i - 1]
		var leg := from.distance_to(_points[i])
		var along := clampf((point - from).dot((_points[i] - from) / maxf(leg, 0.000001)), 0.0, leg)
		var gap := point.distance_to(from.lerp(_points[i], along / maxf(leg, 0.000001)))
		if gap < best_gap:
			best_gap = gap
			best = walked + along
		walked += leg
	return best

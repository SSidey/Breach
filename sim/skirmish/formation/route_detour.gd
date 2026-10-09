class_name RouteDetour
extends RefCounted
## A group's way off its route and back (spec 30): it is noted where it stands as it
## goes - each tick on the route, and at each waypoint of its plan off it. While it is on
## the route it remembers the last place it stood there; once off, the places it is noted
## at are its detour's waypoints. When it is back on the route it forgets what its
## pathfinder saw (its `memory`), and if it came back ahead of where it left, the detour
## worked: `note` hands back the RoutePatch it makes, for the command to keep, so every
## group of the command follows the patched route (RoutePatch.patched). A group is on its
## route within the route's corridor, or ON_ROUTE of its line where the corridor is
## narrower. Pure.

const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const RoutePatch = preload("res://sim/skirmish/formation/route_patch.gd")
const PathMemory = preload("res://sim/skirmish/formation/path_memory.gd")

## The least distance (cells) from its route's line within which a group is on it.
const ON_ROUTE := 0.5

## What its pathfinder has seen since it left the route.
var memory := PathMemory.new()

var _left := Vector2.INF  # the last place it stood on the route; INF before any
var _via := PackedVector2Array()  # where it has been noted off the route
var _off := false


## Notes the group standing at `at` beside `route`: the patch its detour makes if it has
## just come back onto the route ahead of where it left, else null.
func note(route: FormationRoute, at: Vector2) -> RoutePatch:
	var gap := at.distance_to(route.point_at(route.distance_of(at)))
	if gap > maxf(route.corridor_half_width, ON_ROUTE):
		_off = _off or _left != Vector2.INF
		if _off:
			_via.append(at)
		return null
	var patch: RoutePatch = null
	if _off:
		memory.forget()
		var detour := PackedVector2Array([_left])
		detour.append_array(_via)
		detour.append(at)
		if route.distance_of(at) > route.distance_of(_left):
			patch = RoutePatch.of_detour(route, detour)
	_off = false
	_via = PackedVector2Array()
	_left = at
	return patch

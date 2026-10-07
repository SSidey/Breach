class_name RoutePatch
extends RefCounted
## A learned detour (spec 30): a way round that worked, kept as a patch to a route -
## "between `from_along` and `to_along` cells along it, follow these waypoints". The
## command a group follows keeps its patches beside its route (FormationCommand, on
## feature/movement-commands, will hold an `Array` of them and hand every group
## `RoutePatch.patched(route, patches)` to follow), so every group of the command takes
## the detour. Patches apply in order along the route; one starting inside an earlier
## one's stretch gives way to it. Ties go to where they lie, never to the order they were
## learned in (Decision 97). Pure.

const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")

## Where along the route the detour leaves it and rejoins it (cells).
var from_along: float
var to_along: float
## The detour's waypoints between leaving and rejoining.
var waypoints: PackedVector2Array


## The patch a detour makes: from where its first waypoint lies along `route` to where its
## last does, through the waypoints between.
static func of_detour(route: FormationRoute, detour: PackedVector2Array) -> RoutePatch:
	return RoutePatch.new(
		route.distance_of(detour[0]), route.distance_of(detour[-1]), detour.slice(1, -1)
	)


## `route` with each patch's stretch replaced by its detour.
static func patched(route: FormationRoute, patches: Array) -> FormationRoute:
	var ordered := patches.filter(func(patch): return patch.to_along > patch.from_along)
	ordered.sort_custom(_before)
	var corners := route.points()
	var out := PackedVector2Array()
	var cut := -INF  # where the last patch rejoined
	var corner := 0
	var walked := 0.0
	for patch in ordered:
		if patch.from_along < cut:
			continue  # inside an earlier patch's stretch
		while corner < corners.size() and walked < patch.from_along:
			if walked > cut:
				out.append(corners[corner])
			corner += 1
			walked = _along(corners, corner)
		out.append(route.point_at(patch.from_along))
		out.append_array(patch.waypoints)
		out.append(route.point_at(patch.to_along))
		cut = patch.to_along
	for rest in range(corner, corners.size()):
		if _along(corners, rest) > cut:
			out.append(corners[rest])
	return FormationRoute.new(out, route.corridor_half_width)


## Whether `one` comes before `other` along the route: by where it leaves, then where it
## rejoins, then its waypoints' places.
static func _before(one: RoutePatch, other: RoutePatch) -> bool:
	if one.from_along != other.from_along:
		return one.from_along < other.from_along
	if one.to_along != other.to_along:
		return one.to_along < other.to_along
	for index in mini(one.waypoints.size(), other.waypoints.size()):
		if one.waypoints[index] != other.waypoints[index]:
			var a: Vector2 = one.waypoints[index]
			var b: Vector2 = other.waypoints[index]
			return a.x < b.x or (a.x == b.x and a.y < b.y)
	return one.waypoints.size() < other.waypoints.size()


## How far along the polyline `corners` its corner `index` lies (INF past its end).
static func _along(corners: PackedVector2Array, index: int) -> float:
	if index >= corners.size():
		return INF
	var total := 0.0
	for at in range(1, index + 1):
		total += corners[at - 1].distance_to(corners[at])
	return total


func _init(leaves: float, rejoins: float, detour: PackedVector2Array) -> void:
	from_along = leaves
	to_along = rejoins
	waypoints = detour

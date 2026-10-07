class_name FormationRendezvous
extends RefCounted
## Planned rendezvous (Decision 87, spec 27 round 2): the overlord's timing, given before
## departure, so waves on different routes reach their points together. The march is
## predicted as FormationSimulation runs it - a cell pace per tick, slowed by the ground
## along the route (Decision 85), sweeping round bends (Decision 105) as fast as its
## files, walking to their places, keep within their slack (FormationWalk, spec 30 round
## 3), and at a gap narrower than the squad the pauses to narrow and widen - so it holds
## until something interferes on the way (a fight, a queue). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationNarrowing = preload("res://sim/skirmish/formation/formation_narrowing.gd")


## Ticks for a squad `width` wide moving `cells_per_second` to reach `cells` along `route`,
## setting out from `from` cells along it, over `terrain` if given, its units walking to
## their places within `slack` cells (FormationWalk; negative: the slack at discipline
## 50).
static func ticks_to(
	route: FormationRoute,
	cells: float,
	width: int,
	cells_per_second: float,
	tick_seconds: float,
	from: float = 0.0,
	terrain: FormationTerrain = null,
	slack: float = -1.0
) -> int:
	var march := {
		"step": cells_per_second * tick_seconds,
		"travelled": from,
		"facing": UnitMotion.bearing_to(Vector2.ZERO, route.heading_at(from), 0.0),
		"sweep": rad_to_deg(cells_per_second / maxf(width / 2.0, 0.5)) * tick_seconds,
		"slack": slack if slack >= 0.0 else _middling_slack(),
		"ticks": 0,
		"narrowed": false,
	}
	march["files"] = _places(route, width, from, march["facing"])
	while march["travelled"] < cells - 0.000001 and march["ticks"] < 1000000:
		_tick(route, width, march, terrain, tick_seconds)
	return march["ticks"]


## One tick of the predicted march: the frame steps and sweeps by the share its lagging
## files allow (FormationWalk.share), and the front rank's files walk to their places.
static func _tick(
	route: FormationRoute, width: int, march: Dictionary, terrain, tick_seconds: float
) -> void:
	var here := route.point_at(march["travelled"])
	var ahead := route.heading_at(march["travelled"])
	var ground := 1.0
	if terrain != null:
		ground = maxf(0.05, terrain.factor(1.0, here, here + ahead))
		var heading := UnitMotion.bearing_to(Vector2.ZERO, ahead, 0.0)
		if not march["narrowed"] and _narrows(terrain, here + ahead, heading, width):
			march["narrowed"] = true
			march["ticks"] += 2 * roundi(BattleTuning.current().reach_narrow_seconds / tick_seconds)
	var places := _places(route, width, march["travelled"], march["facing"])
	var furthest := 0.0
	for i in places.size():
		furthest = maxf(furthest, march["files"][i].distance_to(places[i]))
	var slack: float = march["slack"]
	var keeping := clampf((slack - furthest) / (slack / 2.0), 0.0, 1.0)
	var wanted := UnitMotion.bearing_to(Vector2.ZERO, ahead, march["facing"])
	var left := fposmod(wanted - march["facing"] + 180.0, 360.0) - 180.0  # the short way
	var reach: float = march["sweep"] * keeping
	march["facing"] = fposmod(march["facing"] + clampf(left, -reach, reach), 360.0)
	march["travelled"] += march["step"] * ground * keeping
	places = _places(route, width, march["travelled"], march["facing"])
	for i in places.size():
		march["files"][i] = march["files"][i].move_toward(places[i], march["step"] * ground)
	march["ticks"] += 1


## The front rank's places, a line `width` wide facing `heading` at `cells` along `route`.
static func _places(route: FormationRoute, width: int, cells: float, heading: float) -> Array:
	var anchor := route.point_at(cells)
	var ahead := UnitMotion.vector(heading)
	var out := []
	for column in range(width):
		var across := column - width / 2.0 + 0.5
		out.append(anchor - ahead.orthogonal() * across - ahead * 0.5)
	return out


static func _middling_slack() -> float:
	var tuning := BattleTuning.current()
	return lerpf(tuning.walk_slack_loose, tuning.walk_slack_drilled, 0.5)


static func _narrows(terrain: FormationTerrain, at: Vector2, heading: float, width: int) -> bool:
	var run := FormationNarrowing.run_across(terrain, at, heading, 1.0)
	return run.x >= 1.0 and run.x < width


## Ticks each wave should wait before setting out so all arrive together: {key: ticks}
## from {key: predicted ticks}.
static func waits(predicted: Dictionary) -> Dictionary:
	var longest := 0
	for key in predicted:
		longest = maxi(longest, predicted[key])
	var out := {}
	for key in predicted:
		out[key] = longest - predicted[key]
	return out

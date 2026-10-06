class_name FormationRendezvous
extends RefCounted
## Planned rendezvous (Decision 87, spec 27 round 2): the overlord's timing, given before
## departure, so waves on different routes reach their points together. The march is
## predicted as FormationSimulation runs it - a cell pace per tick, slowed by the ground
## along the route (Decision 85), sweeping round bends without halting (Decision 105) no
## faster than its outer file can walk (Decision 116), and at a gap narrower than the squad
## the pauses to narrow and widen - so it holds until something interferes on the way (a
## fight, a queue). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationNarrowing = preload("res://sim/skirmish/formation/formation_narrowing.gd")
const FormationWheel = preload("res://sim/skirmish/formation/formation_wheel.gd")


## Ticks for a squad `width` wide moving `cells_per_second` to reach `cells` along `route`,
## setting out from `from` cells along it, over `terrain` if given.
static func ticks_to(
	route: FormationRoute,
	cells: float,
	width: int,
	cells_per_second: float,
	tick_seconds: float,
	from: float = 0.0,
	terrain: FormationTerrain = null
) -> int:
	var step := cells_per_second * tick_seconds
	var travelled := from
	var ticks := 0
	var narrowed := false
	var facing := UnitMotion.bearing_to(Vector2.ZERO, route.heading_at(from), 0.0)
	var sweep := rad_to_deg(cells_per_second / maxf(width / 2.0, 0.5)) * tick_seconds
	while travelled < cells - 0.000001 and ticks < 1000000:
		var here := route.point_at(travelled)
		var ahead := route.heading_at(travelled)
		var share := 1.0
		if terrain != null:
			share = maxf(0.05, terrain.factor(1.0, here, here + ahead))
			var heading := UnitMotion.bearing_to(Vector2.ZERO, ahead, 0.0)
			if not narrowed and _narrows(terrain, here + ahead, heading, width):
				narrowed = true
				ticks += 2 * roundi(BattleTuning.current().reach_narrow_seconds / tick_seconds)
		var wanted := UnitMotion.bearing_to(Vector2.ZERO, ahead, facing)
		var left := fposmod(wanted - facing + 180.0, 360.0) - 180.0  # the short way
		var turned := facing + clampf(left, -sweep, sweep)  # as FormationSweep sweeps
		var stepped := step * share
		var walked := FormationWheel.line_share(
			route, width, travelled, travelled + stepped, facing, turned
		)  # no faster than its outer file walks (Decision 116)
		facing = fposmod(facing + (turned - facing) * walked, 360.0)
		travelled += stepped * walked
		ticks += 1
	return ticks


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

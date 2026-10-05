class_name FormationRendezvous
extends RefCounted
## Planned rendezvous (Decision 87, spec 27 round 2): the overlord's timing, given before
## departure, so waves on different routes reach their points together. The march is
## predicted as FormationSimulation runs it - a cell pace per tick, slowed by the ground
## along the route (Decision 85), sweeping round bends without halting (Decision 105), and
## at a gap narrower than the squad the pauses to narrow and widen - so it holds until
## something interferes on the way (a fight, a queue). Pure.

const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationNarrowing = preload("res://sim/skirmish/formation/formation_narrowing.gd")


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
	while travelled < cells - 0.000001 and ticks < 1000000:
		var here := route.point_at(travelled)
		var share := 1.0
		if terrain != null:
			var ahead := route.heading_at(travelled)
			share = maxf(0.05, terrain.factor(1.0, here, here + ahead))
			var heading := UnitMotion.bearing_to(Vector2.ZERO, ahead, 0.0)
			if not narrowed and _narrows(terrain, here + ahead, heading, width):
				narrowed = true
				ticks += 2 * roundi(FormationNarrowing.REFORM_SECONDS / tick_seconds)
		travelled += step * share
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

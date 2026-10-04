class_name FormationRendezvous
extends RefCounted
## Planned rendezvous (Decision 87, spec 27 round 2): the overlord's timing, given before
## departure, so waves on different routes reach their points together. The march is
## predicted exactly as FormationSimulation runs it - a cell pace per tick, and at each bend
## a wheel (SquadTurn.wheel_ticks, plus the tick it starts on) - so it holds until
## something interferes on the way (a fight, a queue). Pure.

const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadTurn = preload("res://sim/skirmish/formation/squad_turn.gd")


## Ticks for a squad `width` wide moving `cells_per_second` to reach `cells` along `route`,
## setting out from `from` cells along it.
static func ticks_to(
	route: FormationRoute,
	cells: float,
	width: int,
	cells_per_second: float,
	tick_seconds: float,
	from: float = 0.0
) -> int:
	var step := cells_per_second * tick_seconds
	var facing := route.facing_at(from, 1, SquadFrame.EAST)
	var travelled := from
	var ticks := 0
	while travelled < cells - 0.000001 and ticks < 1000000:
		var wanted := route.facing_at(travelled, 1, facing)
		if wanted != facing:
			var turn := SquadTurn.wheel_ticks(width, cells_per_second, tick_seconds)
			ticks += 1 + (turn * 2 if wanted == SquadFrame.opposite(facing) else turn)
			facing = wanted
			continue
		travelled += step
		ticks += 1
	return ticks


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

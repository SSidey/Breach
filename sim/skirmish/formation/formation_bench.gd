class_name FormationBench
extends RefCounted
## How long the formation fight takes a tick as battles grow (spec 30 round 3): grems
## against kingdom militia, head-on along the lane, the same number a side, in blocks of
## the given width. Times a tick marching (before any contact) and mid-fight (once the
## fight has settled in), so a speed-up can be judged and a slow-down caught
## (tools/formation_bench.gd). Reads the clock, so not part of any battle.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")

## Ticks a battle may take to come to contact before it is given up on.
const CONTACT_LIMIT := 2000


## {"march": [avg ms, worst ms], "fight": [avg ms, worst ms], "contact": tick (-1 if none)}
## for `per_side` a side; options: width, march, settle, fight (ticks), seed.
static func measure(per_side: int, options: Dictionary) -> Dictionary:
	var sim := clash(per_side, options.get("width", 32), options.get("seed", 1))
	var marching := []
	var contact := -1
	while contact < 0 and sim.tick_number() < CONTACT_LIMIT:
		var began := Time.get_ticks_usec()
		var events := sim.step()
		if events.any(func(e): return e["type"] == "engaged"):
			contact = sim.tick_number()
		elif marching.size() < options.get("march", 10):
			marching.append((Time.get_ticks_usec() - began) / 1000.0)
	var fighting := []
	if contact >= 0:
		for _i in range(options.get("settle", 10)):
			sim.step()
		for _i in range(options.get("fight", 10)):
			var began := Time.get_ticks_usec()
			sim.step()
			fighting.append((Time.get_ticks_usec() - began) / 1000.0)
	return {"march": _spread(marching), "fight": _spread(fighting), "contact": contact}


## The battle: `per_side` grems at the player's end against as many militia, `width` wide.
static func clash(per_side: int, width: int, battle_seed: int) -> FormationSimulation:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.fight_seed = battle_seed
	var sides := [
		[load("res://content/units/grem.tres"), "player", true],
		[load("res://content/units/kingdom_militia.tres"), "the_kingdom", false],
	]
	for side in sides:
		var placements := []
		for index in range(per_side):
			placements.append([side[0], Vector2i(index / width, index % width)])
		sim.spawn_squad(width, placements, side[1], side[2])
	return sim


## [average, worst] of the times, or [0, 0] for none.
static func _spread(times: Array) -> Array:
	if times.is_empty():
		return [0.0, 0.0]
	return [times.reduce(func(a, t): return a + t, 0.0) / times.size(), times.max()]

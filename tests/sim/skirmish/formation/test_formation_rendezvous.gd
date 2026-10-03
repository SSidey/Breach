extends GdUnitTestSuite
## Planned rendezvous, per Decision 87: the march is predicted as the simulation runs it,
## bends and wheels included, so waves given the planned waits reach their points
## together.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const FormationRendezvous = preload("res://sim/skirmish/formation/formation_rendezvous.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1
const CELLS_PER_SECOND := 8.0


func _def() -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 10
	unit_def.dmg = 1
	unit_def.speed = 1.0
	return unit_def


func _line(count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([_def(), Vector2i(0, column)])
	return placements


## Steps until the squad's front has come `cells` along its route; returns the tick.
func _arrival(sim: FormationSimulation, squads: Dictionary, cells: Dictionary) -> Dictionary:
	var arrived := {}
	for _i in range(2000):
		sim.step()
		for key in squads:
			var travelled: float = squads[key].front_distance * 64.0
			if not arrived.has(key) and travelled >= cells[key] - 0.0001:
				arrived[key] = sim.tick_number()
		if arrived.size() == squads.size():
			break
	return arrived


func test_the_prediction_matches_the_march_round_bends() -> void:
	var route := FormationRoute.new(
		PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(80, 40)])
	)
	var sim := FormationSimulation.new(4.0, TICK)
	var squad := sim.spawn_squad(8, _line(8), "player", true, 0, route)

	var predicted := FormationRendezvous.ticks_to(route, 100.0, 8, CELLS_PER_SECOND, TICK)
	var actual := _arrival(sim, {"x": squad}, {"x": 100.0})

	assert_int(absi(actual["x"] - predicted)).is_less_equal(1)


func test_waves_on_routes_of_different_lengths_arrive_together() -> void:
	var short := FormationRoute.new(PackedVector2Array([Vector2(0, 0), Vector2(80, 0)]))
	var long := FormationRoute.new(
		PackedVector2Array([Vector2(0, 40), Vector2(60, 40), Vector2(60, 0), Vector2(80, 0)])
	)
	var predicted := {
		"short": FormationRendezvous.ticks_to(short, 80.0, 4, CELLS_PER_SECOND, TICK),
		"long": FormationRendezvous.ticks_to(long, 120.0, 4, CELLS_PER_SECOND, TICK),
	}
	var waits := FormationRendezvous.waits(predicted)
	var sim := FormationSimulation.new(4.0, TICK)
	var squads := {
		"short": sim.spawn_squad(4, _line(4), "player", true, waits["short"], short),
		"long": sim.spawn_squad(4, _line(4), "player", true, waits["long"], long),
	}

	var arrived := _arrival(sim, squads, {"short": 80.0, "long": 120.0})

	assert_int(waits["long"]).is_equal(0)
	assert_int(waits["short"]).is_greater(0)
	assert_int(absi(arrived["short"] - arrived["long"])).is_less_equal(2)

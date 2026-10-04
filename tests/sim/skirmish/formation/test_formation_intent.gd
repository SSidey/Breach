extends GdUnitTestSuite
## Tactical over strategic, per Decision 94 and spec 27 round 7: a formation ordered to
## march that stands still for no order of the player's moves to a fight nearby, or else
## lets go of its re-formed line and marches on; one ordered to hold stays put.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def() -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 400
	unit_def.dmg = 1
	unit_def.speed = 1.0
	return unit_def


func _row(columns: int) -> Array:
	var placements := []
	for column in range(columns):
		placements.append([_def(), Vector2i(0, column)])
	return placements


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for _i in range(ticks):
		log.append_array(sim.step())
	return log


func _sim() -> FormationSimulation:
	var sim := FormationSimulation.new(2.0, TICK)
	sim.seek_contact = true
	return sim


## A player squad marching east along y = 20, halted by a re-formed line facing south.
func _halted(sim: FormationSimulation) -> SkirmishSquad:
	var east := FormationRoute.new(PackedVector2Array([Vector2(0, 20), Vector2(128, 20)]))
	var squad := sim.spawn_squad(4, _row(4), "player", true, 0, east)
	squad.front_distance = 30.0 / 64.0
	sim.step()
	squad.stance = {"anchor": squad.position, "facing": SquadFrame.SOUTH}
	return squad


func test_halted_near_an_enemy_it_goes_to_fight() -> void:
	var sim := _sim()
	var squad := _halted(sim)
	var hold := FormationRoute.new(PackedVector2Array([Vector2(30, 28), Vector2(30, 64)]))
	var foe := sim.spawn_squad(4, _row(4), "the_kingdom", true, 0, hold)
	sim.order(foe.id, SkirmishUnit.Order.HOLD)

	var log := _run(sim, 80)

	var engaged := log.filter(func(e): return e["type"] == "engaged" and e["squad"] == squad.id)
	assert_bool(engaged.is_empty()).is_false()
	assert_int(engaged[0]["with"]).is_equal(foe.id)


func test_halted_with_no_enemy_near_it_marches_on() -> void:
	var sim := _sim()
	var squad := _halted(sim)
	var start := squad.position.x

	_run(sim, 100)

	assert_bool(squad.stance.is_empty()).is_true()
	assert_float(squad.position.x).is_greater(start + 2.0)


func test_a_formation_ordered_to_hold_stays_put() -> void:
	var sim := _sim()
	var squad := _halted(sim)
	sim.order(squad.id, SkirmishUnit.Order.HOLD)
	var hold := FormationRoute.new(PackedVector2Array([Vector2(30, 28), Vector2(30, 64)]))
	var foe := sim.spawn_squad(4, _row(4), "the_kingdom", true, 0, hold)
	sim.order(foe.id, SkirmishUnit.Order.HOLD)

	var log := _run(sim, 80)

	assert_int(log.filter(func(e): return e["type"] == "engaged").size()).is_equal(0)


func test_a_wave_re_forming_at_its_corner_as_a_fights_does_not_stick() -> void:
	# the round 6 feel test: B re-formed facing the line fighting A, and stayed there
	var field := FormationField.new(
		TICK,
		load("res://content/units/grem.tres"),
		4,
		load("res://content/units/kingdom_militia.tres"),
		load("res://content/units/grem_chieftain.tres"),
		null,
		727784
	)
	field.waves["A"].route = field.routes["C"]
	for _i in range(3000):
		if field.waves["A"].built() == 8 and field.waves["B"].built() == 9:
			break
		field.step()
	var wave := field.send("B")
	for _i in range(10):
		field.step()
	field.send("A")

	var still := 0
	var longest := 0
	var last := wave.position
	for _i in range(1200):
		field.step()
		var moving := wave.state in [SkirmishSquad.State.MOVING, SkirmishSquad.State.HOLDING]
		still = still + 1 if moving and wave.position == last else 0
		longest = maxi(longest, still)
		last = wave.position

	assert_int(longest).is_less(60)

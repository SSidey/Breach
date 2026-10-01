extends GdUnitTestSuite
## SkirmishSimulation, per specs/21-realtime-skirmish-feel-test.md: two factions' melee
## units on one route, stepped deterministically, with orders applied on the next tick.

const SkirmishSimulation = preload("res://sim/skirmish/skirmish_simulation.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const ROUTE := 9.0
const TICK := 0.1


func _def(hp: int, dmg: int, speed: float) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = speed
	return unit_def


func _grem() -> UnitDef:
	return _def(20, 6, 1.0)


func _militia() -> UnitDef:
	return _def(26, 5, 0.8)


func _sim() -> SkirmishSimulation:
	return SkirmishSimulation.new(ROUTE, TICK)


func _step_until(sim: SkirmishSimulation, done: Callable, limit: int = 4000) -> Array:
	var log := []
	for i in range(limit):
		log.append_array(sim.step())
		if done.call():
			break
	return log


func _names(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func test_units_start_at_their_own_ends() -> void:
	var sim := _sim()

	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)

	assert_float(grem.distance).is_equal(0.0)
	assert_float(militia.distance).is_equal(ROUTE)
	assert_int(grem.state).is_equal(SkirmishUnit.State.MOVING)


func test_advancing_units_move_speed_times_travel_scale_times_tick() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)

	sim.step()

	# Playtest 1: travel at x1 felt too fast, so speed is scaled by TRAVEL_SCALE (0.5).
	assert_float(grem.distance).is_equal_approx(1.0 * 0.5 * TICK, 0.0001)
	assert_float(militia.distance).is_equal_approx(ROUTE - 0.8 * 0.5 * TICK, 0.0001)


func test_hostiles_meet_engage_and_stop_without_passing_through() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)

	var log := _step_until(sim, func(): return grem.state == SkirmishUnit.State.FIGHTING)

	assert_array(_names(log)).contains(["engaged"])
	assert_int(militia.state).is_equal(SkirmishUnit.State.FIGHTING)
	assert_float(militia.distance - grem.distance).is_less_equal(SkirmishSimulation.MELEE_REACH)
	assert_float(militia.distance - grem.distance).is_greater(0.0)


func test_melee_is_deterministic_and_the_militia_narrowly_wins_one_on_one() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)
	_step_until(sim, func(): return grem.state == SkirmishUnit.State.FIGHTING)
	var engaged_at := sim.tick_number()

	_step_until(sim, func(): return grem.state == SkirmishUnit.State.DEAD)

	# Blows are simultaneous once a second from the engaging tick: the grem takes its
	# fourth 5-damage blow 3 s after engaging; the militia has taken 24 of its 26.
	assert_float((sim.tick_number() - engaged_at) * TICK).is_equal_approx(3.0, 0.0001)
	assert_int(militia.hp).is_equal(2)
	assert_int(militia.state).is_not_equal(SkirmishUnit.State.DEAD)


func test_the_same_inputs_replay_to_the_same_events() -> void:
	var runs := []
	for run in range(2):
		var sim := _sim()
		var grem := sim.spawn(_grem(), "player", true)
		sim.spawn(_militia(), "the_kingdom", false)
		var log := []
		for i in range(400):
			if i == 150:
				sim.order(grem.id, SkirmishUnit.Order.RETREAT)
			log.append_array(sim.step())
		runs.append(JSON.stringify(log))

	assert_str(runs[0]).is_equal(runs[1])


func test_an_order_applies_on_the_next_tick_and_retreat_disengages() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)
	_step_until(sim, func(): return grem.state == SkirmishUnit.State.FIGHTING)
	var before := grem.distance

	sim.order(grem.id, SkirmishUnit.Order.RETREAT)
	assert_int(grem.order).is_equal(SkirmishUnit.Order.ADVANCE)  # not until the tick
	var events := sim.step()

	assert_array(_names(events)).contains(["order_applied", "disengaged"])
	assert_int(grem.state).is_equal(SkirmishUnit.State.MOVING)
	assert_float(grem.distance).is_less(before)
	assert_int(militia.target_id).is_equal(0)


func test_hold_stops_movement_but_a_holding_unit_still_fights() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	sim.order(grem.id, SkirmishUnit.Order.HOLD)
	var militia := sim.spawn(_militia(), "the_kingdom", false)

	_step_until(sim, func(): return militia.state == SkirmishUnit.State.FIGHTING)

	assert_float(grem.distance).is_equal(0.0)
	assert_int(grem.state).is_equal(SkirmishUnit.State.FIGHTING)


func test_reaching_the_enemy_end_is_arrival_and_the_fort_is_immune() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)

	var log := _step_until(sim, func(): return grem.state == SkirmishUnit.State.ARRIVED)

	assert_float(grem.distance).is_equal(ROUTE)
	assert_array(_names(log)).contains(["arrived"])
	assert_array(_names(log)).not_contains(["hit"])
	sim.step()
	assert_float(grem.distance).is_equal(ROUTE)


func test_a_dead_unit_frees_its_attacker_which_moves_on() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)
	var log := _step_until(sim, func(): return grem.state == SkirmishUnit.State.DEAD)

	assert_array(_names(log)).contains(["died"])
	assert_int(militia.target_id).is_equal(0)
	var at := militia.distance
	sim.step()
	assert_float(militia.distance).is_less(at)


func test_two_grems_beat_one_militia() -> void:
	var sim := _sim()
	var first := sim.spawn(_grem(), "player", true)
	var second := sim.spawn(_grem(), "player", true)
	var militia := sim.spawn(_militia(), "the_kingdom", false)

	_step_until(sim, func(): return militia.state == SkirmishUnit.State.DEAD)

	assert_int(first.state).is_not_equal(SkirmishUnit.State.DEAD)
	assert_int(second.state).is_not_equal(SkirmishUnit.State.DEAD)


func test_a_waiting_unit_does_not_move_until_its_wait_ends() -> void:
	var sim := _sim()
	var grem := sim.spawn(_grem(), "player", true, 2)

	sim.step()
	sim.step()
	assert_float(grem.distance).is_equal(0.0)
	sim.step()
	assert_float(grem.distance).is_greater(0.0)

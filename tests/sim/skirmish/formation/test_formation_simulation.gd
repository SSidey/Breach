extends GdUnitTestSuite
## FormationSimulation, per specs/22-formation-feel-test.md and Decision 40: squads in
## formation on one lane - front ranks fight, the ranks behind step up, and a wider line
## wraps onto the flanks.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const ROUTE := 9.0
const TICK := 0.1


func _def(hp: int, dmg: int, speed: float, depth: int = 1, width: int = 1) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = speed
	unit_def.footprint_depth = depth
	unit_def.footprint_width = width
	return unit_def


func _grem() -> UnitDef:
	return _def(20, 6, 1.0)


func _militia() -> UnitDef:
	return _def(26, 5, 0.8)


## A single-rank line of `count` units, `width` wide.
func _line(unit_def: UnitDef, count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([unit_def, Vector2i(0, column)])
	return placements


func _run(sim: FormationSimulation, done: Callable, limit: int = 4000) -> Array:
	var log := []
	for i in range(limit):
		log.append_array(sim.step())
		if done.call():
			break
	return log


func _of(events: Array, kind: String) -> Array:
	return events.filter(func(e): return e["type"] == kind)


func test_squads_meet_and_stop_at_melee_reach() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(1, _line(_grem(), 1), "player", true)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)

	_run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)

	assert_int(theirs.state).is_equal(SkirmishSquad.State.FIGHTING)
	var gap := theirs.front_distance - mine.front_distance
	assert_float(gap).is_less_equal(FormationSimulation.MELEE_REACH + 0.0001)
	assert_float(gap).is_greater(0.0)


func test_the_spec_21_duel_still_holds() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(1, _line(_grem(), 1), "player", true)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)
	_run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)
	var engaged_at := sim.tick_number()

	_run(sim, func(): return mine.is_destroyed())

	assert_float((sim.tick_number() - engaged_at) * TICK).is_equal_approx(3.0, 0.0001)
	assert_int(theirs.units[0].hp).is_equal(2)


func test_only_the_front_rank_fights_and_the_rank_behind_steps_up() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var column := [[_grem(), Vector2i(0, 0)], [_grem(), Vector2i(1, 0)]]
	var mine := sim.spawn_squad(1, column, "player", true)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)
	var front_id := mine.units[0].id
	var back_id := mine.units[1].id

	# The militia beats the front grem on 2 hp; the grem behind steps up and finishes it.
	var log := _run(sim, func(): return theirs.is_destroyed() or mine.is_destroyed())

	var first_death: int = _of(log, "died").filter(func(e): return e["unit"] == front_id)[0]["tick"]
	var back_hits := _of(log, "hit").filter(func(e): return e["unit"] == back_id)
	assert_bool(back_hits.all(func(e): return e["tick"] > first_death)).is_true()
	assert_int(back_hits.size()).is_greater(0)
	assert_array(_of(log, "stepped_up").map(func(e): return e["unit"])).contains([back_id])


func test_a_wider_line_wraps_onto_the_flanks_for_bonus_damage() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(5, _line(_grem(), 5), "player", true)
	sim.spawn_squad(3, _line(_militia(), 3), "the_kingdom", false)

	var log := _run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)
	var first := _of(log, "hit").filter(func(e): return e["tick"] == sim.tick_number())
	var exchange := first.filter(func(e): return e["faction"] == "player")

	assert_int(exchange.size()).is_equal(5)
	var flanks := exchange.filter(func(e): return e["flank"])
	assert_int(flanks.size()).is_equal(2)
	assert_bool(flanks.all(func(e): return e["dmg"] == 9)).is_true()
	(
		assert_bool(
			exchange.filter(func(e): return not e["flank"]).all(func(e): return e["dmg"] == 6)
		)
		. is_true()
	)


func test_a_unit_struck_by_several_takes_every_blow_but_strikes_once() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(5, _line(_grem(), 5), "player", true)
	var theirs := sim.spawn_squad(3, _line(_militia(), 3), "the_kingdom", false)

	var log := _run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)
	var hits := _of(log, "hit").filter(func(e): return e["tick"] == sim.tick_number())
	var end_militia := theirs.units[2].id  # its column is the player's left flank end

	assert_int(hits.filter(func(e): return e["target"] == end_militia).size()).is_equal(2)
	assert_int(hits.filter(func(e): return e["unit"] == end_militia).size()).is_equal(1)


func test_a_holding_squad_stays_put_and_still_fights() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(1, _line(_grem(), 1), "player", true)
	sim.order(mine.id, SkirmishUnit.Order.HOLD)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)

	_run(sim, func(): return theirs.state == SkirmishSquad.State.FIGHTING)

	assert_float(mine.front_distance).is_equal(0.0)
	assert_int(mine.state).is_equal(SkirmishSquad.State.FIGHTING)


func test_a_retreating_squad_disengages_and_the_enemy_is_freed() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(1, _line(_grem(), 1), "player", true)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)
	_run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)
	var at := mine.front_distance

	sim.order(mine.id, SkirmishUnit.Order.RETREAT)
	var events := sim.step()

	assert_array(events.map(func(e): return e["type"])).contains(["disengaged", "turning"])
	assert_int(theirs.engaged_with).is_equal(0)
	# It about-faces first (Decision 74), then marches home.
	_run(sim, func(): return mine.state == SkirmishSquad.State.MOVING)
	sim.step()
	assert_float(mine.front_distance).is_less(at)


func test_reaching_the_enemy_end_is_arrival() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(2, _line(_grem(), 2), "player", true)

	var log := _run(sim, func(): return mine.state == SkirmishSquad.State.ARRIVED)

	assert_float(mine.front_distance).is_equal(ROUTE)
	assert_int(_of(log, "arrived").size()).is_equal(1)


func test_a_destroyed_squad_frees_its_opponent_to_move_on() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var mine := sim.spawn_squad(1, _line(_grem(), 1), "player", true)
	var theirs := sim.spawn_squad(1, _line(_militia(), 1), "the_kingdom", false)
	_run(sim, func(): return mine.is_destroyed())

	assert_int(mine.state).is_equal(SkirmishSquad.State.DESTROYED)
	var at := theirs.front_distance
	sim.step()
	assert_float(theirs.front_distance).is_less(at)


func test_the_same_inputs_replay_to_the_same_events() -> void:
	var runs := []
	for run in range(2):
		var sim := FormationSimulation.new(ROUTE, TICK)
		var mine := sim.spawn_squad(5, _line(_grem(), 5), "player", true)
		sim.spawn_squad(3, _line(_militia(), 3), "the_kingdom", false)
		var log := []
		for i in range(600):
			if i == 200:
				sim.order(mine.id, SkirmishUnit.Order.RETREAT)
			log.append_array(sim.step())
		runs.append(JSON.stringify(log))

	assert_str(runs[0]).is_equal(runs[1])

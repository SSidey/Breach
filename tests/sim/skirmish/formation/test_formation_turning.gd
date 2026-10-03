extends GdUnitTestSuite
## Turning, per Decision 74 and spec 27 round 1: a squad wheels where its route bends, for
## as long as its outer end needs to march the quarter arc; it about-faces to go back the
## way it faces, its back rank becoming its front. While turning it neither advances nor
## strikes, and blows on it are flank blows.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadTurn = preload("res://sim/skirmish/formation/squad_turn.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(hp: int, dmg: int, preferred: int = 0) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = 1.0
	unit_def.preferred_position = preferred
	return unit_def


func _line(unit_def: UnitDef, count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([unit_def, Vector2i(0, column)])
	return placements


func _run(sim: FormationSimulation, done: Callable, limit: int = 2000) -> Array:
	var log := []
	for _i in range(limit):
		log.append_array(sim.step())
		if done.call():
			break
	return log


func _of(events: Array, kind: String) -> Array:
	return events.filter(func(e): return e["type"] == kind)


func test_a_wheel_takes_as_long_as_the_outer_end_marches_its_quarter_arc() -> void:
	var sim := FormationSimulation.new(4.0, TICK)
	var bend := FormationRoute.new(
		PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 80)])
	)
	var squad := sim.spawn_squad(16, _line(_def(20, 2), 16), "player", true, 0, bend)

	var log := _run(sim, func(): return squad.facing == SquadFrame.SOUTH)

	var turning: Array = _of(log, "turning")
	var turned: Array = _of(log, "turned")
	assert_int(turning.size()).is_equal(1)
	assert_int(turned[0]["tick"] - turning[0]["tick"]).is_equal(
		SquadTurn.wheel_ticks(16, 8.0, TICK)
	)
	assert_int(turned[0]["facing"]).is_equal(SquadFrame.SOUTH)


func test_a_turning_squad_stands_still() -> void:
	var sim := FormationSimulation.new(4.0, TICK)
	var bend := FormationRoute.new(
		PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 80)])
	)
	var squad := sim.spawn_squad(16, _line(_def(20, 2), 16), "player", true, 0, bend)
	_run(sim, func(): return squad.state == SkirmishSquad.State.TURNING)
	var at := squad.position

	for _i in range(5):
		sim.step()
		assert_vector(squad.position).is_equal(at)


func test_a_turning_squad_does_not_strike_and_takes_flank_blows() -> void:
	var sim := FormationSimulation.new(4.0, TICK)
	var mine := sim.spawn_squad(1, _line(_def(100, 6), 1), "player", true)
	var theirs := sim.spawn_squad(1, _line(_def(100, 4), 1), "the_kingdom", false)
	_run(sim, func(): return mine.state == SkirmishSquad.State.FIGHTING)
	mine.state = SkirmishSquad.State.TURNING
	mine.turn_to = mine.facing
	mine.turn_ticks = 1000
	var their_hp := theirs.living()[0].hp

	var log := _run(sim, func(): return false, 25)

	assert_int(theirs.living()[0].hp).is_equal(their_hp)
	var hits: Array = _of(log, "hit")
	assert_bool(hits.is_empty()).is_false()
	for hit in hits:
		assert_str(hit["faction"]).is_equal("the_kingdom")
		assert_bool(hit["flank"]).is_true()
		assert_int(hit["dmg"]).is_equal(FormationCombat.damage(theirs.living()[0], true))


func test_a_retreat_about_faces_and_the_back_rank_leads_home() -> void:
	var sim := FormationSimulation.new(4.0, TICK)
	var placements := [[_def(20, 2), Vector2i(0, 0)], [_def(20, 2, 2), Vector2i(1, 0)]]
	var squad := sim.spawn_squad(1, placements, "player", true)
	var front: SkirmishUnit = squad.units[0]
	var back: SkirmishUnit = squad.units[1]
	_run(sim, func(): return squad.front_distance > 1.0)

	sim.order(squad.id, SkirmishUnit.Order.RETREAT)
	var log := _run(sim, func(): return squad.direction < 0)

	assert_int(_of(log, "turned")[0]["tick"] - _of(log, "turning")[0]["tick"]).is_equal(
		SquadTurn.about_face_ticks(TICK)
	)
	assert_int(squad.facing).is_equal(SquadFrame.WEST)
	assert_int(back.rank).is_equal(0)
	assert_int(front.rank).is_equal(1)
	var returned := _run(sim, func(): return squad.state == SkirmishSquad.State.HOLDING)
	assert_int(_of(returned, "returned").size()).is_equal(1)


func test_advancing_again_turns_the_squad_back_round() -> void:
	var sim := FormationSimulation.new(4.0, TICK)
	var squad := sim.spawn_squad(2, _line(_def(20, 2), 2), "player", true)
	_run(sim, func(): return squad.front_distance > 0.5)
	sim.order(squad.id, SkirmishUnit.Order.RETREAT)
	_run(sim, func(): return squad.state == SkirmishSquad.State.HOLDING)

	sim.order(squad.id, SkirmishUnit.Order.ADVANCE)
	var log := _run(sim, func(): return squad.direction > 0)

	assert_int(_of(log, "turning").size()).is_equal(1)
	assert_int(squad.facing).is_equal(SquadFrame.EAST)


func test_turning_replays_the_same() -> void:
	var logs := []
	for _run_index in range(2):
		var sim := FormationSimulation.new(4.0, TICK)
		var bend := FormationRoute.new(
			PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(30, 60)])
		)
		var squad := sim.spawn_squad(8, _line(_def(20, 2), 8), "player", true, 0, bend)
		var log := _run(sim, func(): return squad.front_distance > 0.9)
		sim.order(squad.id, SkirmishUnit.Order.RETREAT)
		log.append_array(_run(sim, func(): return false, 40))
		logs.append(log)

	assert_array(logs[1]).is_equal(logs[0])

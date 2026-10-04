extends GdUnitTestSuite
## Fronts on four edges, per Decision 78 and spec 27 round 2: a squad whose front reaches a
## hostile's side or rear locks onto that edge; the units there turn and fight back; its
## first blows are flank blows; a corner unit strikes back at one foe; and when the edge's
## units fall back inward the attacker advances to them again.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(hp: int, dmg: int) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = 1.0
	return unit_def


func _block(unit_def: UnitDef, ranks: int, columns: int) -> Array:
	var placements := []
	for rank in range(ranks):
		for column in range(columns):
			placements.append([unit_def, Vector2i(rank, column)])
	return placements


func _route(points: Array) -> FormationRoute:
	return FormationRoute.new(PackedVector2Array(points))


## A kingdom line 4 wide facing west, holding with its front at (40, 32): it covers x 40 to
## 40 + ranks and y 30 to 34; its right edge is its north face.
func _line(sim: FormationSimulation, ranks: int = 1, hp: int = 100) -> SkirmishSquad:
	var route := _route([Vector2(40, 32), Vector2(0, 32)])
	var line := sim.spawn_squad(4, _block(_def(hp, 2), ranks, 4), "the_kingdom", true, 0, route)
	sim.order(line.id, SkirmishUnit.Order.HOLD)
	return line


## A player squad 2 wide coming south down x = 41 onto the line's north face.
func _from_north(sim: FormationSimulation, dmg: int = 3) -> SkirmishSquad:
	var route := _route([Vector2(41, 0), Vector2(41, 64)])
	return sim.spawn_squad(2, _block(_def(100, dmg), 1, 2), "player", true, 0, route)


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for _i in range(ticks):
		log.append_array(sim.step())
	return log


func _of(log: Array, kind: String) -> Array:
	return log.filter(func(e): return e["type"] == kind)


func test_a_squad_reaching_a_side_locks_onto_it_and_both_fight() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var line := _line(sim)
	var raider := _from_north(sim)

	var log := _run(sim, 80)

	var flanked: Array = _of(log, "flanked")
	assert_int(flanked.size()).is_equal(1)
	assert_int(flanked[0]["edge"]).is_equal(SquadEdges.RIGHT)
	assert_int(line.state).is_equal(SkirmishSquad.State.FIGHTING)
	assert_int(raider.engaged_with).is_equal(line.id)
	var hits: Array = _of(log, "hit")
	assert_bool(hits.any(func(h): return h["faction"] == "player")).is_true()
	assert_bool(hits.any(func(h): return h["faction"] == "the_kingdom")).is_true()
	assert_float(raider.position.y).is_less(30.0)


func test_only_the_first_blows_on_a_side_are_flank_blows() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	_line(sim)
	_from_north(sim)

	var log := _run(sim, 120)

	var raids: Array = _of(log, "hit").filter(func(h): return h["faction"] == "player")
	var start: int = _of(log, "flanked")[0]["tick"]
	for hit in raids:
		assert_bool(hit["flank"]).is_equal(hit["tick"] - start < 10)
	assert_bool(raids.any(func(h): return not h["flank"])).is_true()


func test_a_squad_from_behind_strikes_the_rear() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var line := _line(sim)
	var route := _route([Vector2(90, 32), Vector2(0, 32)])
	sim.spawn_squad(4, _block(_def(100, 3), 1, 4), "player", true, 0, route)

	var log := _run(sim, 120)

	var flanked: Array = _of(log, "flanked")
	assert_int(flanked.size()).is_equal(1)
	assert_int(flanked[0]["edge"]).is_equal(SquadEdges.REAR)
	assert_bool(line.flank_contacts.has(SquadEdges.REAR)).is_true()


func test_a_squad_fights_its_front_and_a_side_at_once() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var line := _line(sim, 2)
	var front := sim.spawn_squad(
		4, _block(_def(100, 3), 1, 4), "player", true, 0, _route([Vector2(0, 32), Vector2(90, 32)])
	)
	var raider := _from_north(sim)
	for _i in range(300):
		sim.step()
		if line.engaged_with != 0 and line.flank_contacts.has(SquadEdges.RIGHT):
			break

	assert_int(line.engaged_with).is_equal(front.id)
	var log := _run(sim, 40)  # both at once, before the line's morale gives
	var targets := {}
	for hit in _of(log, "hit").filter(func(h): return h["faction"] == "the_kingdom"):
		targets[hit["target"]] = true
	var raider_ids := raider.units.map(func(u): return u.id)
	var front_ids := front.units.map(func(u): return u.id)
	assert_bool(targets.keys().any(func(t): return raider_ids.has(t))).is_true()
	assert_bool(targets.keys().any(func(t): return front_ids.has(t))).is_true()


func test_a_corner_unit_strikes_back_at_one_foe() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	_line(sim, 1)
	sim.spawn_squad(
		4, _block(_def(100, 3), 1, 4), "player", true, 0, _route([Vector2(0, 32), Vector2(90, 32)])
	)
	_from_north(sim)

	var log := _run(sim, 200)

	var per_tick := {}
	for hit in _of(log, "hit").filter(func(h): return h["faction"] == "the_kingdom"):
		var key := "%d:%d" % [hit["tick"], hit["unit"]]
		per_tick[key] = per_tick.get(key, 0) + 1
	assert_bool(per_tick.values().all(func(n): return n == 1)).is_true()


func test_when_the_edge_falls_back_the_attacker_advances_to_it_again() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var line := _line(sim, 1, 6)
	_from_north(sim, 8)

	var log := _run(sim, 300)

	assert_int(_of(log, "flank_released").size()).is_greater_equal(1)
	assert_int(_of(log, "flanked").size()).is_greater_equal(2)
	assert_int(line.living().size()).is_less(4)


func test_crossing_squads_no_longer_pass_through_each_other() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var east := _route([Vector2(0, 32), Vector2(100, 32)])
	var north := _route([Vector2(50, 70), Vector2(50, 0)])
	sim.spawn_squad(4, _block(_def(100, 3), 1, 4), "player", true, 0, east)
	sim.spawn_squad(4, _block(_def(100, 3), 1, 4), "the_kingdom", true, 15, north)

	var log := _run(sim, 200)

	assert_int(_of(log, "flanked").size()).is_greater_equal(1)
	assert_int(_of(log, "arrived").size()).is_equal(0)


func test_only_units_in_contact_with_the_face_strike() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	_line(sim)  # one rank deep: its north face is one cell, x 40 to 41
	var route := _route([Vector2(41, 0), Vector2(41, 64)])
	var raider := sim.spawn_squad(6, _block(_def(100, 3), 1, 6), "player", true, 0, route)

	var log := _run(sim, 120)

	var strikers := {}
	for hit in _of(log, "hit").filter(func(h): return h["faction"] == "player"):
		strikers[hit["unit"]] = true
	assert_int(raider.living().size()).is_equal(6)
	assert_int(strikers.size()).is_equal(3)  # the one facing the face and the two at its corners

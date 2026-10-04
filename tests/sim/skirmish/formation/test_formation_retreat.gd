extends GdUnitTestSuite
## Retreat and pursuit, per Decision 95 and spec 27 round 8: an ordered retreat breaks
## contact at once; a drilled formation withdraws fighting and gets away cheaply, a ragged
## one turns and runs, takes a scaled rout and pays in losses; an enemy ordered to pursue,
## or led by a pursuer, follows; one that isn't returns to formation, though its
## undisciplined units may break ranks to chase, decided unit by unit.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const ScrumPursuit = preload("res://sim/skirmish/formation/scrum_pursuit.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _def(discipline: int, tactics: Array[String] = []) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 60
	unit_def.dmg = 3
	unit_def.speed = 1.0
	unit_def.discipline = discipline
	unit_def.tactics = tactics
	return unit_def


func _row(unit_def: UnitDef) -> Array:
	var placements := []
	for column in range(8):
		placements.append([unit_def, Vector2i(0, column)])
	return placements


## A head-on fight of 8 v 8; 3 s in, the player's squad is ordered to retreat. Returns
## [sim, mine, theirs, log after the order, the player's losses after it, the morale it lost
## on the order's tick].
func _retreat(mine: UnitDef, theirs: UnitDef, battle_seed: int = 1, pursue := false) -> Array:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.seek_contact = true
	sim.fight_seed = battle_seed
	sim.damage_band = 0.25
	var me := sim.spawn_squad(8, _row(mine), "player", true)
	var foe := sim.spawn_squad(8, _row(theirs), "the_kingdom", false)
	foe.pursues = pursue
	for _i in range(400):
		if sim.step().any(func(e): return e["type"] == "engaged"):
			break
	for _i in range(30):
		sim.step()
	sim.order(me.id, SkirmishUnit.Order.RETREAT)
	var before := me.morale
	var log := sim.step()
	var shock := before - me.morale
	for _i in range(400):
		log.append_array(sim.step())
	var lost := log.filter(func(e): return e["type"] == "died" and e["faction"] == "player")
	return [sim, me, foe, log, lost.size(), shock]


func test_a_retreat_breaks_contact_at_once_and_heads_home() -> void:
	var setup := _retreat(_def(60), _def(60))
	var me: SkirmishSquad = setup[1]
	var log: Array = setup[3]

	assert_bool(log.any(func(e): return e["type"] == "disengaged")).is_true()
	assert_int(me.engaged_with).is_equal(0)
	assert_float(me.position.x).is_less(60.0)


func test_a_drilled_withdrawal_costs_less_than_a_ragged_flight() -> void:
	var drilled := 0
	var ragged := 0
	for battle_seed in range(1, 6):
		drilled += _retreat(_def(60), _def(60), battle_seed)[4]
		ragged += _retreat(_def(20), _def(60), battle_seed)[4]

	assert_int(drilled).is_less(ragged)


func test_a_ragged_retreat_takes_a_scaled_rout() -> void:
	var ragged := _retreat(_def(20), _def(60))
	var drilled := _retreat(_def(60), _def(60))

	assert_int(ragged[5]).is_greater_equal(ScrumPursuit.RAGGED_SHOCK * 3 / 5 - 2)
	assert_int(drilled[5]).is_less(ragged[5])


func test_an_enemy_ordered_to_pursue_follows() -> void:
	var setup := _retreat(_def(60), _def(60), 1, true)

	assert_bool(setup[3].any(func(e): return e["type"] == "pursuing")).is_true()


func test_a_leader_who_pursues_leads_the_pursuit() -> void:
	var tactics: Array[String] = ["pursues"]
	var setup := _retreat(_def(60), _def(60, tactics))

	assert_bool(ScrumPursuit.pursues(setup[2])).is_true()
	assert_bool(setup[3].any(func(e): return e["type"] == "pursuing")).is_true()


func test_undisciplined_units_break_ranks_to_chase_one_by_one() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.seek_contact = true
	var me := sim.spawn_squad(8, _row(_def(60)), "player", true)
	var ragged := sim.spawn_squad(8, _row(_def(0)), "the_kingdom", false)
	for _i in range(400):
		if sim.step().any(func(e): return e["type"] == "engaged"):
			break
	for _i in range(30):
		sim.step()
	sim.order(me.id, SkirmishUnit.Order.RETREAT)
	var most := 0
	for _i in range(5):
		sim.step()
		most = maxi(most, ragged.chasers.size())

	assert_int(most).is_greater(0)
	assert_int(most).is_less(ragged.living().size())  # some chase, not all


func test_a_pursuing_formation_follows_as_a_body_then_returns_to_its_post() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.seek_contact = true
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 32), Vector2(128, 32)]))
	var me := sim.spawn_squad(8, _row(_def(20)), "player", true, 0, route)
	var line := sim.spawn_squad(8, _row(_def(60)), "the_kingdom", false, 0, route)
	line.front_distance = 80.0 / 64.0
	sim.order(line.id, SkirmishUnit.Order.HOLD)
	line.pursues = true
	for _i in range(400):
		if sim.step().any(func(e): return e["type"] == "engaged"):
			break
	for _i in range(20):
		sim.step()
	sim.order(me.id, SkirmishUnit.Order.RETREAT)
	var furthest := line.position.x
	var log := []
	for _i in range(900):
		log.append_array(sim.step())
		furthest = minf(furthest, line.position.x)

	assert_float(furthest).is_less(70.0)  # the formation itself followed
	assert_bool(log.any(func(e): return e["type"] == "pursuit_ended")).is_true()
	assert_float(line.position.x).is_greater(76.0)  # and went back to its post
	assert_int(line.order).is_equal(SkirmishUnit.Order.HOLD)
	assert_bool(line.pursuit.is_empty()).is_true()

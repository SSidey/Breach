extends GdUnitTestSuite
## Withdrawals and disorderly flight, per Decision 99 and spec 27 round 10: a retreat is
## combat's equal; its units flee homeward from where they stand, not via their places;
## it re-forms on its route only once safe, then marches home; one with nowhere further to
## go re-forms at home; the less ordered it is the wider it fans out, and a rout fans out
## wholly unless a friend stands between it and home.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationManoeuvre = preload("res://sim/skirmish/formation/formation_manoeuvre.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _def(discipline: int) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 60
	unit_def.dmg = 3
	unit_def.speed = 1.0
	unit_def.discipline = discipline
	return unit_def


func _row(unit_def: UnitDef, count: int = 8) -> Array:
	var placements := []
	for column in range(count):
		placements.append([unit_def, Vector2i(0, column)])
	return placements


## 8 v 8 head-on; 3 s into the fight the player's squad is ordered to retreat.
## Returns [sim, mine, theirs].
func _fight_then_retreat(discipline: int) -> Array:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.seek_contact = true
	sim.fight_seed = 3
	var me := sim.spawn_squad(8, _row(_def(discipline)), "player", true)
	var foe := sim.spawn_squad(8, _row(_def(60)), "the_kingdom", false)
	for _i in range(400):
		if sim.step().any(func(e): return e["type"] == "engaged"):
			break
	for _i in range(30):
		sim.step()
	sim.order(me.id, SkirmishUnit.Order.RETREAT)
	return [sim, me, foe]


func _spread_y(squad: SkirmishSquad) -> float:
	var ys: Array = squad.living().map(func(u): return ScrumReach.at(squad, u).y)
	return ys.max() - ys.min()


func test_a_retreat_withdraws_at_combats_priority_from_where_its_units_stand() -> void:
	var setup := _fight_then_retreat(60)
	var me: SkirmishSquad = setup[1]
	var foe: SkirmishSquad = setup[2]
	setup[0].step()
	var front: float = foe.living().map(func(u): return u.position.x).min()
	var before := {}
	for unit in me.living():
		before[unit.id] = ScrumReach.at(me, unit).x

	for _i in range(10):
		setup[0].step()

	assert_int(me.manoeuvre).is_equal(FormationManoeuvre.Kind.WITHDRAW)
	for unit in me.living():  # every unit heads away, none back towards its place first
		assert_float(ScrumReach.at(me, unit).x).is_less(before[unit.id])
		assert_float(ScrumReach.at(me, unit).x).is_less(front)


func test_it_re_forms_only_once_safe_then_marches_home() -> void:
	var setup := _fight_then_retreat(60)
	var me: SkirmishSquad = setup[1]
	setup[0].order(setup[2].id, SkirmishUnit.Order.HOLD)  # the enemy holds its ground
	var log := []
	for _i in range(600):
		log.append_array(setup[0].step())

	var regrouped: Array = log.filter(func(e): return e["type"] == "regrouping")
	var withdrew: Array = log.filter(func(e): return e["type"] == "withdrawing")
	assert_bool(regrouped.is_empty()).is_false()
	var safe_ticks := roundi(FormationRout.RALLY_SECONDS / 0.1)
	assert_int(regrouped[0]["tick"] - withdrew[0]["tick"]).is_greater_equal(safe_ticks)
	assert_bool(me.withdraw.is_empty()).is_true()
	assert_bool(log.any(func(e): return e["type"] == "returned" and e["squad"] == me.id)).is_true()


func test_a_ragged_retreat_fans_out_wider_than_a_drilled_one() -> void:
	var drilled := _fight_then_retreat(60)
	var ragged := _fight_then_retreat(0)
	for _i in range(30):
		drilled[0].step()
		ragged[0].step()

	assert_float(_spread_y(ragged[1])).is_greater(_spread_y(drilled[1]) + 1.0)


func test_a_rout_with_no_friend_in_its_way_fans_out_from_its_route() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	sim.fight_seed = 5
	var mine := sim.spawn_squad(4, _row(_def(30), 4), "player", true)
	mine.front_distance = 30.0 / 64.0
	sim.step()
	var start := _spread_y(mine)
	mine.morale = 0

	for _i in range(40):
		sim.step()

	assert_int(mine.state).is_equal(SkirmishSquad.State.ROUTING)
	var ys: Array = mine.living().map(func(u): return FormationRout.where(mine, u.id).y)
	assert_float(ys.max() - ys.min()).is_greater(start + 2.0)


func test_withdrawals_replay_the_same() -> void:
	var logs := []
	for _r in range(2):
		var setup := _fight_then_retreat(10)
		var log := []
		for _i in range(200):
			log.append_array(setup[0].step())
		logs.append(log)

	assert_array(logs[1]).is_equal(logs[0])

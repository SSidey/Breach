extends GdUnitTestSuite
## FormationRecovery and FormationStrays, per Decisions 121, 125 and 126: wounds lower a
## unit's condition; a poor condition drains HP, standing or downed; a downed unit comes to
## at 1 HP after a seeded while, rejoining its formation if it stands within sight, and
## otherwise makes for home alone; regeneration mends up to its limit, times condition.

const FormationRecovery = preload("res://sim/skirmish/formation/formation_recovery.gd")
const FormationStrays = preload("res://sim/skirmish/formation/formation_strays.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")


func _unit(unit_id: int, at: Vector2) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = unit_id
	unit.faction_id = "player"
	unit.hp = 10
	unit.max_hp = 10
	unit.position = at
	unit.attributes = {"constitution": 10}
	return unit


func _squad(members: Array) -> SkirmishSquad:
	var typed: Array[SkirmishUnit] = []
	typed.assign(members)
	return SkirmishSquad.new(1, "player", 1, 0.0, members.size(), typed)


func _downed(unit: SkirmishUnit) -> SkirmishUnit:
	unit.hp = 0
	unit.state = SkirmishUnit.State.DOWNED
	unit.wounded = 1
	return unit


func _run(squads: Array, seconds: float, events: Array = []) -> Array:
	var strays := []
	for tick in range(roundi(seconds / 0.1)):
		strays.append_array(FormationRecovery.step(squads, 0.1, tick, 3, events))
	return strays


func test_each_wound_lowers_its_condition_past_those_it_is_hardened_to() -> void:
	var step := BattleTuning.current().wounds_condition
	var unit := _unit(1, Vector2.ZERO)
	unit.wounded = 1
	var hardened := _unit(2, Vector2.ZERO)
	hardened.wounded = 1
	hardened.traits = {"hardened": 1}

	assert_float(FormationRecovery.condition_of(unit)).is_equal_approx(1.0 - step, 0.0001)
	assert_float(FormationRecovery.condition_of(hardened)).is_equal(1.0)


func test_a_poor_condition_drains_it_to_death() -> void:
	var dying := _downed(_unit(1, Vector2.ZERO))
	dying.wounded = 3  # condition 0 with the usual tuning
	var events := []
	_run([_squad([dying])], 15.0, events)

	assert_int(dying.state).is_equal(SkirmishUnit.State.DEAD)
	assert_bool(events.any(func(e): return e["type"] == "died_of_wounds")).is_true()


func test_downed_it_comes_to_and_rejoins_its_formation_in_sight() -> void:
	var friend := _unit(2, Vector2(3, 0))
	var downed := _downed(_unit(1, Vector2.ZERO))
	var events := []
	var strays := _run([_squad([friend, downed])], 60.0, events)

	assert_bool(downed.is_alive()).is_true()
	assert_int(downed.hp).is_equal(1)
	assert_int(downed.rank).is_equal(1)  # at the back
	assert_array(strays).is_empty()
	assert_bool(events.any(func(e): return e["type"] == "came_to")).is_true()


func test_with_no_formation_in_sight_it_makes_for_home_alone() -> void:
	var downed := _downed(_unit(1, Vector2.ZERO))
	var strays := _run([_squad([downed])], 60.0)

	assert_int(strays.size()).is_equal(1)
	assert_object(strays[0][0]).is_same(downed)


func test_a_lone_unit_flees_home_and_returns_to_the_reserve() -> void:
	var sim := FormationSimulation.new(1.0, 0.1)
	var grem := UnitDef.new()
	grem.hp = 10
	grem.speed = 1.0
	grem.items = [WeaponDef.innate_weapon(1)]
	var squad := sim.spawn_squad(1, [[grem, Vector2i.ZERO]], "player", true)
	squad.front_distance = 0.5
	sim.step()
	var unit: SkirmishUnit = squad.units[0]
	_downed(unit)
	unit.wake_left = 0.05
	var events := []
	for _i in range(200):
		events.append_array(sim.step())

	assert_bool(events.any(func(e): return e["type"] == "came_to" and e.get("alone"))).is_true()
	assert_bool(events.any(func(e): return e["type"] == "fled_home")).is_true()


func test_regeneration_mends_to_its_max_and_no_further_than_its_limit() -> void:
	var troll := _unit(1, Vector2.ZERO)
	troll.hp = 2
	troll.regeneration = 2.0
	troll.regeneration_left = 5.0
	var squads := [_squad([troll])]
	_run(squads, 3.0)

	assert_int(troll.hp).is_equal(7)  # 5 regained: its limit until it rests
	troll.regeneration_left = 100.0
	_run(squads, 7.0)
	assert_int(troll.hp).is_equal(10)  # never past its max


func test_a_blow_of_a_type_it_fears_stops_its_regeneration_a_while() -> void:
	var troll := _unit(1, Vector2.ZERO)
	troll.hp = 2
	troll.regeneration = 10.0
	troll.regeneration_left = 100.0
	troll.regeneration_stops = ["fire"]
	FormationRecovery.scorch(troll, [[3.0, "slashing", false]], 3)
	assert_float(troll.regeneration_halt).is_equal(0.0)
	FormationRecovery.scorch(troll, [[3.0, "fire", true]], 3)
	_run([_squad([troll])], 1.0)

	assert_int(troll.hp).is_equal(2)


func test_a_downed_regenerator_mends_only_with_the_trait() -> void:
	var plain := _downed(_unit(1, Vector2.ZERO))
	var troll := _downed(_unit(2, Vector2(1, 0)))
	for unit in [plain, troll]:
		unit.regeneration = 10.0
		unit.regeneration_left = 100.0
	troll.traits = {"regenerates_downed": 1}
	_run([_squad([plain, troll])], 0.5)

	assert_int(plain.hp).is_equal(0)
	assert_int(troll.hp).is_greater(0)

extends GdUnitTestSuite
## Ranged units, per Decision 46: a spitter strikes the nearest enemy within its range
## (in ranks), from anywhere in its squad, moving or fighting, with no flank bonus; in
## the front rank of an engaged squad it fights as melee.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")

const ROUTE := 9.0
const TICK := 0.1


## A melee unit striking for `dmg`, or - with a range - a spitter: spit `dmg` acid at
## that range, and a claw 1 + bite 1 for melee.
func _def(hp: int, dmg: int, speed: float, attack_range: int = 0) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = speed
	if attack_range > 0:
		unit_def.preferred_position = UnitDef.Position.BACK
		unit_def.items = [
			_weapon("spit", dmg, "acid", attack_range),
			_weapon("claw", 1, "slashing", 0),
			_weapon("bite", 1, "piercing", 0)
		]
	return unit_def


func _weapon(weapon_name: String, damage: int, damage_type: String, attack_range: int) -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.item_name = weapon_name
	weapon.damage = damage
	weapon.damage_type = damage_type
	weapon.attack_range = attack_range
	return weapon


func _run(sim: FormationSimulation, done: Callable, limit: int = 4000) -> Array:
	var log := []
	for i in range(limit):
		log.append_array(sim.step())
		if done.call(log):
			break
	return log


func _of(events: Array, kind: String) -> Array:
	return events.filter(func(e): return e["type"] == kind)


## A grem in front and a spitter two ranks behind it, against one durable militia.
func _grem_and_spitter(spitter_range: int) -> Array:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var placements := [
		[_def(400, 1, 1.0), Vector2i(0, 0)], [_def(400, 4, 1.0, spitter_range), Vector2i(2, 0)]
	]
	var mine := sim.spawn_squad(1, placements, "player", true)
	var theirs := sim.spawn_squad(1, [[_def(400, 0, 0.8), Vector2i(0, 0)]], "the_kingdom", false)
	return [sim, mine, theirs]


func test_a_spitter_behind_the_front_strikes_the_enemy_front() -> void:
	var setup := _grem_and_spitter(5)
	var sim: FormationSimulation = setup[0]
	var mine: SkirmishSquad = setup[1]
	var theirs: SkirmishSquad = setup[2]
	_run(sim, func(_log): return mine.state == SkirmishSquad.State.FIGHTING)

	var log := _run(sim, func(_log): return false, 20)

	var spits := _of(log, "spat")
	assert_bool(spits.is_empty()).is_false()
	assert_int(spits[0]["unit"]).is_equal(mine.units[1].id)
	assert_int(spits[0]["target"]).is_equal(theirs.units[0].id)
	assert_int(spits[0]["dmg"]).is_equal(4)  # no flank bonus at range
	assert_str(spits[0]["damage_type"]).is_equal("acid")


func test_a_spitter_out_of_range_holds_its_fire() -> void:
	var setup := _grem_and_spitter(1)  # 0.3 cells: short of the enemy behind the front
	var sim: FormationSimulation = setup[0]
	var mine: SkirmishSquad = setup[1]
	_run(sim, func(_log): return mine.state == SkirmishSquad.State.FIGHTING)

	var log := _run(sim, func(_log): return false, 20)

	assert_array(_of(log, "spat")).is_empty()


func test_a_spitter_strikes_before_the_lines_meet() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var spitter := sim.spawn_squad(1, [[_def(12, 4, 1.0, 5), Vector2i(0, 0)]], "player", true)
	var theirs := sim.spawn_squad(1, [[_def(400, 0, 0.8), Vector2i(0, 0)]], "the_kingdom", false)

	var log := _run(sim, func(events): return not _of(events, "spat").is_empty())

	var gap := absf(theirs.front_distance - spitter.front_distance)
	assert_float(gap).is_less_equal(5 * SkirmishSquad.RANK_DEPTH + 0.0001)
	assert_float(gap).is_greater(FormationSimulation.MELEE_REACH)
	assert_array(_of(log, "engaged")).is_empty()


func test_a_front_rank_spitter_in_a_fight_strikes_with_its_melee_weapons() -> void:
	var sim := FormationSimulation.new(ROUTE, TICK)
	var spitter := sim.spawn_squad(1, [[_def(400, 4, 1.0, 5), Vector2i(0, 0)]], "player", true)
	sim.spawn_squad(1, [[_def(400, 0, 0.8), Vector2i(0, 0)]], "the_kingdom", false)
	_run(sim, func(_log): return spitter.state == SkirmishSquad.State.FIGHTING)

	var log := _run(sim, func(_log): return false, 20)

	assert_array(_of(log, "spat")).is_empty()
	var own_hits := _of(log, "hit").filter(func(e): return e["unit"] == spitter.units[0].id)
	assert_bool(own_hits.is_empty()).is_false()
	assert_int(own_hits[0]["dmg"]).is_equal(2)  # its claw and bite, not its spit

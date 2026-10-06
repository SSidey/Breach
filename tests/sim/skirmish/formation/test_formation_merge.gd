extends GdUnitTestSuite
## Auto merge, per Decision 51 and specs/22-formation-feel-test.md (round 6): with it on, a
## wave that catches up with a friendly squad that isn't fighting merges into it as rear
## ranks; with it off, it queues behind. A retreating squad is never merged into.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const ROUTE := 9.0
const TICK := 0.1


func _grem() -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 400
	unit_def.items = [WeaponDef.innate_weapon(1)]
	unit_def.speed = 1.0
	return unit_def


func _line(count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([_grem(), Vector2i(0, column)])
	return placements


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for i in range(ticks):
		log.append_array(sim.step())
	return log


func _players(sim: FormationSimulation) -> Array:
	return sim.squads().filter(func(s): return s.faction_id == "player")


## A grem line holding a little way out, and a second wave sent after it.
func _holding_and_following(
	merges: bool, leader_order: int = SkirmishUnit.Order.HOLD, lead_ticks: int = 10
) -> Array:
	var sim := FormationSimulation.new(ROUTE, TICK)
	sim.combat_width = 5
	var leader := sim.spawn_squad(2, _line(2), "player", true)
	_run(sim, lead_ticks)
	sim.order(leader.id, leader_order)
	var follower := sim.spawn_squad(2, _line(2), "player", true)
	follower.merges = merges
	return [sim, leader, follower]


func test_auto_merge_joins_a_wave_on_the_march() -> void:
	var setup := _holding_and_following(true)
	var sim: FormationSimulation = setup[0]
	var leader: SkirmishSquad = setup[1]

	var log := _run(sim, 100)

	assert_int(_players(sim).size()).is_equal(1)
	assert_int(leader.living().size()).is_equal(4)
	assert_int(log.filter(func(e): return e["type"] == "merged").size()).is_equal(1)


func test_without_auto_merge_the_wave_queues_behind() -> void:
	var setup := _holding_and_following(false)
	var sim: FormationSimulation = setup[0]
	var leader: SkirmishSquad = setup[1]
	var follower: SkirmishSquad = setup[2]

	_run(sim, 100)

	assert_int(_players(sim).size()).is_equal(2)
	assert_float(follower.front_distance).is_less(leader.front_distance)


func test_a_retreating_squad_is_never_merged_into() -> void:
	var setup := _holding_and_following(true, SkirmishUnit.Order.RETREAT, 40)
	var sim: FormationSimulation = setup[0]

	_run(sim, 30)  # they pass before the retreating squad gets home

	assert_int(_players(sim).size()).is_equal(2)


func test_merged_units_spread_once_the_squad_fights() -> void:
	var setup := _holding_and_following(true)
	var sim: FormationSimulation = setup[0]
	var leader: SkirmishSquad = setup[1]
	_run(sim, 100)
	sim.spawn_squad(3, _line(3), "the_kingdom", false)
	sim.order(leader.id, SkirmishUnit.Order.ADVANCE)

	for i in range(4000):
		sim.step()
		if leader.state == SkirmishSquad.State.FIGHTING and leader.fighters().size() == 4:
			break

	assert_int(leader.fighters().size()).is_equal(4)

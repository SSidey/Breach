extends GdUnitTestSuite
## Leaderless rally, per Decisions 89 and 98 and spec 27 rounds 5 and 9: routers that run
## into a friendly formation without a leader are caught there, crushing on the way, and
## join its rear after it has been steady a while; a shaken formation holds them until it
## steadies.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")
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


func _line(count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([_def(100, 2), Vector2i(0, column)])
	return placements


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for _i in range(ticks):
		log.append_array(sim.step())
	return log


func _of(log: Array, kind: String) -> Array:
	return log.filter(func(e): return e["type"] == kind)


## The player's squad 30 cells from home fighting a kingdom squad, a leaderless friend
## holding 15 cells from home behind it; it routs, and the enemy holds its ground (so it
## doesn't follow up onto the friend). Returns [sim, routers, friend].
func _rout_past_a_friend(friend_morale: int) -> Array:
	var sim := FormationSimulation.new(2.0, TICK)
	var mine := sim.spawn_squad(4, _line(4), "player", true)
	mine.front_distance = 30.0 / 64.0
	var theirs := sim.spawn_squad(4, _line(4), "the_kingdom", false)
	theirs.front_distance = 32.0 / 64.0
	var friend := sim.spawn_squad(4, _line(4), "player", true)
	friend.front_distance = 15.0 / 64.0
	sim.order(friend.id, SkirmishUnit.Order.HOLD)
	_run(sim, 5)
	friend.morale = friend_morale
	mine.morale = 0
	sim.order(theirs.id, SkirmishUnit.Order.HOLD)
	return [sim, mine, friend]


func test_routers_are_caught_by_a_steady_friend_and_join_it() -> void:
	var setup := _rout_past_a_friend(75)  # the crushes shake it a little; it soon steadies
	var friend: SkirmishSquad = setup[2]

	var caught := _run(setup[0], 25)
	assert_bool(_of(caught, "crushed").is_empty()).is_false()
	assert_int(_of(caught, "rallied").size()).is_equal(0)  # not yet: it takes a while
	var log := _run(
		setup[0], roundi((BattleTuning.current().rout_steady_rally_seconds + 3.0) / TICK)
	)

	var rallied := _of(log, "rallied")
	assert_bool(rallied.is_empty()).is_false()
	assert_int(rallied[0]["into"]).is_equal(friend.id)
	assert_int(friend.living().size()).is_greater(4)
	assert_int(_of(caught + log, "fled_home").size()).is_equal(0)


func test_a_shaken_friend_holds_them_until_it_steadies() -> void:
	var setup := _rout_past_a_friend(30)
	var friend: SkirmishSquad = setup[2]

	var held := _run(setup[0], 80)
	assert_int(_of(held, "fled_home").size()).is_equal(0)
	assert_int(_of(held, "rallied").size()).is_equal(0)  # not while it is shaken
	friend.morale = 60  # it steadies
	var log := _run(
		setup[0], roundi((BattleTuning.current().rout_steady_rally_seconds + 3.0) / TICK)
	)

	assert_int(_of(log, "fled_home").size()).is_equal(0)
	var rallied := _of(log, "rallied")
	assert_bool(rallied.is_empty()).is_false()
	assert_int(rallied[0]["into"]).is_equal(friend.id)

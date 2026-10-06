extends GdUnitTestSuite
## FormationTerrain and pace, per Decision 85 and spec 27 round 4: ground cost, uphill
## slope, liquid in bands of a unit's height, cliffs and deep water impassable, and a squad
## keeping the pace of the worst cell its front rank steps into.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _terrain() -> FormationTerrain:
	return FormationTerrain.new(Vector2i(64, 32))


func _def() -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 20
	unit_def.items = [WeaponDef.innate_weapon(1)]
	unit_def.speed = 1.0
	return unit_def


func _line(count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([_def(), Vector2i(0, column)])
	return placements


func test_open_ground_is_full_pace_and_a_wood_is_half() -> void:
	var ground := _terrain()
	ground.paint(Rect2i(10, 0, 5, 5), {"cost": 0.5})

	assert_float(ground.factor(1.0, Vector2(2.5, 2.5), Vector2(3.5, 2.5))).is_equal(1.0)
	assert_float(ground.factor(1.0, Vector2(9.5, 2.5), Vector2(10.5, 2.5))).is_equal(0.5)
	assert_float(ground.factor(1.0, Vector2(-5, -5), Vector2(-4, -5))).is_equal(1.0)


func test_uphill_is_slower_and_downhill_no_faster() -> void:
	var ground := _terrain()
	ground.paint(Rect2i(10, 0, 1, 5), {"height": 2})

	assert_float(ground.factor(1.0, Vector2(9.5, 1), Vector2(10.5, 1))).is_equal_approx(0.8, 0.0001)
	assert_float(ground.factor(1.0, Vector2(10.5, 1), Vector2(11.5, 1))).is_equal(1.0)


func test_a_rise_of_more_than_a_cell_is_a_cliff() -> void:
	var ground := _terrain()
	ground.paint(Rect2i(10, 0, 1, 5), {"height": 5})

	assert_float(ground.factor(1.0, Vector2(9.5, 1), Vector2(10.5, 1))).is_equal(0.0)


func test_water_slows_by_depth_against_height() -> void:
	var ground := _terrain()
	ground.paint(Rect2i(10, 0, 1, 1), {"depth": 0.1})
	ground.paint(Rect2i(11, 0, 1, 1), {"depth": 0.3})
	ground.paint(Rect2i(12, 0, 1, 1), {"depth": 0.7})
	ground.paint(Rect2i(13, 0, 1, 1), {"depth": 1.2})
	var at := func(x: int, height: float):
		return ground.factor(height, Vector2(x - 0.5, 0.5), Vector2(x + 0.5, 0.5))
		return ground.factor(height, Vector2(x - 0.5, 0.5), Vector2(x + 0.5, 0.5))

	assert_float(at.call(10, 1.0)).is_equal(1.0)
	assert_float(at.call(11, 1.0)).is_equal_approx(BattleTuning.current().ground_wading, 0.0001)
	assert_float(at.call(12, 1.0)).is_equal_approx(
		BattleTuning.current().ground_slow_wading, 0.0001
	)
	assert_float(at.call(13, 1.0)).is_equal(0.0)
	# A brute, twice as tall, wades it.
	assert_float(at.call(13, 2.0)).is_equal_approx(
		BattleTuning.current().ground_slow_wading, 0.0001
	)


func test_a_squad_half_in_a_wood_slows_as_a_whole() -> void:
	var sim := FormationSimulation.new(1.0, TICK)
	sim.terrain = _terrain()
	sim.terrain.paint(Rect2i(20, 10, 44, 2), {"cost": 0.5})  # under the squad's south half
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 10), Vector2(64, 10)]))
	var squad := sim.spawn_squad(4, _line(4), "player", true, 0, route)

	for _i in range(40):
		sim.step()  # 25 ticks to the wood's edge at x 20, then 15 at half pace: x 26
	var x := squad.position.x
	assert_float(x).is_less(28.0)
	assert_float(x).is_greater(22.0)


func test_deep_water_across_the_route_halts_the_squad() -> void:
	var sim := FormationSimulation.new(1.0, TICK)
	sim.terrain = _terrain()
	sim.terrain.paint(Rect2i(20, 0, 2, 32), {"depth": 2.0})
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 10), Vector2(64, 10)]))
	var squad := sim.spawn_squad(2, _line(2), "player", true, 0, route)

	var log := []
	for _i in range(80):
		log.append_array(sim.step())

	assert_float(squad.position.x).is_less_equal(20.0)
	assert_int(log.filter(func(e): return e["type"] == "blocked").size()).is_equal(1)


func test_without_terrain_nothing_changes() -> void:
	var sim := FormationSimulation.new(1.0, TICK)
	var squad := sim.spawn_squad(2, _line(2), "player", true)

	for _i in range(10):
		sim.step()

	assert_float(squad.position.x).is_equal_approx(8.0, 0.0001)

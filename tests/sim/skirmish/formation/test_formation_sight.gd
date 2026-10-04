extends GdUnitTestSuite
## FormationSight, per Decision 87: a formation detects another squad when any of that
## squad's units is within the best detection range among its own units.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _def(detection: float = 40.0) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 10
	unit_def.dmg = 1
	unit_def.speed = 1.0
	unit_def.detection_range = detection
	return unit_def


func _at(sim: FormationSimulation, point: Vector2, placements: Array, faction: String = "player"):
	var route := FormationRoute.new(PackedVector2Array([point, point + Vector2(0, 100)]))
	return sim.spawn_squad(placements.size(), placements, faction, true, 0, route)


func test_a_squad_within_range_is_detected_and_one_beyond_it_is_not() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	var watcher = _at(sim, Vector2(0, 0), [[_def(), Vector2i(0, 0)]])
	var near = _at(sim, Vector2(30, 0), [[_def(), Vector2i(0, 0)]], "the_kingdom")
	var far = _at(sim, Vector2(60, 0), [[_def(), Vector2i(0, 0)]], "the_kingdom")

	assert_bool(FormationSight.detects(watcher, near)).is_true()
	assert_bool(FormationSight.detects(watcher, far)).is_false()


func test_a_formation_sees_with_its_best_detector() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	var watcher = _at(
		sim, Vector2(0, 0), [[_def(10.0), Vector2i(0, 0)], [_def(80.0), Vector2i(0, 1)]]
	)
	var far = _at(sim, Vector2(60, 0), [[_def(), Vector2i(0, 0)]], "the_kingdom")

	assert_bool(FormationSight.detects(watcher, far)).is_true()


func test_a_detection_range_comes_from_the_unit_definition() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	var squad = _at(sim, Vector2(0, 0), [[_def(25.0), Vector2i(0, 0)]])

	assert_float(squad.units[0].detection).is_equal(25.0)

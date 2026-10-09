extends GdUnitTestSuite
## Climbing on stamina (spec 30): there is no breather on a climb face - stamina recovers
## only where a unit can stand, a passable cell whose slope across it is under the climb
## threshold. A pathfinder plans only climbs whose stretches between standable cells fit
## its unit's stamina ("they should only make it so far"). A unit at 0 stamina on a face
## falls to the foot, hurt by the drop and more the heavier it is.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const ClimbStamina = preload("res://sim/skirmish/formation/climb_stamina.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


## A staircase of cliffs, a cell a step, up from x 10 to a plateau at x 14-19 on rows 0-9;
## down its east side a cliff to a 2-cell ledge at x 20-21, and another to the ground; a
## wall too high to climb across rows 10-11.
func _stairs(mirrored: bool = false) -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(30, 24))
	var columns := {10: 8, 11: 16, 12: 24, 13: 32, 14: 40, 15: 40, 16: 40, 17: 40}
	columns.merge({18: 40, 19: 40, 20: 16, 21: 16})
	for x in columns:
		ground.paint(Rect2i(29 - x if mirrored else x, 0, 1, 10), {"height": columns[x]})
	ground.paint(Rect2i(0, 10, 30, 2), {"height": 80, "climb": 9})
	return ground


func _climber(stamina: float) -> TerrainWalker:
	var walker := TerrainWalker.new(1.0, 0, 1)
	walker.stamina = stamina
	return walker


func test_a_unit_stands_where_the_slope_across_the_cell_is_under_the_threshold() -> void:
	var ground := _stairs()
	var grem := TerrainWalker.new(1.0)

	assert_bool(ClimbStamina.standable(ground, grem, Vector2(9.5, 5.5))).is_true()  # the foot
	assert_bool(ClimbStamina.standable(ground, grem, Vector2(11.5, 5.5))).is_false()  # a face
	assert_bool(ClimbStamina.standable(ground, grem, Vector2(14.5, 5.5))).is_true()  # the top
	assert_bool(ClimbStamina.standable(ground, grem, Vector2(20.5, 5.5))).is_true()  # a ledge
	assert_bool(ClimbStamina.standable(ground, grem, Vector2(13.5, 5.5))).is_false()
	var water := FormationTerrain.new(Vector2i(8, 8))
	water.paint(Rect2i(2, 2, 3, 3), {"depth": 1.5})
	assert_bool(ClimbStamina.standable(water, grem, Vector2(3.5, 3.5))).is_false()
	assert_bool(ClimbStamina.standable(water, grem, Vector2(0.5, 0.5))).is_true()


func test_standing_is_the_same_on_the_ground_mirrored() -> void:
	var ground := _stairs()
	var mirrored := _stairs(true)
	var grem := TerrainWalker.new(1.0)
	for x in 30:
		var here := ClimbStamina.standable(ground, grem, Vector2(x + 0.5, 5.5))
		var there := ClimbStamina.standable(mirrored, grem, Vector2(29.5 - x, 5.5))
		assert_bool(there).is_equal(here)


func test_a_plan_climbs_only_what_its_stamina_lasts_between_ledges() -> void:
	var ground := _stairs()
	var start := Vector2(8.5, 5.5)
	var goal := Vector2(16.5, 5.5)
	# each step up: 1 cell at the climb pace (0.25), climber 1 against difficulty 1 - 4 s
	# at 4 stamina a second; the stretch from the foot to the top is 5 steps, 80 stamina
	var fresh := TerrainPaths.cells(ground, _climber(100.0), start, goal)
	var tired := TerrainPaths.cells(ground, _climber(60.0), start, goal)

	assert_bool(fresh.has(Vector2i(12, 5))).is_true()
	assert_array(tired).is_empty()  # no way up it can last, and no way round
	assert_float(ClimbStamina.hardest(ground, _climber(100.0), fresh)).is_equal_approx(80.0, 0.01)
	var east := TerrainPaths.cells(ground, _climber(20.0), Vector2(25.5, 5.5), goal)
	assert_bool(east.has(Vector2i(20, 5)) or east.has(Vector2i(21, 5))).is_true()  # by the ledge
	assert_float(ClimbStamina.hardest(ground, _climber(20.0), east)).is_equal_approx(16.0, 0.01)


func test_a_spent_unit_on_a_face_falls_and_one_on_a_ledge_does_not() -> void:
	var ground := _stairs()
	var grem := TerrainWalker.new(1.0)

	assert_bool(ClimbStamina.falls(0.0, ground, grem, Vector2(12.5, 5.5))).is_true()
	assert_bool(ClimbStamina.falls(5.0, ground, grem, Vector2(12.5, 5.5))).is_false()
	assert_bool(ClimbStamina.falls(0.0, ground, grem, Vector2(14.5, 5.5))).is_false()


func test_a_fall_hurts_by_the_drop_and_more_the_heavier_the_unit() -> void:
	var ground := _stairs()
	var tuning := BattleTuning.current()
	var foot := Vector2(9.5, 5.5)
	var drop := ClimbStamina.drop(ground, foot, Vector2(12.5, 5.5))  # 24 quarters up
	var grem := UnitDef.new()
	var brute := UnitDef.new()
	brute.footprint_width = 2
	brute.footprint_depth = 2

	assert_float(drop).is_equal_approx(6.0, 0.0001)
	assert_float(ClimbStamina.fall_damage(drop, grem)).is_equal_approx(
		6.0 * tuning.fall_damage_per_cell, 0.0001
	)
	assert_float(ClimbStamina.fall_damage(drop * 2.0, grem)).is_equal_approx(
		2.0 * ClimbStamina.fall_damage(drop, grem), 0.0001
	)
	assert_float(ClimbStamina.fall_damage(drop, brute)).is_greater(
		ClimbStamina.fall_damage(drop, grem)
	)

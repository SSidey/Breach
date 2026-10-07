extends GdUnitTestSuite
## How a unit crosses terrain, per spec 30 round 3 and Decisions 64 and 85: everyone swims
## water at least its height deep at a swim pace a "swimmer" raises; a unit too loaded,
## or one that "sinks", can't; a cliff is climbed by Decision 64's pair rule, a climber
## against the face's demand - full pace meeting it, half one short, not at all further.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const ItemDef = preload("res://content/definitions/item_def.gd")


func _def(carried: float = 0.0, traits: Dictionary = {}) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.speed = 1.0
	unit_def.traits = traits
	if carried > 0.0:
		var pack := ItemDef.new()
		pack.item_name = "pack"
		pack.weight = carried
		unit_def.items = [pack]
	return unit_def


func test_everyone_swims_at_the_swim_pace_and_a_swimmer_faster() -> void:
	var tuning := BattleTuning.current()

	assert_float(TerrainWalker.of(_def()).swim).is_equal_approx(tuning.ground_swim_pace, 0.0001)
	assert_float(TerrainWalker.of(_def(0.0, {"swimmer": 1})).swim).is_equal_approx(
		tuning.ground_swim_pace + tuning.ground_swimmer_pace, 0.0001
	)
	assert_float(TerrainWalker.of(_def(0.0, {"swimmer": 9})).swim).is_equal(1.0)


func test_a_unit_that_sinks_or_is_loaded_past_the_threshold_cannot_swim() -> void:
	var tuning := BattleTuning.current()
	var limit := UnitDef.AVERAGE * tuning.load_per_strength
	var easy := limit * tuning.load_easy
	var threshold := easy + (limit - easy) * tuning.ground_sink_share

	assert_float(TerrainWalker.of(_def(0.0, {"sinks": 1})).swim).is_equal(0.0)
	assert_float(TerrainWalker.of(_def(threshold)).swim).is_greater(0.0)
	assert_float(TerrainWalker.of(_def(threshold + 0.5)).swim).is_equal(0.0)


func test_deep_water_is_crossed_at_the_swim_pace_of_the_ground() -> void:
	var ground := FormationTerrain.new(Vector2i(16, 8))
	ground.paint(Rect2i(5, 0, 1, 8), {"depth": 1.2, "cost": 0.5})
	var swimmer := TerrainWalker.new(1.0, 0.25)

	assert_float(ground.crossing(swimmer, Vector2(4.5, 2.5), Vector2(5.5, 2.5))).is_equal(0.125)
	(
		assert_float(ground.crossing(TerrainWalker.new(1.0), Vector2(4.5, 2.5), Vector2(5.5, 2.5)))
		. is_equal(0.0)
	)
	assert_float(ground.factor(1.0, Vector2(4.5, 2.5), Vector2(5.5, 2.5))).is_equal(0.0)


func test_a_cliff_meets_the_climber_by_the_pair_rule() -> void:
	var tuning := BattleTuning.current()
	var ground := FormationTerrain.new(Vector2i(16, 8))
	ground.paint(Rect2i(8, 0, 8, 8), {"height": 8, "climb": 2})
	var below := Vector2(7.5, 2.5)
	var face := Vector2(8.5, 2.5)

	assert_float(ground.crossing(TerrainWalker.new(1.0, 0.0, 0), below, face)).is_equal(0.0)
	assert_float(ground.crossing(TerrainWalker.new(1.0, 0.0, 1), below, face)).is_equal_approx(
		tuning.ground_climb_pace * 0.5, 0.0001
	)
	assert_float(ground.crossing(TerrainWalker.new(1.0, 0.0, 2), below, face)).is_equal_approx(
		tuning.ground_climb_pace, 0.0001
	)
	assert_float(ground.crossing(TerrainWalker.new(1.0, 0.0, 0), face, below)).is_equal(1.0)


func test_an_unpainted_face_demands_the_tuned_difficulty() -> void:
	var ground := FormationTerrain.new(Vector2i(16, 8))
	ground.paint(Rect2i(8, 0, 8, 8), {"height": 8})
	var demand := BattleTuning.current().ground_climb_demand
	var level := TerrainWalker.new(1.0, 0.0, demand)

	assert_float(ground.crossing(level, Vector2(7.5, 2.5), Vector2(8.5, 2.5))).is_greater(0.0)
	assert_int(TerrainWalker.of(_def(0.0, {"climber": 3})).climber).is_equal(3)

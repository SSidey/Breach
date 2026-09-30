extends GdUnitTestSuite
## WaveTemplate, per Decision 42 and specs/22-formation-feel-test.md (round 2): a lane's
## wave, painted unit by unit into a grid - the painted units are the shape.

const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _def(depth: int = 1, width: int = 1) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 10
	unit_def.footprint_depth = depth
	unit_def.footprint_width = width
	return unit_def


func _places(template: WaveTemplate) -> Array:
	return template.ordered().map(func(p): return p[1])


func test_painting_places_units_and_a_brute_covers_two_by_two() -> void:
	var grem := _def()
	var brute := _def(2, 2)
	var template := WaveTemplate.new(5, 8)

	assert_bool(template.paint(brute, Vector2i(0, 1))).is_true()
	assert_bool(template.paint(grem, Vector2i(2, 1))).is_true()
	assert_bool(template.paint(grem, Vector2i(2, 2))).is_true()

	assert_array(_places(template)).is_equal([Vector2i(0, 1), Vector2i(2, 1), Vector2i(2, 2)])


func test_painting_outside_the_grid_or_past_the_slot_limit_is_refused() -> void:
	var template := WaveTemplate.new(3, 2)

	assert_bool(template.paint(_def(), Vector2i(0, 3))).is_false()
	assert_bool(template.paint(_def(), Vector2i(WaveTemplate.MAX_RANKS, 0))).is_false()
	assert_bool(template.paint(_def(2, 2), Vector2i(0, 2))).is_false()  # overhangs the width
	assert_bool(template.paint(_def(), Vector2i(0, 0))).is_true()
	assert_bool(template.paint(_def(), Vector2i(0, 1))).is_true()
	assert_bool(template.paint(_def(), Vector2i(0, 2))).is_false()  # 2 slots used already


func test_painting_over_units_replaces_them() -> void:
	var grem := _def()
	var brute := _def(2, 2)
	var template := WaveTemplate.new(4, 8)
	for column in range(4):
		template.paint(grem, Vector2i(0, column))

	assert_bool(template.paint(brute, Vector2i(0, 1))).is_true()

	var kinds := template.ordered().map(func(p): return p[0] == brute)
	assert_array(_places(template)).is_equal([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 3)])
	assert_array(kinds).is_equal([false, true, false])


func test_erasing_removes_the_unit_covering_a_cell() -> void:
	var template := WaveTemplate.new(4, 8)
	template.paint(_def(2, 2), Vector2i(0, 0))

	assert_bool(template.erase(Vector2i(1, 1))).is_true()
	assert_array(template.ordered()).is_empty()
	assert_bool(template.erase(Vector2i(3, 3))).is_false()


func test_trimming_removes_from_the_back_and_returns_what_was_removed() -> void:
	var grem := _def()
	var template := WaveTemplate.default_line(grem, 6, 3)  # two ranks of three

	var removed := template.trim_to(4)

	assert_array(removed.map(func(p): return p[1])).is_equal([Vector2i(1, 2), Vector2i(1, 1)])
	assert_int(template.ordered().size()).is_equal(4)


func test_layout_normalises_columns_to_start_at_zero() -> void:
	var template := WaveTemplate.new(8, 8)
	template.paint(_def(), Vector2i(0, 3))
	template.paint(_def(), Vector2i(0, 5))

	var layout := template.layout()

	assert_int(layout[0]).is_equal(3)  # columns 3..5
	assert_array(layout[1].map(func(p): return p[1])).is_equal([Vector2i(0, 0), Vector2i(0, 2)])


func test_the_default_line_is_as_wide_as_allowed_then_deeper() -> void:
	var template := WaveTemplate.default_line(_def(), 7, 5)

	assert_array(_places(template)).is_equal(
		[
			Vector2i(0, 0),
			Vector2i(0, 1),
			Vector2i(0, 2),
			Vector2i(0, 3),
			Vector2i(0, 4),
			Vector2i(1, 0),
			Vector2i(1, 1)
		]
	)


func test_a_copy_is_independent() -> void:
	var template := WaveTemplate.default_line(_def(), 2, 4)
	var edited := template.copy()

	edited.erase(Vector2i(0, 0))

	assert_int(template.ordered().size()).is_equal(2)
	assert_int(edited.ordered().size()).is_equal(1)

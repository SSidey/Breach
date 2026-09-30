extends GdUnitTestSuite
## SkirmishFormation, per specs/22-formation-feel-test.md: a lane's width x ranks grid of
## usable slots, filled front-first by footprint (depth x width, Decision 40).

const SkirmishFormation = preload("res://sim/skirmish/formation/skirmish_formation.gd")


func test_ranks_come_from_slots_and_width_and_the_last_rank_may_be_partial() -> void:
	var formation := SkirmishFormation.new(3, 7)

	assert_int(formation.ranks).is_equal(3)
	assert_bool(formation.is_usable(Vector2i(2, 0))).is_true()
	assert_bool(formation.is_usable(Vector2i(2, 1))).is_false()


func test_units_fill_the_front_rank_first_left_to_right() -> void:
	var formation := SkirmishFormation.new(3, 6)

	assert_object(formation.place(1, 1)).is_equal(Vector2i(0, 0))
	assert_object(formation.place(1, 1)).is_equal(Vector2i(0, 1))
	assert_object(formation.place(1, 1)).is_equal(Vector2i(0, 2))
	assert_object(formation.place(1, 1)).is_equal(Vector2i(1, 0))


func test_a_brute_takes_two_ranks_and_two_columns_and_can_prefer_the_centre() -> void:
	var formation := SkirmishFormation.new(4, 8)

	assert_object(formation.place(2, 2, true)).is_equal(Vector2i(0, 1))
	var grems := []
	for i in range(4):
		grems.append(formation.place(1, 1))

	assert_array(grems).is_equal([Vector2i(0, 0), Vector2i(0, 3), Vector2i(1, 0), Vector2i(1, 3)])
	assert_bool(formation.can_fit(1, 1)).is_false()
	assert_object(formation.place(1, 1)).is_equal(SkirmishFormation.NO_ROOM)


func test_a_footprint_that_does_not_fit_has_no_room() -> void:
	var formation := SkirmishFormation.new(3, 3)

	assert_bool(formation.can_fit(2, 2)).is_false()
	assert_object(formation.place(2, 2)).is_equal(SkirmishFormation.NO_ROOM)


func test_width_is_capped_by_the_lane_the_global_maximum_and_the_slots() -> void:
	assert_int(SkirmishFormation.clamp_width(10, 5, 8)).is_equal(5)
	assert_int(SkirmishFormation.clamp_width(10, 12, 20)).is_equal(SkirmishFormation.MAX_LANE_WIDTH)
	assert_int(SkirmishFormation.clamp_width(4, 8, 2)).is_equal(2)
	assert_int(SkirmishFormation.clamp_width(0, 8, 8)).is_equal(1)

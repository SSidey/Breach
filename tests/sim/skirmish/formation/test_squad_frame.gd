extends GdUnitTestSuite
## SquadFrame, per Decision 74 (specs/27-formations-in-2d.md): a squad's units placed in
## cells from its front centre and facing, turned rather than mirrored, so a straight
## route reproduces the lane's lateral spans.

const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")


func _unit(rank: int, column: int, depth: int = 1, width: int = 1) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.rank = rank
	unit.column = column
	unit.footprint_depth = depth
	unit.footprint_width = width
	unit.hp = 10
	return unit


func test_facings_turn_clockwise_with_screen_y_down() -> void:
	assert_vector(SquadFrame.forward(SquadFrame.NORTH)).is_equal(Vector2(0, -1))
	assert_vector(SquadFrame.forward(SquadFrame.EAST)).is_equal(Vector2(1, 0))
	assert_vector(SquadFrame.right(SquadFrame.EAST)).is_equal(Vector2(0, 1))
	assert_vector(SquadFrame.right(SquadFrame.WEST)).is_equal(Vector2(0, -1))
	assert_int(SquadFrame.opposite(SquadFrame.NORTH)).is_equal(SquadFrame.SOUTH)
	assert_int(SquadFrame.opposite(SquadFrame.WEST)).is_equal(SquadFrame.EAST)


func test_ranks_lie_behind_the_front_and_columns_to_the_right() -> void:
	# A 4-wide squad facing east with its front centre at (10, 0).
	var front := SquadFrame.unit_rect(Vector2(10, 0), SquadFrame.EAST, 4, 0.0, _unit(0, 0))
	var behind := SquadFrame.unit_rect(Vector2(10, 0), SquadFrame.EAST, 4, 0.0, _unit(1, 3))

	assert_that(front).is_equal(Rect2(9, -2, 1, 1))
	assert_that(behind).is_equal(Rect2(8, 1, 1, 1))


func test_facing_north_turns_the_block_without_mirroring_it() -> void:
	var brute := SquadFrame.unit_rect(Vector2(0, 10), SquadFrame.NORTH, 4, 0.0, _unit(0, 2, 2, 2))

	assert_that(brute).is_equal(Rect2(0, 10, 2, 2))


func test_a_straight_route_reproduces_the_lanes_lateral_spans() -> void:
	for direction in [1, -1]:
		var unit := _unit(1, 2, 1, 2)
		var members: Array[SkirmishUnit] = [unit]
		var squad := SkirmishSquad.new(1, "player", direction, 0.0, 5, members)
		squad.centre_shift = 0.5
		var facing := SquadFrame.EAST if direction > 0 else SquadFrame.WEST
		var rect := SquadFrame.unit_rect(Vector2(20, 0), facing, 5, 0.5, unit)

		assert_vector(SquadFrame.lateral_interval(rect, facing)).is_equal_approx(
			squad.lateral_span(unit), Vector2(0.0001, 0.0001)
		)


func test_the_gap_is_measured_along_the_facing() -> void:
	assert_float(SquadFrame.gap_along(Vector2(2, 5), Vector2(9, 1), SquadFrame.EAST)).is_equal(7.0)
	assert_float(SquadFrame.gap_along(Vector2(2, 5), Vector2(9, 1), SquadFrame.NORTH)).is_equal(4.0)

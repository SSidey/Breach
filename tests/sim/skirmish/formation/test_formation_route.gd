extends GdUnitTestSuite
## FormationRoute, per Decisions 74 and 75 (specs/27-formations-in-2d.md): a route as a
## path of cells, walked by distance, with a heading and the cardinal facing nearest it.

const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")


func _l_route() -> FormationRoute:
	# East 10 cells, then south 6.
	return FormationRoute.new(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 6)]))


func test_a_straight_route_runs_east_from_the_origin() -> void:
	var route := FormationRoute.straight(64.0)

	assert_float(route.length_cells()).is_equal_approx(64.0, 0.0001)
	assert_vector(route.point_at(16.0)).is_equal_approx(Vector2(16, 0), Vector2(0.0001, 0.0001))
	assert_int(route.facing_at(16.0, 1, SquadFrame.NORTH)).is_equal(SquadFrame.EAST)
	assert_int(route.facing_at(16.0, -1, SquadFrame.NORTH)).is_equal(SquadFrame.WEST)


func test_points_follow_each_leg_and_clamp_at_the_ends() -> void:
	var route := _l_route()

	assert_float(route.length_cells()).is_equal_approx(16.0, 0.0001)
	assert_vector(route.point_at(4.0)).is_equal_approx(Vector2(4, 0), Vector2(0.0001, 0.0001))
	assert_vector(route.point_at(13.0)).is_equal_approx(Vector2(10, 3), Vector2(0.0001, 0.0001))
	assert_vector(route.point_at(-5.0)).is_equal(Vector2(0, 0))
	assert_vector(route.point_at(99.0)).is_equal(Vector2(10, 6))


func test_the_heading_turns_at_a_bend() -> void:
	var route := _l_route()

	assert_vector(route.heading_at(9.0)).is_equal_approx(Vector2(1, 0), Vector2(0.0001, 0.0001))
	assert_vector(route.heading_at(10.0)).is_equal_approx(Vector2(0, 1), Vector2(0.0001, 0.0001))
	assert_int(route.facing_at(12.0, 1, SquadFrame.EAST)).is_equal(SquadFrame.SOUTH)
	assert_int(route.facing_at(12.0, -1, SquadFrame.EAST)).is_equal(SquadFrame.NORTH)


func test_a_diagonal_leg_keeps_the_current_facing_on_a_tie() -> void:
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 0), Vector2(5, 5)]))

	assert_int(route.facing_at(1.0, 1, SquadFrame.EAST)).is_equal(SquadFrame.EAST)
	assert_int(route.facing_at(1.0, 1, SquadFrame.SOUTH)).is_equal(SquadFrame.SOUTH)
	var shallow := FormationRoute.new(PackedVector2Array([Vector2(0, 0), Vector2(5, 2)]))
	assert_int(shallow.facing_at(1.0, 1, SquadFrame.SOUTH)).is_equal(SquadFrame.EAST)


func test_the_corridor_is_carried_with_the_route() -> void:
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 0), Vector2(8, 0)]), 4.0)

	assert_float(route.corridor_half_width).is_equal(4.0)

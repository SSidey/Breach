extends GdUnitTestSuite
## SkirmishRoute, per specs/21-realtime-skirmish-feel-test.md: a unit's distance along
## its route (in cells) becomes a point on the route polyline.

const SkirmishRoute = preload("res://presentation/skirmish/skirmish_route.gd")

const CELL := 64.0


func _points() -> PackedVector2Array:
	# Two cells right, then one diagonal step: lengths 1, 1 and sqrt(2) cells.
	return PackedVector2Array(
		[Vector2(32, 32), Vector2(96, 32), Vector2(160, 32), Vector2(224, 96)]
	)


func test_length_is_measured_in_cells() -> void:
	assert_float(SkirmishRoute.length_cells(_points(), CELL)).is_equal_approx(
		2.0 + sqrt(2.0), 0.0001
	)


func test_a_distance_maps_to_a_point_along_the_segments() -> void:
	var points := _points()

	assert_object(SkirmishRoute.point_at(points, 0.0, CELL)).is_equal(Vector2(32, 32))
	assert_object(SkirmishRoute.point_at(points, 0.5, CELL)).is_equal(Vector2(64, 32))
	assert_object(SkirmishRoute.point_at(points, 1.5, CELL)).is_equal(Vector2(128, 32))


func test_a_distance_on_the_diagonal_follows_it() -> void:
	var point := SkirmishRoute.point_at(_points(), 2.0 + sqrt(2.0) / 2.0, CELL)

	assert_float(point.x).is_equal_approx(192.0, 0.01)
	assert_float(point.y).is_equal_approx(64.0, 0.01)


func test_distances_past_either_end_clamp_to_the_end() -> void:
	var points := _points()

	assert_object(SkirmishRoute.point_at(points, -3.0, CELL)).is_equal(points[0])
	assert_object(SkirmishRoute.point_at(points, 99.0, CELL)).is_equal(points[-1])


func test_a_single_point_route_is_that_point() -> void:
	var single := PackedVector2Array([Vector2(10, 20)])

	assert_object(SkirmishRoute.point_at(single, 1.0, CELL)).is_equal(Vector2(10, 20))
	assert_float(SkirmishRoute.length_cells(single, CELL)).is_equal(0.0)

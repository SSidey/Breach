extends GdUnitTestSuite

const TickInterpolation = preload("res://presentation/tick_interpolation.gd")


func test_interpolates_the_midpoint_at_fifty_percent_elapsed() -> void:
	var result := TickInterpolation.interpolate_position(0.0, 1.0, 0.5)

	assert_float(result).is_equal_approx(0.5, 0.001)


func test_returns_the_previous_position_at_zero_elapsed() -> void:
	var result := TickInterpolation.interpolate_position(0.0, 1.0, 0.0)

	assert_float(result).is_equal_approx(0.0, 0.001)


func test_returns_the_current_position_at_full_elapsed() -> void:
	var result := TickInterpolation.interpolate_position(0.0, 1.0, 1.0)

	assert_float(result).is_equal_approx(1.0, 0.001)


func test_clamps_a_fraction_above_one() -> void:
	var result := TickInterpolation.interpolate_position(0.0, 1.0, 1.5)

	assert_float(result).is_equal_approx(1.0, 0.001)


func test_clamps_a_fraction_below_zero() -> void:
	var result := TickInterpolation.interpolate_position(0.0, 1.0, -0.2)

	assert_float(result).is_equal_approx(0.0, 0.001)


func test_interpolates_correctly_when_moving_backward() -> void:
	# A Hero Party marching from a higher node index toward a lower one.
	var result := TickInterpolation.interpolate_position(3.0, 2.0, 0.5)

	assert_float(result).is_equal_approx(2.5, 0.001)


func test_elapsed_fraction_computes_elapsed_seconds_over_tick_duration() -> void:
	var fraction := TickInterpolation.elapsed_fraction(1.0, 2.0)

	assert_float(fraction).is_equal_approx(0.5, 0.001)


func test_elapsed_fraction_is_zero_when_tick_duration_is_zero() -> void:
	var fraction := TickInterpolation.elapsed_fraction(1.0, 0.0)

	assert_float(fraction).is_equal_approx(0.0, 0.001)

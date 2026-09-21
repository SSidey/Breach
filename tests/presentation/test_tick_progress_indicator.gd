extends GdUnitTestSuite
## TickProgressIndicator's actual rendering has no automated coverage - it needs a
## real render context, per specs/05's own Notes (same honesty as LaneView). These
## tests confirm the script constructs cleanly and that its elapsed-time bookkeeping
## (the one piece not delegated to the already-tested TickInterpolation) behaves per
## specs/05's tick-progress scenario.

const TickProgressIndicator = preload("res://presentation/tick_progress_indicator.gd")
const TickInterpolation = preload("res://presentation/tick_interpolation.gd")


func test_constructs_without_error() -> void:
	var indicator: TickProgressIndicator = auto_free(TickProgressIndicator.new())

	assert_object(indicator).is_not_null()


func test_elapsed_fraction_reflects_progress_toward_the_next_tick() -> void:
	var indicator: TickProgressIndicator = auto_free(TickProgressIndicator.new())
	indicator.tick_duration_seconds = 2.0
	indicator._elapsed_since_last_tick = 1.0

	var fraction := TickInterpolation.elapsed_fraction(
		indicator._elapsed_since_last_tick, indicator.tick_duration_seconds
	)

	assert_float(fraction).is_equal_approx(0.5, 0.001)


func test_tick_advanced_resets_elapsed_time_to_zero() -> void:
	var indicator: TickProgressIndicator = auto_free(TickProgressIndicator.new())
	indicator._elapsed_since_last_tick = 1.5

	indicator._on_tick_advanced(1)

	assert_float(indicator._elapsed_since_last_tick).is_equal_approx(0.0, 0.001)

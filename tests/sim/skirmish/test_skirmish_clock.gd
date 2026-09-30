extends GdUnitTestSuite
## SkirmishClock, per specs/21-realtime-skirmish-feel-test.md: a fixed-step accumulator
## that carries leftover time, so short ticks don't drift.

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")


func _clock() -> SkirmishClock:
	var clock := SkirmishClock.new()
	clock.tick_seconds = 0.25
	return clock


func test_no_tick_is_due_before_the_tick_length() -> void:
	assert_int(_clock().advance(0.2)).is_equal(0)


func test_leftover_time_is_carried_between_frames() -> void:
	var clock := _clock()

	var due := clock.advance(0.3) + clock.advance(0.3)

	assert_int(due).is_equal(2)
	assert_int(clock.tick_number()).is_equal(2)
	assert_float(clock.fraction()).is_equal_approx(0.4, 0.001)


func test_pausing_stops_ticks_and_resuming_continues() -> void:
	var clock := _clock()
	clock.pause()

	assert_int(clock.advance(5.0)).is_equal(0)
	assert_bool(clock.is_paused()).is_true()
	clock.resume()
	assert_int(clock.advance(0.25)).is_equal(1)


func test_speed_multiplier_scales_time() -> void:
	var clock := _clock()
	clock.speed_multiplier = 2.0

	assert_int(clock.advance(0.5)).is_equal(4)


func test_catch_up_is_capped_so_a_long_frame_does_not_flood_ticks() -> void:
	var clock := _clock()

	var due := clock.advance(60.0)

	assert_int(due).is_equal(SkirmishClock.MAX_CATCH_UP_TICKS)
	assert_float(clock.fraction()).is_less(1.0)

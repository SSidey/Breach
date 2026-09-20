extends GdUnitTestSuite

const SimulationClock = preload("res://sim/simulation_clock.gd")


func test_advance_tick_increments_tick_number() -> void:
	var clock := SimulationClock.new()

	clock.advance_tick()

	assert_int(clock.tick_number()).is_equal(1)


func test_advance_tick_emits_tick_advanced_with_new_tick_number() -> void:
	var clock := SimulationClock.new()
	# auto_free = false: SimEvents is the shared project autoload, not a test-owned
	# object - monitor_signals() defaults to freeing what it's given at test end, which
	# would tear down the singleton for every later test in the suite (caught by this
	# exact failure: subsequent tests errored with "previously freed" until this was
	# set to false).
	monitor_signals(SimEvents, false)

	clock.advance_tick()

	await assert_signal(SimEvents).is_emitted("tick_advanced", 1)


func test_advance_time_does_not_tick_before_duration_reached() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0

	clock.advance_time(1.0)

	assert_int(clock.tick_number()).is_equal(0)


func test_advance_time_ticks_once_duration_reached() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0

	clock.advance_time(2.0)

	assert_int(clock.tick_number()).is_equal(1)


func test_pause_prevents_advance_time_from_ticking() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0
	clock.pause()

	clock.advance_time(10.0)

	assert_int(clock.tick_number()).is_equal(0)
	assert_bool(clock.is_paused()).is_true()


func test_resume_allows_auto_advance_again() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0
	clock.pause()
	clock.advance_time(10.0)
	clock.resume()

	clock.advance_time(2.0)

	assert_int(clock.tick_number()).is_equal(1)
	assert_bool(clock.is_paused()).is_false()


func test_skip_to_next_marker_ticks_immediately_regardless_of_elapsed_time() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0
	clock.advance_time(0.1)

	clock.skip_to_next_marker()

	assert_int(clock.tick_number()).is_equal(1)


func test_skip_to_next_marker_resets_elapsed_time_for_next_tick() -> void:
	var clock := SimulationClock.new()
	clock.tick_duration_seconds = 2.0
	clock.advance_time(0.1)
	clock.skip_to_next_marker()

	# Only 0.1s into the *next* tick, not 0.1 + 1.9 - the elapsed counter reset.
	clock.advance_time(1.9)

	assert_int(clock.tick_number()).is_equal(1)


func test_skip_to_next_marker_ticks_even_while_paused() -> void:
	var clock := SimulationClock.new()
	clock.pause()

	clock.skip_to_next_marker()

	assert_int(clock.tick_number()).is_equal(1)

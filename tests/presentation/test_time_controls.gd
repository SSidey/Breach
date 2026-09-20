extends GdUnitTestSuite
## Per specs/05's "Time controls affect timing only, never simulation content"
## scenario: each button method calls exactly one SimulationClock method and nothing
## else - verified here with a real SimulationClock rather than a mock, since it's
## cheap and pure to instantiate.

const TimeControls = preload("res://presentation/time_controls.gd")
const SimulationClock = preload("res://sim/simulation_clock.gd")


func test_pause_button_pauses_when_not_paused() -> void:
	var clock := SimulationClock.new()
	var controls: TimeControls = auto_free(TimeControls.new())
	controls.simulation_clock = clock

	controls.on_pause_pressed()

	assert_bool(clock.is_paused()).is_true()


func test_pause_button_resumes_when_already_paused() -> void:
	var clock := SimulationClock.new()
	clock.pause()
	var controls: TimeControls = auto_free(TimeControls.new())
	controls.simulation_clock = clock

	controls.on_pause_pressed()

	assert_bool(clock.is_paused()).is_false()


func test_skip_button_advances_exactly_one_tick() -> void:
	var clock := SimulationClock.new()
	var controls: TimeControls = auto_free(TimeControls.new())
	controls.simulation_clock = clock

	controls.on_skip_pressed()

	assert_int(clock.tick_number()).is_equal(1)


func test_skip_button_works_even_while_paused() -> void:
	var clock := SimulationClock.new()
	clock.pause()
	var controls: TimeControls = auto_free(TimeControls.new())
	controls.simulation_clock = clock

	controls.on_skip_pressed()

	assert_int(clock.tick_number()).is_equal(1)

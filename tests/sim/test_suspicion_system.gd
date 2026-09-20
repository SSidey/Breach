extends GdUnitTestSuite

const SuspicionSystem = preload("res://sim/suspicion_system.gd")


func _system(decay_per_tick: int = 0) -> SuspicionSystem:
	# Thresholds: Wary=25, Alarmed=50, Mobilized=75, Full Alert=90.
	return SuspicionSystem.new([25, 50, 75, 90], decay_per_tick)


func test_starts_calm_at_zero() -> void:
	var suspicion := _system()

	assert_int(suspicion.meter()).is_equal(0)
	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.CALM)


func test_add_suspicion_increases_the_meter() -> void:
	var suspicion := _system()

	suspicion.add_suspicion(10)

	assert_int(suspicion.meter()).is_equal(10)


func test_crossing_a_threshold_changes_tier_and_emits_the_event() -> void:
	var suspicion := _system()
	monitor_signals(SimEvents, false)

	suspicion.add_suspicion(80)

	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.MOBILIZED)
	await assert_signal(SimEvents).is_emitted(
		"suspicion_tier_changed", SuspicionSystem.Tier.MOBILIZED
	)


func test_meter_is_clamped_to_one_hundred() -> void:
	var suspicion := _system()

	suspicion.add_suspicion(500)

	assert_int(suspicion.meter()).is_equal(100)
	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.FULL_ALERT)


func test_decay_reduces_the_meter_each_tick() -> void:
	var suspicion := _system(5)
	suspicion.add_suspicion(20)

	suspicion.on_tick_advanced(1)

	assert_int(suspicion.meter()).is_equal(15)


func test_decay_can_move_the_tier_back_down_and_emits_the_event() -> void:
	var suspicion := _system(30)
	suspicion.add_suspicion(30)
	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.WARY)
	monitor_signals(SimEvents, false)

	suspicion.on_tick_advanced(1)

	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.CALM)
	await assert_signal(SimEvents).is_emitted("suspicion_tier_changed", SuspicionSystem.Tier.CALM)


func test_meter_does_not_decay_below_zero() -> void:
	var suspicion := _system(100)
	suspicion.add_suspicion(10)

	suspicion.on_tick_advanced(1)

	assert_int(suspicion.meter()).is_equal(0)

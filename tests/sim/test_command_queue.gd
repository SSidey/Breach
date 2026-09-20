extends GdUnitTestSuite

const CommandQueue = preload("res://sim/command_queue.gd")
const SimulationClock = preload("res://sim/simulation_clock.gd")


func _slot_state(filled: int, required: int) -> Dictionary:
	return {"filled": filled, "required": required}


func _is_filled_check(state: Dictionary) -> Callable:
	return func(): return state["filled"] >= state["required"]


func test_enqueue_returns_a_usable_id() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(0, 1)

	var id := queue.enqueue("some command", _is_filled_check(state))

	assert_array(queue.pending_commands()).contains(id)


func test_is_filled_reflects_the_injected_predicate() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(3, 5)
	var id := queue.enqueue("wave of 5", _is_filled_check(state))

	assert_bool(queue.is_filled(id)).is_false()

	state["filled"] = 5

	assert_bool(queue.is_filled(id)).is_true()


func test_under_filled_command_stays_pending_after_tick() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(3, 5)
	var id := queue.enqueue("wave of 5", _is_filled_check(state))
	monitor_signals(SimEvents, false)

	queue.on_tick_advanced(1)

	assert_array(queue.pending_commands()).contains(id)
	await assert_signal(SimEvents).is_not_emitted("command_committed")


func test_filled_command_does_not_commit_until_a_tick_is_announced() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(5, 5)
	queue.enqueue("wave of 5", _is_filled_check(state))

	assert_array(queue.pending_commands()).has_size(1)


func test_filled_command_commits_on_tick_and_emits_exactly_once() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(5, 5)
	var id := queue.enqueue("wave of 5", _is_filled_check(state))
	monitor_signals(SimEvents, false)

	queue.on_tick_advanced(1)

	assert_array(queue.pending_commands()).is_empty()
	await assert_signal(SimEvents).is_emitted("command_committed", "wave of 5")


func test_cancel_removes_a_pending_command() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(2, 5)
	var id := queue.enqueue("wave of 5", _is_filled_check(state))

	queue.cancel(id)

	assert_array(queue.pending_commands()).is_empty()
	assert_bool(queue.is_filled(id)).is_false()


func test_cancelled_command_never_commits_even_after_becoming_filled_and_ticking() -> void:
	var queue := CommandQueue.new()
	var state := _slot_state(2, 5)
	var id := queue.enqueue("wave of 5", _is_filled_check(state))
	queue.cancel(id)
	monitor_signals(SimEvents, false)

	state["filled"] = 5
	queue.on_tick_advanced(1)

	await assert_signal(SimEvents).is_not_emitted("command_committed")


func test_integration_commits_only_once_slots_fill_and_a_tick_advances() -> void:
	var clock := SimulationClock.new()
	var queue := CommandQueue.new()
	var state := _slot_state(3, 5)
	queue.enqueue("wave of 5", _is_filled_check(state))
	monitor_signals(SimEvents, false)

	# Tick 1: still under-filled.
	clock.advance_tick()
	queue.on_tick_advanced(clock.tick_number())
	assert_array(queue.pending_commands()).has_size(1)

	# Fill the last slots between ticks.
	state["filled"] = 5

	# Tick 2: now filled, should commit.
	clock.advance_tick()
	queue.on_tick_advanced(clock.tick_number())

	assert_array(queue.pending_commands()).is_empty()
	await assert_signal(SimEvents).is_emitted("command_committed", "wave of 5")

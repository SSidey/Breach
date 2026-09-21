extends GdUnitTestSuite

const ScriptedBeatWatcher = preload("res://sim/scripted_beat_watcher.gd")

const CORE_INDEX := 3


func test_reaching_the_core_before_the_hero_party_is_defeated_does_not_win() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	monitor_signals(SimEvents, false)

	watcher.on_node_captured(CORE_INDEX)

	await assert_signal(SimEvents).is_not_emitted("victory")


func test_defeating_the_hero_party_sets_the_flag_but_does_not_win_by_itself() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	monitor_signals(SimEvents, false)

	watcher.on_hero_party_defeated()

	assert_bool(watcher.hero_party_defeated()).is_true()
	await assert_signal(SimEvents).is_not_emitted("victory")


func test_reaching_the_core_after_the_hero_party_is_defeated_wins() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	watcher.on_hero_party_defeated()
	monitor_signals(SimEvents, false)

	watcher.on_node_captured(CORE_INDEX)

	await assert_signal(SimEvents).is_emitted("victory")


func test_capturing_a_different_node_after_defeat_does_not_win() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	watcher.on_hero_party_defeated()
	monitor_signals(SimEvents, false)

	watcher.on_node_captured(1)

	await assert_signal(SimEvents).is_not_emitted("victory")


func test_losing_the_entire_force_before_defeating_the_hero_party_loses() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	monitor_signals(SimEvents, false)

	watcher.on_player_unit_count_changed(0)

	await assert_signal(SimEvents).is_emitted("defeat")


func test_losing_the_entire_force_after_defeating_the_hero_party_still_loses() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	watcher.on_hero_party_defeated()
	monitor_signals(SimEvents, false)

	watcher.on_player_unit_count_changed(0)

	await assert_signal(SimEvents).is_emitted("defeat")


func test_a_positive_unit_count_does_not_trigger_defeat() -> void:
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	monitor_signals(SimEvents, false)

	watcher.on_player_unit_count_changed(3)

	await assert_signal(SimEvents).is_not_emitted("defeat")


func test_defeat_only_fires_once_even_if_reported_zero_repeatedly() -> void:
	## Regression: found via manual playtest - a composition root re-checking unit
	## count every tick (rather than only on a real change) was spamming "defeat"
	## once the count first hit zero, since nothing gated repeat reports.
	var watcher := ScriptedBeatWatcher.new(CORE_INDEX)
	watcher.on_player_unit_count_changed(0)
	monitor_signals(SimEvents, false)

	watcher.on_player_unit_count_changed(0)
	watcher.on_player_unit_count_changed(0)

	await assert_signal(SimEvents).is_not_emitted("defeat")

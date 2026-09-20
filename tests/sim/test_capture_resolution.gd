extends GdUnitTestSuite

const CaptureResolution = preload("res://sim/capture_resolution.gd")
const EconomySystem = preload("res://sim/economy_system.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")


func _farm_node() -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.RESOURCE
	node.yield_food_per_tick = 10
	node.decay_interval_ticks = 5
	node.decay_floor_food = 2
	node.ravage_yield_food = 40
	return node


func _fort_node() -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.garrison = 1
	node.garrison_hp = 10
	node.garrison_dmg = 3
	node.dismantle_wood_yield = 8
	node.dismantle_stone_yield = 5
	node.fortify_wood_cost = 10
	node.fortify_stone_cost = 6
	return node


func test_capturing_a_resource_node_defaults_to_harvest_and_is_not_awaiting_choice() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)

	capture.on_node_captured(1, _farm_node())

	assert_bool(capture.is_awaiting_choice(1)).is_false()


func test_capturing_a_fort_awaits_a_choice() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)

	capture.on_node_captured(2, _fort_node())

	assert_bool(capture.is_awaiting_choice(2)).is_true()


func test_harvest_adds_the_current_decayed_yield_every_tick() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(1, _farm_node())

	capture.on_tick_advanced(1)

	assert_int(economy.balance("food")).is_equal(10)


func test_harvest_yield_decays_after_enough_ticks() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(1, _farm_node())

	for i in range(5):
		capture.on_tick_advanced(i + 1)

	# Ticks 1-4 (interval not yet reached) yield 10 each = 40; tick 5 (1 interval
	# elapsed) yields 9. Total = 49.
	assert_int(economy.balance("food")).is_equal(49)


func test_ravage_grants_a_lump_sum_and_stops_further_harvesting() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(1, _farm_node())

	capture.issue_choice(1, "ravage")
	capture.on_tick_advanced(1)

	assert_int(economy.balance("food")).is_equal(40)


func test_dismantle_grants_free_salvage_and_resolves_the_choice() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(2, _fort_node())

	capture.issue_choice(2, "dismantle")

	assert_int(economy.balance("wood")).is_equal(8)
	assert_int(economy.balance("stone")).is_equal(5)
	assert_bool(capture.is_awaiting_choice(2)).is_false()


func test_fortify_spends_resources_and_resolves_the_choice() -> void:
	var economy := EconomySystem.new()
	economy.add("wood", 10)
	economy.add("stone", 6)
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(2, _fort_node())

	capture.issue_choice(2, "fortify")

	assert_int(economy.balance("wood")).is_equal(0)
	assert_int(economy.balance("stone")).is_equal(0)
	assert_bool(capture.is_awaiting_choice(2)).is_false()


func test_fortify_does_nothing_when_the_player_cannot_afford_it() -> void:
	var economy := EconomySystem.new()
	var capture := CaptureResolution.new(economy)
	capture.on_node_captured(2, _fort_node())

	capture.issue_choice(2, "fortify")

	assert_int(economy.balance("wood")).is_equal(0)
	assert_bool(capture.is_awaiting_choice(2)).is_true()

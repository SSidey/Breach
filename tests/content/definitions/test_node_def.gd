extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")


func test_resource_node_without_yield_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.RESOURCE
	node.yield_food_per_tick = 0

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(
			Array(errors).any(func(message): return message.contains("yield_food_per_tick"))
		)
		. is_true()
	)


func test_origin_node_does_not_require_resource_fields() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "home"
	node.yield_food_per_tick = 0

	assert_array(node.validate()).is_empty()


func test_negative_garrison_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.garrison = -1

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("garrison"))).is_true()


func test_garrisoned_node_without_blocker_stats_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.garrison = 3
	node.garrison_hp = 0
	node.garrison_dmg = 0

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("garrison_hp"))).is_true()


func test_ungarrisoned_node_does_not_require_blocker_stats() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "home"
	node.garrison = 0
	node.garrison_hp = 0
	node.garrison_dmg = 0

	assert_array(node.validate()).is_empty()


func test_resource_node_without_ravage_yield_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.RESOURCE
	node.yield_food_per_tick = 10
	node.decay_interval_ticks = 5
	node.ravage_yield_food = 0

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(Array(errors).any(func(message): return message.contains("ravage_yield_food")))
		. is_true()
	)


func test_node_with_empty_id_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = ""

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("id"))).is_true()


func test_node_with_a_non_empty_id_is_valid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "farm"

	assert_array(node.validate()).is_empty()


func test_neutral_node_requires_no_type_specific_fields() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.NEUTRAL
	node.id = "contested"

	assert_array(node.validate()).is_empty()


func test_fort_node_missing_dismantle_and_fortify_figures_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.garrison = 1
	node.garrison_hp = 10
	node.garrison_dmg = 3
	node.dismantle_wood_yield = 0
	node.dismantle_stone_yield = 0
	node.fortify_wood_cost = 0
	node.fortify_stone_cost = 0

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(
			Array(errors).any(func(message): return message.contains("dismantle_wood_yield"))
		)
		. is_true()
	)


func test_resource_node_defaults_to_food_with_unlimited_reserves() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.RESOURCE
	node.id = "farm"
	node.yield_food_per_tick = 6
	node.decay_interval_ticks = 5
	node.ravage_yield_food = 40

	assert_int(node.resource_type).is_equal(NodeDef.ResourceType.FOOD)
	assert_int(node.total_reserves).is_equal(0)
	assert_array(node.validate()).is_empty()


func test_negative_total_reserves_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "home"
	node.total_reserves = -1

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("total_reserves"))).is_true()


func test_patrol_route_without_a_garrison_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "home"
	node.garrison = 0
	node.patrol_route = ["a", "b"]

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("patrol_route"))).is_true()


func test_patrol_route_with_a_garrison_is_valid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.id = "fort"
	node.garrison = 2
	node.garrison_hp = 10
	node.garrison_dmg = 3
	node.dismantle_wood_yield = 8
	node.dismantle_stone_yield = 5
	node.fortify_wood_cost = 10
	node.fortify_stone_cost = 6
	node.patrol_route = ["a", "b"]

	assert_array(node.validate()).is_empty()


func test_can_sortie_without_a_garrison_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "home"
	node.garrison = 0
	node.can_sortie = true

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("can_sortie"))).is_true()

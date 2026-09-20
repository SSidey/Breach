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
	node.yield_food_per_tick = 0

	assert_array(node.validate()).is_empty()


func test_negative_garrison_is_invalid() -> void:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.garrison = -1

	var errors := node.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("garrison"))).is_true()

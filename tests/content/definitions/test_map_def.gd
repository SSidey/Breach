extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")


func _make_origin_node() -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = "node"
	return node


func test_valid_map_def_has_no_errors() -> void:
	var map := MapDef.new()
	map.nodes = [_make_origin_node(), _make_origin_node()]
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	map.suspicion_decay_per_tick = 1

	assert_array(map.validate()).is_empty()


func test_fewer_than_two_nodes_is_invalid() -> void:
	var map := MapDef.new()
	map.nodes = [_make_origin_node()]
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("nodes"))).is_true()


func test_non_ascending_thresholds_is_invalid() -> void:
	var map := MapDef.new()
	map.nodes = [_make_origin_node(), _make_origin_node()]
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [50, 30, 70, 90]

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(
			Array(errors).any(func(message): return message.contains("suspicion_tier_thresholds"))
		)
		. is_true()
	)


func test_invalid_child_node_error_is_aggregated() -> void:
	var bad_node := NodeDef.new()
	bad_node.node_type = NodeDef.NodeType.ORIGIN
	bad_node.garrison = -1

	var map := MapDef.new()
	map.nodes = [_make_origin_node(), bad_node]
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	assert_bool(Array(errors).any(func(message): return message.contains("garrison"))).is_true()

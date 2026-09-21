extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")


func _origin_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _valid_lane() -> LaneDef:
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_origin_node("home"), _origin_node("core")]
	lane.nodes = nodes
	lane.player_home_index = 0
	return lane


func test_valid_lane_def_has_no_errors() -> void:
	assert_array(_valid_lane().validate()).is_empty()


func test_fewer_than_two_nodes_is_invalid() -> void:
	var lane := _valid_lane()
	var nodes: Array[NodeDef] = [_origin_node("home")]
	lane.nodes = nodes

	var errors := lane.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("nodes"))).is_true()


func test_player_home_index_out_of_range_is_invalid() -> void:
	var lane := _valid_lane()
	lane.player_home_index = 5

	var errors := lane.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(Array(errors).any(func(message): return message.contains("player_home_index")))
		. is_true()
	)


func test_negative_player_home_index_is_invalid() -> void:
	var lane := _valid_lane()
	lane.player_home_index = -1

	var errors := lane.validate()

	assert_array(errors).is_not_empty()
	(
		assert_bool(Array(errors).any(func(message): return message.contains("player_home_index")))
		. is_true()
	)


func test_invalid_child_node_error_is_aggregated() -> void:
	var lane := _valid_lane()
	var bad_node := _origin_node("bad")
	bad_node.garrison = -1
	var nodes: Array[NodeDef] = [_origin_node("home"), bad_node]
	lane.nodes = nodes

	var errors := lane.validate()

	assert_bool(Array(errors).any(func(message): return message.contains("garrison"))).is_true()

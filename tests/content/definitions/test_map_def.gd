extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")


func _make_origin_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _valid_lane() -> LaneDef:
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("home"), _make_origin_node("core")]
	lane.nodes = nodes
	lane.player_home_index = 0
	return lane


func test_valid_map_def_has_no_errors() -> void:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	map.suspicion_decay_per_tick = 1

	assert_array(map.validate()).is_empty()


func test_zero_lanes_is_invalid() -> void:
	var map := MapDef.new()
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("lanes"))).is_true()


func test_non_ascending_thresholds_is_invalid() -> void:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
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


func test_invalid_child_lane_error_is_aggregated() -> void:
	var bad_lane := _valid_lane()
	bad_lane.player_home_index = 9

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [bad_lane]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	(
		assert_bool(Array(errors).any(func(message): return message.contains("player_home_index")))
		. is_true()
	)

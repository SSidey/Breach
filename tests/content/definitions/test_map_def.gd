extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")
const FactionRelationDef = preload("res://content/definitions/faction_relation_def.gd")


func _make_origin_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _valid_lane(
	lane_id: String = "main", node_a_id: String = "home", node_b_id: String = "core"
) -> LaneDef:
	var lane := LaneDef.new()
	lane.id = lane_id
	var nodes: Array[NodeDef] = [_make_origin_node(node_a_id), _make_origin_node(node_b_id)]
	lane.nodes = nodes
	lane.player_home_index = 0
	return lane


func _edge(node_a_id: String, node_b_id: String) -> MapEdgeDef:
	var edge := MapEdgeDef.new()
	edge.node_a_id = node_a_id
	edge.node_b_id = node_b_id
	return edge


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


func test_edge_referencing_nonexistent_node_id_is_invalid() -> void:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane("main", "p", "f")]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var edges: Array[MapEdgeDef] = [_edge("p", "ghost")]
	map.edges = edges

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost"))).is_true()


func test_duplicate_edge_either_order_is_invalid() -> void:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane("main", "p", "f")]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var edges: Array[MapEdgeDef] = [_edge("p", "f"), _edge("f", "p")]
	map.edges = edges

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("duplicate"))).is_true()


func test_valid_edge_across_two_lanes_has_no_errors() -> void:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [
		_valid_lane("a", "a_home", "a_core"), _valid_lane("b", "b_home", "b_core")
	]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var edges: Array[MapEdgeDef] = [_edge("a_home", "b_home")]
	map.edges = edges

	assert_array(map.validate()).is_empty()


func _garrisoned_fort_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.id = id
	node.garrison = 2
	node.garrison_hp = 10
	node.garrison_dmg = 3
	node.dismantle_wood_yield = 8
	node.dismantle_stone_yield = 5
	node.fortify_wood_cost = 10
	node.fortify_stone_cost = 6
	return node


func test_patrol_route_referencing_nonexistent_node_id_is_invalid() -> void:
	var fort := _garrisoned_fort_node("F")
	fort.patrol_route = ["p", "ghost"]
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("p"), fort]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [lane]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost"))).is_true()


func test_delivery_target_id_referencing_nonexistent_node_is_invalid() -> void:
	var resource_node := NodeDef.new()
	resource_node.node_type = NodeDef.NodeType.RESOURCE
	resource_node.id = "f"
	resource_node.yield_food_per_tick = 6
	resource_node.decay_interval_ticks = 5
	resource_node.ravage_yield_food = 40
	resource_node.delivery_target_id = "ghost"
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("p"), resource_node]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [lane]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost"))).is_true()


func test_faction_relations_error_is_aggregated() -> void:
	var relation := FactionRelationDef.new()
	relation.faction_a = FactionRelationDef.FactionId.PLAYER
	relation.faction_b = FactionRelationDef.FactionId.PLAYER

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var relations: Array[FactionRelationDef] = [relation]
	map.faction_relations = relations

	var errors := map.validate()

	assert_array(errors).is_not_empty()

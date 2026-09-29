extends GdUnitTestSuite
## MapDef.off_lane_nodes, per specs/16-designer-map-import.md: nodes that exist on the
## map but sit on no lane path (side objectives, secret caches, branch waypoints).
## Split from test_map_def.gd to keep that file under the max-file-lines gate.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")
const FactionDef = preload("res://content/definitions/faction_def.gd")


func _origin(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _map_with_off_lane(off_lane: NodeDef) -> MapDef:
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_origin("home"), _origin("core")]
	lane.nodes = nodes
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [lane]
	map.lanes = lanes
	map.tick_duration_seconds = 1.5
	map.suspicion_tier_thresholds = [20, 45, 70, 90]
	var off: Array[NodeDef] = [off_lane]
	map.off_lane_nodes = off
	return map


func test_edge_may_reference_an_off_lane_node() -> void:
	var cache := NodeDef.new()
	cache.node_type = NodeDef.NodeType.WAYPOINT
	cache.id = "cache"
	var map := _map_with_off_lane(cache)
	var edge := MapEdgeDef.new()
	edge.node_a_id = "core"
	edge.node_b_id = "cache"
	var edges: Array[MapEdgeDef] = [edge]
	map.edges = edges

	assert_array(map.validate()).is_empty()


func test_off_lane_node_is_validated() -> void:
	var cache := NodeDef.new()
	cache.node_type = NodeDef.NodeType.RESOURCE
	cache.id = "cache"
	cache.yield_food_per_tick = 0

	var errors := _map_with_off_lane(cache).validate()

	assert_bool(Array(errors).any(func(m): return m.contains("yield_food_per_tick"))).is_true()


func test_off_lane_node_faction_references_are_checked() -> void:
	var cache := _origin("cache")
	cache.owning_faction_id = "ghost_faction"
	var map := _map_with_off_lane(cache)
	var factions: Array[FactionDef] = []
	map.factions = factions

	var errors := map.validate()

	assert_bool(Array(errors).any(func(m): return m.contains("ghost_faction"))).is_true()

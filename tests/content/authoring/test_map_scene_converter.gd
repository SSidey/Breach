extends GdUnitTestSuite

const NodeDef = preload("res://content/definitions/node_def.gd")
const MapLaneRoot = preload("res://content/authoring/map_lane_root.gd")
const MapNodeMarker = preload("res://content/authoring/map_node_marker.gd")
const MapSceneConverter = preload("res://content/authoring/map_scene_converter.gd")


func _origin_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _marker(node_def: NodeDef, at: Vector2 = Vector2.ZERO, is_home: bool = false) -> MapNodeMarker:
	var marker: MapNodeMarker = auto_free(MapNodeMarker.new())
	marker.node_def = node_def
	marker.position = at
	marker.player_home = is_home
	return marker


func _lane(lane_id: String, markers: Array[MapNodeMarker]) -> MapLaneRoot:
	var lane: MapLaneRoot = auto_free(MapLaneRoot.new())
	lane.lane_id = lane_id
	for marker in markers:
		lane.add_child(marker)
	return lane


func _scene_root(lanes: Array[MapLaneRoot]) -> Node2D:
	var root: Node2D = auto_free(Node2D.new())
	for lane in lanes:
		root.add_child(lane)
	return root


func test_single_lane_converts_with_matching_id_order_and_player_home() -> void:
	var markers: Array[MapNodeMarker] = [
		_marker(_origin_node("home"), Vector2.ZERO, true),
		_marker(_origin_node("mid")),
		_marker(_origin_node("core")),
	]
	var root := _scene_root([_lane("main", markers)])

	var result := MapSceneConverter.build_map_def(root)

	assert_array(result.errors).is_empty()
	assert_int(result.map_def.lanes.size()).is_equal(1)
	var lane := result.map_def.lanes[0]
	assert_str(lane.id).is_equal("main")
	assert_int(lane.nodes.size()).is_equal(3)
	assert_str(lane.nodes[0].id).is_equal("home")
	assert_str(lane.nodes[1].id).is_equal("mid")
	assert_str(lane.nodes[2].id).is_equal("core")
	assert_int(lane.player_home_index).is_equal(0)


func test_marker_position_is_stamped_without_mutating_the_source_node_def() -> void:
	var source := _origin_node("home")
	var marker := _marker(source, Vector2(128, 64), true)
	var root := _scene_root([_lane("main", [marker, _marker(_origin_node("core"))])])

	var result := MapSceneConverter.build_map_def(root)

	var converted_node := result.map_def.lanes[0].nodes[0]
	assert_vector(converted_node.position).is_equal_approx(Vector2(128, 64), Vector2(0.001, 0.001))
	assert_vector(source.position).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))


func test_no_player_home_marker_reports_an_error() -> void:
	var markers: Array[MapNodeMarker] = [
		_marker(_origin_node("home")),
		_marker(_origin_node("core")),
	]
	var root := _scene_root([_lane("main", markers)])

	var result := MapSceneConverter.build_map_def(root)

	assert_array(result.errors).is_not_empty()
	assert_bool(Array(result.errors).any(func(m): return m.contains("player_home"))).is_true()


func test_multiple_player_home_markers_reports_an_error() -> void:
	var markers: Array[MapNodeMarker] = [
		_marker(_origin_node("home"), Vector2.ZERO, true),
		_marker(_origin_node("core"), Vector2.ZERO, true),
	]
	var root := _scene_root([_lane("main", markers)])

	var result := MapSceneConverter.build_map_def(root)

	assert_array(result.errors).is_not_empty()
	assert_bool(Array(result.errors).any(func(m): return m.contains("player_home"))).is_true()


func test_multiple_lanes_preserve_scene_root_child_order() -> void:
	var lane_a := _lane(
		"a", [_marker(_origin_node("a1"), Vector2.ZERO, true), _marker(_origin_node("a2"))]
	)
	var lane_b := _lane(
		"b", [_marker(_origin_node("b1"), Vector2.ZERO, true), _marker(_origin_node("b2"))]
	)
	var root := _scene_root([lane_a, lane_b])

	var result := MapSceneConverter.build_map_def(root)

	assert_array(result.errors).is_empty()
	assert_int(result.map_def.lanes.size()).is_equal(2)
	assert_str(result.map_def.lanes[0].id).is_equal("a")
	assert_str(result.map_def.lanes[1].id).is_equal("b")

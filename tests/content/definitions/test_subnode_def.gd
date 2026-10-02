extends GdUnitTestSuite
## A node's subnodes, per Decision 72 and spec 26 round 1: objectives with a capture area
## inside a zone of influence, painted in the node's cells; zones stay on the node's tiles
## and never overlap.

const NodeDef = preload("res://content/definitions/node_def.gd")
const SubnodeDef = preload("res://content/definitions/subnode_def.gd")


func _cells(points: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(points)
	return out


func _square(x0: int, y0: int, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(x0, x0 + size):
		for y in range(y0, y0 + size):
			out.append(Vector2i(x, y))
	return out


func _subnode(subnode_id: String, at: Vector2i, capture: Array, zone: Array) -> SubnodeDef:
	var subnode := SubnodeDef.new()
	subnode.id = subnode_id
	subnode.subnode_type = "WELL"
	subnode.at = at
	subnode.capture_cells = _cells(capture)
	subnode.zone_cells = _cells(zone)
	return subnode


func _well(subnode_id: String, x0: int, y0: int) -> SubnodeDef:
	return _subnode(
		subnode_id, Vector2i(x0 + 2, y0 + 2), _square(x0 + 1, y0 + 1, 3), _square(x0, y0, 5)
	)


func _node_with(subnodes: Array, footprint: Array = []) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.WAYPOINT
	node.id = "n"
	node.tile = Vector2i(3, 2)
	node.footprint = _cells(footprint)
	var list: Array[SubnodeDef] = []
	list.assign(subnodes)
	node.subnodes = list
	return node


func _has(errors: PackedStringArray, text: String) -> bool:
	return Array(errors).any(func(m): return m.contains(text))


func test_a_well_inside_the_node_is_valid() -> void:
	assert_array(_node_with([_well("well_1", 10, 10)]).validate()).is_empty()


func test_the_capture_area_must_not_be_empty() -> void:
	var subnode := _subnode("well_1", Vector2i(1, 1), [], _square(0, 0, 3))

	assert_bool(_has(subnode.validate(), "capture area is empty")).is_true()


func test_the_capture_area_must_lie_in_the_zone() -> void:
	var subnode := _subnode("well_1", Vector2i(1, 1), [Vector2i(9, 9)], _square(0, 0, 3))

	assert_bool(_has(subnode.validate(), "outside its zone")).is_true()


func test_the_marker_must_lie_in_the_zone() -> void:
	var subnode := _subnode("well_1", Vector2i(20, 20), [Vector2i(1, 1)], _square(0, 0, 3))

	assert_bool(_has(subnode.validate(), "marker")).is_true()


func test_the_type_must_be_known() -> void:
	var subnode := _well("well_1", 0, 0)
	subnode.subnode_type = "VOLCANO"

	assert_bool(_has(subnode.validate(), "unknown type")).is_true()


func test_zones_must_not_overlap() -> void:
	var errors := _node_with([_well("well_1", 10, 10), _well("well_2", 13, 10)]).validate()

	assert_bool(_has(errors, "overlap")).is_true()


func test_subnode_ids_are_unique_in_a_node() -> void:
	var errors := _node_with([_well("well_1", 0, 0), _well("well_1", 20, 20)]).validate()

	assert_bool(_has(errors, "more than once")).is_true()


func test_a_zone_must_stay_on_the_nodes_tiles() -> void:
	var errors := _node_with([_well("well_1", 62, 10)]).validate()

	assert_bool(_has(errors, "off the node's tiles")).is_true()


func test_a_zone_may_cross_onto_another_tile_of_the_footprint() -> void:
	var node := _node_with([_well("well_1", 62, 10)], [Vector2i(3, 2), Vector2i(4, 2)])

	assert_array(node.validate()).is_empty()


func test_cells_left_and_up_of_the_own_tile_fall_on_earlier_tiles() -> void:
	var node := _node_with([_well("well_1", -3, -3)], [Vector2i(3, 2), Vector2i(2, 2)])

	assert_bool(_has(node.validate(), "off the node's tiles")).is_true()  # (2,1) isn't covered

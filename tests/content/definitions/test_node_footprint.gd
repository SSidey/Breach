extends GdUnitTestSuite
## A node's footprint, per Decision 68 and spec 25 round 2: the tiles it covers, any
## connected shape including its own tile; a node with no tile covers none.

const NodeDef = preload("res://content/definitions/node_def.gd")


func _node_at(tile: Vector2i, footprint: Array) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.WAYPOINT
	node.id = "n"
	node.tile = tile
	var tiles: Array[Vector2i] = []
	tiles.assign(footprint)
	node.footprint = tiles
	return node


func test_a_node_with_no_tile_covers_none() -> void:
	assert_array(NodeDef.new().covered_tiles()).is_empty()


func test_a_node_covers_its_own_tile_by_default() -> void:
	assert_array(_node_at(Vector2i(2, 3), []).covered_tiles()).is_equal([Vector2i(2, 3)])


func test_an_l_shaped_footprint_is_valid() -> void:
	var node := _node_at(Vector2i(0, 0), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])

	assert_array(node.validate()).is_empty()
	assert_int(node.covered_tiles().size()).is_equal(3)


func test_a_footprint_must_include_the_nodes_own_tile() -> void:
	var errors := Array(_node_at(Vector2i(0, 0), [Vector2i(5, 5)]).validate())

	assert_bool(errors.any(func(m): return m.contains("own tile"))).is_true()


func test_a_footprint_must_be_connected() -> void:
	var errors := Array(_node_at(Vector2i(0, 0), [Vector2i(0, 0), Vector2i(2, 0)]).validate())

	assert_bool(errors.any(func(m): return m.contains("connected"))).is_true()

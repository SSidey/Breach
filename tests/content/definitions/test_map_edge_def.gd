extends GdUnitTestSuite

const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")


func _valid_edge() -> MapEdgeDef:
	var edge := MapEdgeDef.new()
	edge.node_a_id = "p"
	edge.node_b_id = "f"
	return edge


func test_valid_edge_has_no_errors() -> void:
	assert_array(_valid_edge().validate()).is_empty()


func test_empty_node_a_id_is_invalid() -> void:
	var edge := _valid_edge()
	edge.node_a_id = ""

	var errors := edge.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("node_a_id"))).is_true()


func test_empty_node_b_id_is_invalid() -> void:
	var edge := _valid_edge()
	edge.node_b_id = ""

	var errors := edge.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("node_b_id"))).is_true()


func test_self_loop_is_invalid() -> void:
	var edge := _valid_edge()
	edge.node_b_id = edge.node_a_id

	var errors := edge.validate()

	assert_array(errors).is_not_empty()

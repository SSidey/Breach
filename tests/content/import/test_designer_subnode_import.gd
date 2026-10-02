extends GdUnitTestSuite
## Subnodes import with their node, per spec 26 round 1: the designer's subnodes (type,
## marker, capture and zone cells as [x, y] columns) become the node's SubnodeDefs.

const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


func _import_node_c(subnodes: Array) -> NodeDef:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var entry: Dictionary = export_data["nodes"][3]  # c, at row 2, col 9
	entry["subnodes"] = subnodes
	var result = DesignerMapImporter.import_map(export_data)
	for lane in result.map_def.lanes:
		for candidate in lane.nodes:
			if candidate.id == "c":
				return candidate
	return null


func test_a_nodes_subnodes_import_with_it() -> void:
	var node := _import_node_c(
		[
			{
				"id": "well_1",
				"type": "WELL",
				"at": [5, 6],
				"capture": [[5, 6], [5, 7]],
				"zone": [[5, 6], [5, 7], [4, 6]]
			}
		]
	)

	assert_int(node.subnodes.size()).is_equal(1)
	var well = node.subnodes[0]
	assert_str(well.id).is_equal("well_1")
	assert_str(well.subnode_type).is_equal("WELL")
	assert_object(well.at).is_equal(Vector2i(5, 6))
	assert_array(well.capture_cells).is_equal([Vector2i(5, 6), Vector2i(5, 7)])
	assert_array(well.zone_cells).is_equal([Vector2i(5, 6), Vector2i(5, 7), Vector2i(4, 6)])
	assert_array(well.validate()).is_empty()


func test_a_node_without_subnodes_imports_none() -> void:
	assert_array(_import_node_c([]).subnodes).is_empty()

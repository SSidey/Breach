extends GdUnitTestSuite
## Structure plans import with their node, per spec 24 round 2: the designer's plan
## (solid cells, faces, dug cells, loads) becomes the node's StructurePlanDef.

const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")
const DesignerPlanBuilder = preload("res://content/import/designer_plan_builder.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")

const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


func _plan() -> Dictionary:
	return {
		"solid_cells": {"3,4,0": "ROCK"},
		"faces":
		[
			{"x": 1, "y": 1, "level": 0, "side": "south", "material": "TIMBER", "thickness": 2},
			{"x": 1, "y": 1, "level": 1, "side": "floor", "material": "TIMBER", "thickness": 8}
		],
		"dug": [[2, 2, -1]],
		"loads": {"1,1,1": 40}
	}


func test_a_plan_builds_its_cells_faces_dug_cells_and_loads() -> void:
	var plan := DesignerPlanBuilder.build(_plan())

	assert_str(plan.solid_cells[Vector3i(3, 4, 0)]).is_equal("ROCK")
	assert_str(plan.faces[0].key()).is_equal("face:1,2,0,north")  # south stored as north
	assert_int(plan.faces[0].thickness).is_equal(2)
	assert_int(plan.face_at(Vector3i(1, 1, 1), StructureFaceDef.FLOOR).thickness).is_equal(8)
	assert_array(plan.dug).is_equal([Vector3i(2, 2, -1)])
	assert_int(plan.loads[Vector3i(1, 1, 1)]).is_equal(40)


func test_a_nodes_plan_imports_with_it() -> void:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	export_data["nodes"][0]["plan"] = _plan()

	var result = DesignerMapImporter.import_map(export_data)
	var node_id: String = export_data["nodes"][0]["id"]
	var node = null
	for lane in result.map_def.lanes:
		for candidate in lane.nodes:
			if candidate.id == node_id:
				node = candidate
	for candidate in result.map_def.off_lane_nodes:
		if candidate.id == node_id:
			node = candidate

	assert_object(node).is_not_null()
	assert_int(node.plan.faces.size()).is_equal(2)


func test_a_node_without_a_plan_has_none() -> void:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))

	var result = DesignerMapImporter.import_map(export_data)

	assert_object(result.map_def.lanes[0].nodes[0].plan).is_null()

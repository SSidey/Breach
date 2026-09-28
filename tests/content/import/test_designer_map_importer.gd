extends GdUnitTestSuite
## DesignerMapImporter, per specs/16-designer-map-import.md. Scenarios run against the
## designer's demo export (tests/fixtures/designer/demo_map.designer.json), mutated per
## test where a scenario needs a different shape.

const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")
const FactionRelationDef = preload("res://content/definitions/faction_relation_def.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"


func _demo() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DEMO_PATH))


func _node(export_data: Dictionary, id: String) -> Dictionary:
	for node in export_data["nodes"]:
		if node["id"] == id:
			return node
	return {}


func _find(nodes: Array, id: String) -> NodeDef:
	for node in nodes:
		if node.id == id:
			return node
	return null


func _any(messages: PackedStringArray, needle: String) -> bool:
	return Array(messages).any(func(m): return m.contains(needle))


func test_demo_map_derives_one_lane_from_links() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	assert_array(result.errors).is_empty()
	assert_int(result.map_def.lanes.size()).is_equal(1)
	var lane = result.map_def.lanes[0]
	assert_str(lane.id).is_equal("to_c")
	assert_array(lane.nodes.map(func(n): return n.id)).contains_exactly(["p", "f", "F", "c"])
	assert_int(lane.player_home_index).is_equal(0)


func test_links_not_on_a_lane_become_edges() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	var pairs := result.map_def.edges.map(func(e): return e.node_a_id + "-" + e.node_b_id)
	assert_array(pairs).contains_exactly(["p-s2", "s2-w1", "w1-F"])


func test_nodes_on_no_lane_are_kept_off_lane() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	var ids := result.map_def.off_lane_nodes.map(func(n): return n.id)
	assert_array(ids).contains_exactly(["s2", "w1"])


func test_demo_map_validates() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	assert_array(result.map_def.validate()).is_empty()


func test_position_is_the_centre_of_the_grid_cell() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	var home := _find(result.map_def.lanes[0].nodes, "p")
	assert_vector(home.position).is_equal(Vector2(96, 160))


func test_types_fields_and_names_convert() -> void:
	var export_data := _demo()
	_node(export_data, "f")["fields"]["resource_type"] = "STONE"

	var result := DesignerMapImporter.import_map(export_data)

	var farm := _find(result.map_def.lanes[0].nodes, "f")
	assert_int(farm.node_type).is_equal(NodeDef.NodeType.RESOURCE)
	assert_int(farm.resource_type).is_equal(NodeDef.ResourceType.STONE)
	assert_int(farm.yield_food_per_tick).is_equal(6)
	var waypoint := _find(result.map_def.off_lane_nodes, "w1")
	assert_int(waypoint.node_type).is_equal(NodeDef.NodeType.WAYPOINT)


func test_hidden_status_garrison_and_factions_carry_over() -> void:
	var result := DesignerMapImporter.import_map(_demo())

	var secret := _find(result.map_def.off_lane_nodes, "s2")
	assert_array(secret.hidden_from_faction_ids).contains_exactly(["player"])
	var fort := _find(result.map_def.lanes[0].nodes, "F")
	assert_int(fort.garrison).is_equal(2)
	assert_str(fort.garrison_units[0].faction_id).is_equal("kingdom")  # fell back to owner
	assert_array(fort.garrison_units[0].patrol_route).contains_exactly(["s2"])
	assert_int(result.map_def.factions.size()).is_equal(2)
	var relation = result.map_def.faction_relations[0]
	assert_int(relation.stance).is_equal(FactionRelationDef.Stance.HOSTILE)


func test_missing_player_home_is_an_error() -> void:
	var export_data := _demo()
	_node(export_data, "p")["owning_faction_id"] = null

	var result := DesignerMapImporter.import_map(export_data)

	assert_bool(_any(result.errors, "player home")).is_true()


func test_unreachable_target_is_an_error_but_the_node_is_kept() -> void:
	var export_data := _demo()
	var links: Array = export_data["links"]
	export_data["links"] = links.filter(func(link): return link["b"] != "c")

	var result := DesignerMapImporter.import_map(export_data)

	assert_bool(_any(result.errors, "'c'")).is_true()
	assert_object(_find(result.map_def.off_lane_nodes, "c")).is_not_null()


func test_unknown_fields_and_prototype_sections_are_warnings() -> void:
	var export_data := _demo()
	_node(export_data, "f")["fields"]["mystery"] = 7

	var result := DesignerMapImporter.import_map(export_data)

	assert_array(result.errors).is_empty()
	assert_bool(_any(result.warnings, "mystery")).is_true()
	assert_bool(_any(result.warnings, "tiles")).is_true()


func test_wrong_format_or_version_is_rejected() -> void:
	var export_data := _demo()
	export_data["format_version"] = 2

	var result := DesignerMapImporter.import_map(export_data)

	assert_bool(_any(result.errors, "format")).is_true()


func test_garrison_unit_with_no_faction_anywhere_is_an_error() -> void:
	var export_data := _demo()
	_node(export_data, "F")["owning_faction_id"] = null

	var result := DesignerMapImporter.import_map(export_data)

	assert_bool(_any(result.errors, "'F'")).is_true()

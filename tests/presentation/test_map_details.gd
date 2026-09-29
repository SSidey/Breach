extends GdUnitTestSuite
## MapDetails, per specs/18-map-viewer.md: the map viewer's info-panel text.

const MapDetails = preload("res://presentation/map_details.gd")
const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"


func _demo_map() -> MapDef:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO_PATH))
	return DesignerMapImporter.import_map(export_data).map_def


func test_summary_counts_nodes_lanes_edges_and_factions() -> void:
	var text := MapDetails.summary(_demo_map())

	assert_str(text).contains("6 nodes")
	assert_str(text).contains("1 lane")
	assert_str(text).contains("3 edges")
	assert_str(text).contains("2 off-lane")


func test_node_details_show_type_owner_garrison_and_lanes() -> void:
	var text := MapDetails.node_details(_demo_map(), "F")

	assert_str(text).contains("FORT")
	assert_str(text).contains("garrison 2")
	assert_str(text).contains("to_c")


func test_hidden_status_is_listed() -> void:
	var map := _demo_map()
	var hidden: Array[String] = ["player"]
	map.off_lane_nodes[0].hidden_from_faction_ids = hidden

	var text := MapDetails.node_details(map, map.off_lane_nodes[0].id)

	assert_str(text).contains("hidden from player")
	assert_str(text).contains("off-lane")


func test_unknown_node_says_so() -> void:
	assert_str(MapDetails.node_details(_demo_map(), "nope")).contains("not found")

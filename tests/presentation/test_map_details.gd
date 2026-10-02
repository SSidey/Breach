extends GdUnitTestSuite
## MapDetails, per specs/18-map-viewer.md: the map viewer's info-panel text.

const MapDetails = preload("res://presentation/map_details.gd")
const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"
const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


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


# --- specs/19: layout and objectives ---------------------------------------------


func _layout_map() -> MapDef:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return DesignerMapImporter.import_map(export_data).map_def


func test_summary_adds_the_grid_and_loss_groups() -> void:
	var text := MapDetails.summary(_layout_map())

	assert_str(text).contains("12×5 grid")
	assert_str(text).contains("2 loss groups")


func test_node_details_mark_critical_assets_and_their_loss_groups() -> void:
	var text := MapDetails.node_details(_layout_map(), "p")

	assert_str(text).contains("critical asset")
	assert_str(text).contains("loss group: Home (player, ANY)")


func test_tile_details_show_terrain_feature_capacity_upgrades_and_bridge() -> void:
	var map_def := _layout_map()

	var farm := MapDetails.tile_details(map_def, Vector2i(4, 2))
	var bridge := MapDetails.tile_details(map_def, Vector2i(7, 3))
	var plain := MapDetails.tile_details(map_def, Vector2i(0, 0))

	assert_str(farm).contains("Fields (base)")
	assert_str(farm).contains("Arable land")
	assert_str(farm).contains("upgrades 1/1: GUARD_BARRACKS")
	assert_str(farm).contains("stability 4")
	assert_str(farm).contains("ground: bearing 4 (foundations 8) · dig 32")
	assert_str(farm).contains("liquids: Water 12-24")
	assert_str(farm).contains("strata: Soil, Clay, Rock")
	assert_str(farm).contains("elevation 2")
	assert_str(bridge).contains("Water")
	assert_str(bridge).contains("bridge, hp 40")
	assert_str(plain).contains("Fields (base)")

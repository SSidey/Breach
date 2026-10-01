extends GdUnitTestSuite
## MapView, per specs/18-map-viewer.md. Its drawing needs a render context and is
## verified manually; these smoke tests cover construction, the model rebuild on
## assignment, the fallback shapes and click lookup.

const MapView = preload("res://presentation/map_view.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")
const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"


func _demo_map() -> MapDef:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO_PATH))
	return DesignerMapImporter.import_map(export_data).map_def


func test_constructs_without_a_map() -> void:
	var view: MapView = auto_free(MapView.new())

	assert_object(view.model).is_null()


func test_assigning_a_map_builds_its_view_model() -> void:
	var view: MapView = auto_free(MapView.new())

	view.map = _demo_map()

	assert_int(view.model.markers.size()).is_equal(6)


func test_changing_view_as_rebuilds_the_model() -> void:
	var view: MapView = auto_free(MapView.new())
	var map := _demo_map()
	var hidden: Array[String] = ["player"]
	map.off_lane_nodes[0].hidden_from_faction_ids = hidden
	view.map = map

	view.view_as_faction_id = "player"

	assert_int(view.model.markers.size()).is_equal(5)


func test_every_node_type_has_a_fallback_shape() -> void:
	for node_type in NodeDef.NodeType.values():
		var points := MapView.shape_points(node_type, Vector2(100, 100), 40.0)
		assert_int(points.size()).is_greater_equal(3)


func test_node_at_uses_local_coordinates() -> void:
	var view: MapView = auto_free(MapView.new())
	view.map = _demo_map()
	view.position = Vector2(1000, 0)
	var marker = view.model.markers[0]

	assert_str(view.node_at(marker.position + Vector2(1000, 0))).is_equal(marker.id)
	assert_str(view.node_at(marker.position)).is_equal("")

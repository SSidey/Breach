extends GdUnitTestSuite
## MapViewer (presentation/map_viewer.tscn), per specs/18-map-viewer.md: argument
## parsing and map discovery, plus a smoke test that the scene instantiates and loads
## a map. Interaction (pan, zoom, pick, click) is verified manually.

const MapViewer = preload("res://presentation/map_viewer.gd")
const VIEWER_SCENE := "res://presentation/map_viewer.tscn"


func test_map_argument_is_read_from_user_args() -> void:
	var args := PackedStringArray(["--other", "--map=res://content/maps/demo_map.tres"])

	assert_str(MapViewer.map_path_from_args(args)).is_equal("res://content/maps/demo_map.tres")
	assert_str(MapViewer.map_path_from_args(PackedStringArray())).is_equal("")


func test_lists_only_map_resources_in_name_order() -> void:
	var paths := MapViewer.list_map_paths("res://content/maps")

	assert_array(Array(paths)).contains(["res://content/maps/demo_map.tres"])
	assert_array(Array(paths)).contains(["res://content/maps/p_f_F_c.tres"])
	var sorted := Array(paths)
	sorted.sort()
	assert_array(Array(paths)).is_equal(sorted)


func test_non_map_resources_are_skipped() -> void:
	var paths := MapViewer.list_map_paths("res://assets/placeholder/map")

	assert_array(Array(paths)).is_empty()


func test_scene_instantiates_and_shows_the_requested_map() -> void:
	var viewer: MapViewer = auto_free(load(VIEWER_SCENE).instantiate())
	viewer.initial_map_path = "res://content/maps/demo_map.tres"

	add_child(viewer)

	assert_object(viewer.map_view().map).is_not_null()
	assert_int(viewer.map_view().model.markers.size()).is_greater(0)

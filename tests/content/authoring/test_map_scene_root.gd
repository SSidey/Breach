extends GdUnitTestSuite
## MapSceneRoot's export/save path is engine-glue-only, manual-playtest-verified, per
## specs/10-map-scene-authoring.md - same disclosed-limitation convention as LaneView
## (tests/presentation/test_lane_view.gd). This smoke test only confirms the script
## compiles and constructs cleanly.

const MapSceneRoot = preload("res://content/authoring/map_scene_root.gd")


func test_constructs_without_error() -> void:
	var root: MapSceneRoot = auto_free(MapSceneRoot.new())

	assert_object(root).is_not_null()

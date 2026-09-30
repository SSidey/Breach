extends GdUnitTestSuite
## MapLayoutView and the layout-aware parts of MapViewModel, per
## specs/19-map-layout-and-objectives.md: the viewer draws the designer grid, terrain,
## roads and bridges, and lanes/edges follow their link routes.

const MapLayoutView = preload("res://presentation/map_layout_view.gd")
const MapViewModel = preload("res://presentation/map_view_model.gd")
const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


func _map_def():
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return DesignerMapImporter.import_map(export_data).map_def


func _centre(col: int, row: int) -> Vector2:
	return Vector2((col + 0.5) * 64.0, (row + 0.5) * 64.0)


func _cell_view(view, cell: Vector2i):
	for entry in view.cells:
		if entry.cell == cell:
			return entry
	return null


func test_every_grid_cell_gets_its_terrain_colour() -> void:
	var map_def = _map_def()
	var view := MapLayoutView.build(map_def.layout)
	var library = map_def.layout.terrain_library

	assert_int(view.cells.size()).is_equal(12 * 5)
	assert_object(_cell_view(view, Vector2i(2, 3)).color).is_equal(library.terrain("FOREST").color)
	assert_object(_cell_view(view, Vector2i(0, 0)).color).is_equal(library.terrain("FIELDS").color)
	assert_str(_cell_view(view, Vector2i(9, 4)).feature_glyph).is_equal(
		library.feature("ORE_VEIN").glyph
	)
	assert_object(view.grid_rect).is_equal(Rect2(0, 0, 12 * 64, 5 * 64))


func test_bridges_and_roads_are_listed() -> void:
	var view := MapLayoutView.build(_map_def().layout)

	assert_bool(_cell_view(view, Vector2i(7, 3)).has_bridge).is_true()
	assert_bool(_cell_view(view, Vector2i(7, 4)).has_bridge).is_false()
	assert_int(view.road_segments.size()).is_equal(7)
	assert_array(Array(view.road_segments[0])).is_equal([_centre(1, 2), _centre(2, 2)])


func test_route_points_follow_the_route_in_either_direction() -> void:
	var view := MapLayoutView.build(_map_def().layout)

	var forward := view.route_points("p", "f")
	var backward := view.route_points("f", "p")

	assert_int(forward.size()).is_equal(4)
	assert_object(forward[0]).is_equal(_centre(1, 2))
	assert_object(forward[-1]).is_equal(_centre(4, 2))
	assert_object(backward[0]).is_equal(_centre(4, 2))
	assert_int(view.route_points("p", "c").size()).is_equal(0)


func test_cell_at_finds_the_cell_under_a_point() -> void:
	var view := MapLayoutView.build(_map_def().layout)

	assert_object(view.cell_at(Vector2(130, 200))).is_equal(Vector2i(2, 3))
	assert_object(view.cell_at(Vector2(-5, 10))).is_equal(MapLayoutView.NO_CELL)
	assert_object(view.cell_at(Vector2(12 * 64 + 1, 10))).is_equal(MapLayoutView.NO_CELL)


func test_the_model_frames_the_whole_grid() -> void:
	var model := MapViewModel.build(_map_def())

	assert_object(model.bounds).is_equal(Rect2(-64, -64, 14 * 64, 7 * 64))


func test_lanes_and_edges_follow_their_routes() -> void:
	var model := MapViewModel.build(_map_def())

	var lane_points: PackedVector2Array = model.lane_paths[0].runs[0]
	# p-f is 4 cells, f-F 3, F-c 4; shared endpoints are not repeated: 4 + 2 + 3.
	assert_int(lane_points.size()).is_equal(9)
	assert_object(lane_points[1]).is_equal(_centre(2, 2))
	for segment in model.edge_segments:
		assert_int(segment.size()).is_greater_equal(3)


func test_a_pair_without_a_route_is_a_straight_line() -> void:
	var map_def = _map_def()
	map_def.layout.routes = map_def.layout.routes.filter(func(r): return r.label() != "p-f")

	var lane_points: PackedVector2Array = MapViewModel.build(map_def).lane_paths[0].runs[0]

	assert_object(lane_points[0]).is_equal(_centre(1, 2))
	assert_object(lane_points[1]).is_equal(_centre(4, 2))


func test_markers_carry_the_critical_flag() -> void:
	var model := MapViewModel.build(_map_def())
	var critical := model.markers.filter(func(m): return m.critical).map(func(m): return m.id)

	assert_array(critical).contains_exactly_in_any_order(["p", "c"])


func test_the_model_finds_cells_through_the_layout() -> void:
	var model := MapViewModel.build(_map_def())

	assert_object(model.cell_at(Vector2(130, 200))).is_equal(Vector2i(2, 3))
	assert_object(MapViewModel.build(MapDef.new()).cell_at(Vector2(1, 1))).is_equal(
		MapLayoutView.NO_CELL
	)

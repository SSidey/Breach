extends GdUnitTestSuite
## MapViewModel, per specs/18-map-viewer.md: what the map viewer draws, computed
## headlessly from a MapDef (markers, lane paths, edges, bounds, view-as filtering).

const MapViewModel = preload("res://presentation/map_view_model.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")
const FactionDef = preload("res://content/definitions/faction_def.gd")
const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"


func _node(id: String, at: Vector2, hidden_from: Array[String] = []) -> NodeDef:
	var node := NodeDef.new()
	node.id = id
	node.node_type = NodeDef.NodeType.NEUTRAL
	node.position = at
	node.hidden_from_faction_ids = hidden_from
	return node


func _lane(id: String, nodes: Array[NodeDef]) -> LaneDef:
	var lane := LaneDef.new()
	lane.id = id
	lane.nodes = nodes
	return lane


func _edge(a: String, b: String) -> MapEdgeDef:
	var edge := MapEdgeDef.new()
	edge.node_a_id = a
	edge.node_b_id = b
	return edge


func _faction(id: String) -> FactionDef:
	var faction := FactionDef.new()
	faction.id = id
	faction.display_name = id
	return faction


## Lane main: a, b, c. Edge b <-> x, where x is off-lane. b is hidden from "kingdom".
func _map(b_hidden: bool = false) -> MapDef:
	var hidden: Array[String] = []
	if b_hidden:
		hidden.append("kingdom")
	var a := _node("a", Vector2(32, 32))
	var b := _node("b", Vector2(160, 32), hidden)
	var c := _node("c", Vector2(416, 224))
	var x := _node("x", Vector2(160, 160))
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_lane("main", [a, b, c] as Array[NodeDef])]
	map.lanes = lanes
	var off: Array[NodeDef] = [x]
	map.off_lane_nodes = off
	var edges: Array[MapEdgeDef] = [_edge("b", "x")]
	map.edges = edges
	var factions: Array[FactionDef] = [_faction("player"), _faction("kingdom")]
	map.factions = factions
	return map


func _ids(model: MapViewModel) -> Array:
	return model.markers.map(func(m): return m.id)


func _marker(model: MapViewModel, id: String):
	for marker in model.markers:
		if marker.id == id:
			return marker
	return null


func test_shared_nodes_get_one_marker_and_off_lane_nodes_are_flagged() -> void:
	var map := _map()
	var home := map.lanes[0].nodes[0]
	var d := _node("d", Vector2(32, 160))
	var second: Array[LaneDef] = [map.lanes[0], _lane("side", [home, d] as Array[NodeDef])]
	map.lanes = second

	var model := MapViewModel.build(map)

	assert_array(_ids(model)).contains_exactly_in_any_order(["a", "b", "c", "d", "x"])
	assert_bool(_marker(model, "x").on_lane).is_false()
	assert_bool(_marker(model, "a").on_lane).is_true()


func test_lane_paths_follow_node_order_and_edges_resolve_to_positions() -> void:
	var model := MapViewModel.build(_map())

	assert_int(model.lane_paths.size()).is_equal(1)
	assert_str(model.lane_paths[0].id).is_equal("main")
	assert_array(model.lane_paths[0].runs).is_equal(
		[PackedVector2Array([Vector2(32, 32), Vector2(160, 32), Vector2(416, 224)])]
	)
	assert_array(model.edge_segments).is_equal(
		[PackedVector2Array([Vector2(160, 32), Vector2(160, 160)])]
	)


## Nodes sit at cell centres, so bounds snap outward to whole cells (the cells the
## outermost nodes are in) plus one cell of margin; the grid then never shows a half cell.
func test_bounds_cover_whole_cells_around_the_markers_plus_one_cell() -> void:
	var model := MapViewModel.build(_map())  # nodes span (32,32)..(416,224)

	assert_object(model.bounds).is_equal(Rect2(Vector2(-64, -64), Vector2(576, 384)))


func test_bounds_edges_fall_on_cell_boundaries() -> void:
	var bounds := MapViewModel.build(_map()).bounds

	for edge in [bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]:
		assert_float(fposmod(edge, MapViewModel.CELL)).is_equal(0.0)


func test_an_empty_map_gets_the_default_bounds() -> void:
	var model := MapViewModel.build(MapDef.new())

	assert_array(model.markers).is_empty()
	assert_object(model.bounds).is_equal(MapViewModel.DEFAULT_BOUNDS)


func test_designer_view_shows_hidden_nodes_with_a_badge() -> void:
	var model := MapViewModel.build(_map(true))

	assert_bool(_marker(model, "b").hidden_badge).is_true()
	assert_bool(_marker(model, "a").hidden_badge).is_false()
	assert_int(model.edge_segments.size()).is_equal(1)


func test_viewing_as_a_faction_drops_what_it_does_not_know_about() -> void:
	var model := MapViewModel.build(_map(true), "kingdom")

	assert_array(_ids(model)).contains_exactly_in_any_order(["a", "c", "x"])
	assert_array(model.edge_segments).is_empty()
	assert_array(model.lane_paths[0].runs).is_equal(
		[PackedVector2Array([Vector2(32, 32)]), PackedVector2Array([Vector2(416, 224)])]
	)


func test_viewing_as_a_faction_the_node_is_not_hidden_from_shows_it_without_a_badge() -> void:
	var model := MapViewModel.build(_map(true), "player")

	assert_array(_ids(model)).contains("b")
	assert_bool(_marker(model, "b").hidden_badge).is_false()


func test_owner_colour_follows_the_faction_roster() -> void:
	var model := MapViewModel.build(_map())
	var palette: Array[Color] = [Color.RED, Color.BLUE]

	assert_object(model.faction_color("player", palette, Color.GRAY)).is_equal(Color.RED)
	assert_object(model.faction_color("kingdom", palette, Color.GRAY)).is_equal(Color.BLUE)
	assert_object(model.faction_color("", palette, Color.GRAY)).is_equal(Color.GRAY)
	assert_object(model.faction_color("nobody", palette, Color.GRAY)).is_equal(Color.GRAY)


func test_owner_colour_wraps_over_a_short_palette() -> void:
	var model := MapViewModel.build(_map())
	var palette: Array[Color] = [Color.RED]

	assert_object(model.faction_color("kingdom", palette, Color.GRAY)).is_equal(Color.RED)


func test_node_at_finds_the_nearest_visible_node_within_the_radius() -> void:
	var model := MapViewModel.build(_map(true), "kingdom")

	assert_str(model.node_at(Vector2(40, 36), 24.0)).is_equal("a")
	assert_str(model.node_at(Vector2(96, 32), 24.0)).is_equal("")
	assert_str(model.node_at(Vector2(160, 32), 24.0)).is_equal("")  # b is hidden


func test_builds_from_an_imported_designer_map() -> void:
	var export_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO_PATH))
	var map_def := DesignerMapImporter.import_map(export_data).map_def

	var model := MapViewModel.build(map_def)

	assert_array(_ids(model)).contains_exactly_in_any_order(["p", "f", "F", "c", "s2", "w1"])
	assert_int(model.lane_paths.size()).is_equal(1)
	assert_int(model.edge_segments.size()).is_equal(3)

extends GdUnitTestSuite
## MapLayoutDef, TileDef, BridgeDef, RoadSegmentDef and RouteDef, per
## specs/19-map-layout-and-objectives.md: a map's grid, tiles, roads and link routes.

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainFeatureDef = preload("res://content/definitions/terrain_feature_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const TileDef = preload("res://content/definitions/tile_def.gd")
const BridgeDef = preload("res://content/definitions/bridge_def.gd")
const RoadSegmentDef = preload("res://content/definitions/road_segment_def.gd")
const RouteDef = preload("res://content/definitions/route_def.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const NODES := ["a", "b"]


func _terrain(id: String, base: bool, needs_bridge: bool, stability: int) -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.id = id
	terrain.can_be_base = base
	terrain.needs_bridge = needs_bridge
	terrain.default_stability = stability
	terrain.default_max_width = 1
	return terrain


func _library() -> TerrainLibraryDef:
	var library := TerrainLibraryDef.new()
	var terrains: Array[TerrainDef] = [
		_terrain("FIELDS", true, false, 4),
		_terrain("FOREST", true, false, 2),
		_terrain("WATER", false, true, 0),
	]
	library.terrains = terrains
	var ore := TerrainFeatureDef.new()
	ore.id = "ORE"
	var features: Array[TerrainFeatureDef] = [ore]
	library.features = features
	return library


func _tile(col: int, row: int, terrain_id: String = "") -> TileDef:
	var tile := TileDef.new()
	tile.cell = Vector2i(col, row)
	tile.terrain_id = terrain_id
	return tile


func _layout(tiles: Array[TileDef] = []) -> MapLayoutDef:
	var layout := MapLayoutDef.new()
	layout.cols = 6
	layout.rows = 4
	layout.default_terrain_id = "FIELDS"
	layout.terrain_library = _library()
	layout.tiles = tiles
	return layout


func _road(a: Vector2i, b: Vector2i) -> RoadSegmentDef:
	var road := RoadSegmentDef.new()
	road.a = a
	road.b = b
	return road


func _route(cells: Array[Vector2i], a: String = "a", b: String = "b") -> RouteDef:
	var route := RouteDef.new()
	route.node_a_id = a
	route.node_b_id = b
	route.cells = cells
	return route


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_plain_layout_validates() -> void:
	var tiles: Array[TileDef] = [_tile(1, 1, "FOREST"), _tile(2, 1)]

	assert_array(_layout(tiles).validate(NODES)).is_empty()


func test_terrain_at_falls_back_to_the_default_terrain() -> void:
	var layout := _layout([_tile(1, 1, "FOREST")] as Array[TileDef])

	assert_str(layout.terrain_id_at(Vector2i(1, 1))).is_equal("FOREST")
	assert_str(layout.terrain_id_at(Vector2i(3, 3))).is_equal("FIELDS")
	assert_object(layout.tile_at(Vector2i(1, 1))).is_not_null()
	assert_object(layout.tile_at(Vector2i(3, 3))).is_null()


func test_effective_capacity_uses_overrides_and_terrain_defaults() -> void:
	var tile := _tile(1, 1, "FOREST")
	tile.max_width = 4

	var capacity := tile.effective_capacity(_library(), "FIELDS")

	assert_int(capacity["stability"]).is_equal(2)
	assert_int(capacity["max_width"]).is_equal(4)


func test_grid_and_default_terrain_are_checked() -> void:
	var layout := _layout()
	layout.cols = 0
	layout.default_terrain_id = "WATER"

	var errors := layout.validate(NODES)

	assert_bool(_any(errors, "cols")).is_true()
	assert_bool(_any(errors, "default_terrain_id 'WATER'")).is_true()


func test_tiles_must_be_inside_the_grid_unique_and_reference_the_library() -> void:
	var feature_tile := _tile(2, 2)
	feature_tile.feature_id = "GOLD"
	var tiles: Array[TileDef] = [
		_tile(9, 1), _tile(1, 1), _tile(1, 1), _tile(3, 3, "LAVA"), feature_tile
	]

	var errors := _layout(tiles).validate(NODES)

	assert_bool(_any(errors, "tile (9, 1) is outside the 6x4 grid")).is_true()
	assert_bool(_any(errors, "duplicate tile at (1, 1)")).is_true()
	assert_bool(_any(errors, "unknown terrain 'LAVA'")).is_true()
	assert_bool(_any(errors, "unknown feature 'GOLD'")).is_true()


func test_capacity_overrides_and_upgrades_are_checked() -> void:
	var tile := _tile(1, 1)
	tile.stability = -2
	tile.upgrade_slots = 1
	var upgrades: Array[String] = ["BARRACKS", "MILL"]
	tile.upgrade_ids = upgrades

	var errors := _layout([tile] as Array[TileDef]).validate(NODES)

	assert_bool(_any(errors, "stability")).is_true()
	assert_bool(_any(errors, "2 upgrades exceed 1 slot")).is_true()


func test_bridges_need_bridgeable_terrain_and_a_real_drawbridge_node() -> void:
	var on_fields := _tile(1, 1)
	on_fields.bridge = BridgeDef.new()
	var drawbridge := _tile(2, 1, "WATER")
	drawbridge.bridge = BridgeDef.new()
	drawbridge.bridge.drawbridge_node_id = "nobody"

	var errors := _layout([on_fields, drawbridge] as Array[TileDef]).validate(NODES)

	assert_bool(_any(errors, "bridge at (1, 1)")).is_true()
	assert_bool(_any(errors, "drawbridge_node_id 'nobody'")).is_true()


func test_roads_join_neighbouring_cells_inside_the_grid_once() -> void:
	var layout := _layout()
	var roads: Array[RoadSegmentDef] = [
		_road(Vector2i(0, 0), Vector2i(1, 1)),
		_road(Vector2i(1, 1), Vector2i(0, 0)),
		_road(Vector2i(0, 0), Vector2i(2, 0)),
		_road(Vector2i(5, 3), Vector2i(6, 3)),
	]
	layout.roads = roads

	var errors := layout.validate(NODES)

	assert_bool(_any(errors, "duplicate road (1, 1)-(0, 0)")).is_true()
	assert_bool(_any(errors, "road (0, 0)-(2, 0) must join neighbouring cells")).is_true()
	assert_bool(_any(errors, "road (5, 3)-(6, 3) leaves the grid")).is_true()


func test_routes_are_contiguous_inside_the_grid_between_real_nodes() -> void:
	var layout := _layout()
	var routes: Array[RouteDef] = [
		_route([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i]),
		_route([Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]),
		_route([Vector2i(0, 0)] as Array[Vector2i], "a", "ghost"),
	]
	layout.routes = routes

	var errors := layout.validate(NODES)

	assert_int(errors.size()).is_equal(2)
	assert_bool(_any(errors, "route a-b has a gap between (0, 0) and (2, 0)")).is_true()
	assert_bool(_any(errors, "route a-ghost: unknown node 'ghost'")).is_true()

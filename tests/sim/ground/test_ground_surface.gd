extends GdUnitTestSuite
## The ground surface, per Decision 56 and specs/23-ground-model.md (round 2): each cell
## column's surface is interpolated from tile elevations, the surface cell holds the part
## of a cell below it (corner heights in quarters), digging it removes only that part, a
## step of more than one cell is a cliff, and ground at the ceiling is capped.

const GroundSurface = preload("res://sim/ground/ground_surface.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const TileDef = preload("res://content/definitions/tile_def.gd")
const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")


## A row of tiles with these elevations (the default terrain sits at 0).
func _surface(elevations: Array, ceiling: int = 64) -> GroundSurface:
	var terrain := TerrainDef.new()
	terrain.id = "FIELDS"
	var library := TerrainLibraryDef.new()
	library.terrains = [terrain]
	var layout := MapLayoutDef.new()
	layout.cols = elevations.size()
	layout.rows = 1
	layout.default_terrain_id = "FIELDS"
	layout.terrain_library = library
	layout.ceiling = ceiling
	for col in range(elevations.size()):
		var tile := TileDef.new()
		tile.cell = Vector2i(col, 0)
		tile.elevation = elevations[col]
		layout.tiles.append(tile)
	return GroundSurface.new(layout)


func test_flat_ground_has_full_surface_cells_just_below_its_height() -> void:
	var ground := _surface([4, 4])

	assert_int(ground.surface_level(Vector2i(20, 5))).is_equal(3)
	assert_array(Array(ground.surface_shape(Vector2i(20, 5)))).is_equal([4, 4, 4, 4])
	assert_float(ground.surface_height(Vector2i(20, 5))).is_equal(4.0)


func test_a_tile_is_64_cells_across() -> void:
	var ground := _surface([0, 64], 128)

	assert_int(MapLayoutDef.CELLS_PER_TILE).is_equal(64)
	assert_float(ground.surface_height(Vector2i(96, 0))).is_equal(64.0)  # tile 1's centre


func test_a_slope_runs_through_partial_cells() -> void:
	var ground := _surface([0, 16])  # a quarter of a cell per cell, between the tile centres

	assert_int(ground.surface_level(Vector2i(32, 0))).is_equal(0)
	assert_array(Array(ground.surface_shape(Vector2i(32, 0)))).is_equal([0, 1, 1, 0])
	assert_float(ground.surface_height(Vector2i(32, 0))).is_equal(0.125)


func test_digging_a_surface_cell_removes_only_what_is_left_of_it() -> void:
	var ground := _surface([0, 16])

	assert_float(ground.dig_fraction(Vector2i(32, 0))).is_equal(0.125)  # an eighth of a cell is left
	assert_float(_surface([4, 4]).dig_fraction(Vector2i(32, 0))).is_equal(1.0)


func test_a_steep_rise_is_a_cliff_and_a_gentle_one_is_not() -> void:
	var steep := _surface([0, 192], 256)  # three cells per cell
	var gentle := _surface([0, 64], 128)  # one cell per cell

	assert_bool(steep.is_cliff(Vector2i(40, 0), Vector2i(41, 0))).is_true()
	assert_bool(gentle.is_cliff(Vector2i(40, 0), Vector2i(41, 0))).is_false()


func test_the_surface_is_level_beyond_the_outermost_tile_centres() -> void:
	var ground := _surface([0, 64], 128)

	assert_float(ground.surface_height(Vector2i(2, 0))).is_equal(0.0)
	assert_float(ground.surface_height(Vector2i(116, 0))).is_equal(64.0)


func test_ground_at_the_ceiling_is_capped() -> void:
	var ground := _surface([8, 80], 64)

	assert_bool(ground.is_capped(Vector2i(120, 0))).is_true()
	assert_bool(ground.is_capped(Vector2i(1, 0))).is_false()

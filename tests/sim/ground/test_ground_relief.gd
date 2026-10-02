extends GdUnitTestSuite
## Relief and carved channels, per Decision 59 and specs/23-ground-model.md (round 3):
## seeded relief per terrain on top of the tile elevation, so hilly tiles are hilly
## within; channels (rivers, ditches, moats) carved along a path of tiles to a width and
## depth, holding a liquid to a level; a negative depth raises a bank or mound.

const GroundSurface = preload("res://sim/ground/ground_surface.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const TileDef = preload("res://content/definitions/tile_def.gd")
const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const ChannelDef = preload("res://content/definitions/channel_def.gd")


## Three tiles in a row at elevation 8 of a terrain with this relief.
func _layout(amplitude: int, scale: int, seed: int = 7) -> MapLayoutDef:
	var terrain := TerrainDef.new()
	terrain.id = "HILLY"
	terrain.default_elevation = 8
	terrain.relief_amplitude = amplitude
	terrain.relief_scale = scale
	var library := TerrainLibraryDef.new()
	library.terrains = [terrain]
	var layout := MapLayoutDef.new()
	layout.cols = 3
	layout.rows = 1
	layout.default_terrain_id = "HILLY"
	layout.terrain_library = library
	layout.seed = seed
	return layout


func _channel(depth: int, liquid: String = "", liquid_depth: int = 0) -> ChannelDef:
	var channel := ChannelDef.new()
	channel.tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	channel.width = 4
	channel.depth = depth
	channel.liquid_id = liquid
	channel.liquid_depth = liquid_depth
	return channel


func _heights(ground: GroundSurface) -> Array:
	var out := []
	for x in range(16, 32):
		for y in range(16):
			out.append(ground.surface_height(Vector2i(x, y)))
	return out


func test_no_relief_leaves_the_tile_elevation() -> void:
	var ground := GroundSurface.new(_layout(0, 0))

	assert_float(ground.surface_height(Vector2i(20, 5))).is_equal(8.0)


func test_relief_makes_a_hilly_tile_hilly_within() -> void:
	var heights := _heights(GroundSurface.new(_layout(4, 6)))

	assert_float(heights.max() - heights.min()).is_greater(1.0)


func test_relief_stays_within_its_amplitude() -> void:
	for height in _heights(GroundSurface.new(_layout(4, 6))):
		assert_float(height).is_between(4.0, 12.0)


func test_relief_is_the_same_for_the_same_seed_and_differs_for_another() -> void:
	var first := _heights(GroundSurface.new(_layout(4, 6, 7)))

	assert_array(_heights(GroundSurface.new(_layout(4, 6, 7)))).is_equal(first)
	assert_array(_heights(GroundSurface.new(_layout(4, 6, 8)))).is_not_equal(first)


func test_a_channel_carves_its_depth_along_its_path() -> void:
	var layout := _layout(0, 0)
	layout.channels = [_channel(3)]
	var ground := GroundSurface.new(layout)

	assert_float(ground.surface_height(Vector2i(24, 8))).is_equal(5.0)  # on the line
	assert_float(ground.surface_height(Vector2i(24, 11))).is_equal(8.0)  # beyond its width


func test_a_channel_holds_its_liquid_to_a_level() -> void:
	var layout := _layout(0, 0)
	layout.channels = [_channel(3, "WATER", 2)]
	var ground := GroundSurface.new(layout)

	assert_dict(ground.liquid_at(Vector2i(24, 8))).is_equal({"material": "WATER", "level": 7.0})
	assert_dict(ground.liquid_at(Vector2i(24, 12))).is_empty()


func test_a_negative_depth_raises_a_bank() -> void:
	var layout := _layout(0, 0)
	layout.channels = [_channel(-2)]

	assert_float(GroundSurface.new(layout).surface_height(Vector2i(24, 8))).is_equal(10.0)

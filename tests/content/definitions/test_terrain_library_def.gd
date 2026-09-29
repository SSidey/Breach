extends GdUnitTestSuite
## TerrainLibraryDef / TerrainDef / TerrainFeatureDef, per
## specs/19-map-layout-and-objectives.md: the one shared terrain library every map uses.

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainFeatureDef = preload("res://content/definitions/terrain_feature_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")


func _terrain(id: String, base: bool = true, move_cost: float = 1.0) -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.id = id
	terrain.display_name = id.capitalize()
	terrain.can_be_base = base
	terrain.move_cost = move_cost
	return terrain


func _feature(id: String) -> TerrainFeatureDef:
	var feature := TerrainFeatureDef.new()
	feature.id = id
	return feature


func _library(
	terrains: Array[TerrainDef], features: Array[TerrainFeatureDef] = []
) -> TerrainLibraryDef:
	var library := TerrainLibraryDef.new()
	library.terrains = terrains
	library.features = features
	library.road_move_multiplier = 0.5
	return library


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_library_with_a_base_terrain_and_unique_ids_validates() -> void:
	var library := _library([_terrain("FIELDS"), _terrain("WATER", false)], [_feature("ORE")])

	assert_array(library.validate()).is_empty()


func test_lookups_find_entries_by_id() -> void:
	var library := _library([_terrain("FIELDS"), _terrain("WATER", false)], [_feature("ORE")])

	assert_str(library.terrain("WATER").id).is_equal("WATER")
	assert_str(library.feature("ORE").id).is_equal("ORE")
	assert_object(library.terrain("LAVA")).is_null()
	assert_object(library.feature("")).is_null()


func test_duplicate_or_empty_ids_are_errors() -> void:
	var library := _library(
		[_terrain("FIELDS"), _terrain("FIELDS"), _terrain("")], [_feature("ORE"), _feature("ORE")]
	)

	var errors := library.validate()

	assert_bool(_any(errors, "duplicate terrain id 'FIELDS'")).is_true()
	assert_bool(_any(errors, "terrain id must not be empty")).is_true()
	assert_bool(_any(errors, "duplicate feature id 'ORE'")).is_true()


func test_a_library_needs_at_least_one_base_terrain() -> void:
	var errors := _library([_terrain("WATER", false)]).validate()

	assert_bool(_any(errors, "can_be_base")).is_true()


func test_negative_costs_are_errors() -> void:
	var library := _library([_terrain("FIELDS", true, -1.0)])
	library.road_move_multiplier = -0.5

	var errors := library.validate()

	assert_bool(_any(errors, "move_cost")).is_true()
	assert_bool(_any(errors, "road_move_multiplier")).is_true()

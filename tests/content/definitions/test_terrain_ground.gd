extends GdUnitTestSuite
## The ground model in the terrain library, per Decisions 53, 54 and 57: materials (dig
## and climb difficulty, weight, span), and each terrain's bearing, foundation maximum,
## dig depth and strata bands, which name materials. Liquid bodies: test_terrain_liquids.gd.

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const StratumDef = preload("res://content/definitions/stratum_def.gd")


func _material(id: String) -> MaterialDef:
	var material := MaterialDef.new()
	material.id = id
	return material


func _stratum(material_id: String, min_cells: int, max_cells: int) -> StratumDef:
	var stratum := StratumDef.new()
	stratum.material_id = material_id
	stratum.min_cells = min_cells
	stratum.max_cells = max_cells
	return stratum


func _library(terrain: TerrainDef) -> TerrainLibraryDef:
	var library := TerrainLibraryDef.new()
	library.materials = [_material("SOIL"), _material("ROCK")]
	library.terrains = [terrain]
	return library


func _fields() -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.id = "FIELDS"
	terrain.bearing = 4
	terrain.foundation_max = 8
	terrain.dig_depth = 32
	terrain.strata = [_stratum("SOIL", 2, 4), _stratum("ROCK", 4, 8)]
	return terrain


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_terrain_with_strata_of_known_materials_validates() -> void:
	assert_array(Array(_library(_fields()).validate())).is_empty()


func test_the_library_finds_a_material_by_id() -> void:
	assert_str(_library(_fields()).material("ROCK").id).is_equal("ROCK")
	assert_object(_library(_fields()).material("MAGMA")).is_null()


func test_a_stratum_naming_an_unknown_material_is_an_error() -> void:
	var terrain := _fields()
	terrain.strata.append(_stratum("MAGMA", 1, 2))

	assert_bool(_any(_library(terrain).validate(), "unknown material 'MAGMA'")).is_true()


func test_a_stratum_thinner_at_most_than_at_least_is_an_error() -> void:
	var terrain := _fields()
	terrain.strata = [_stratum("SOIL", 4, 2)]

	assert_bool(_any(_library(terrain).validate(), "min_cells 4 > max_cells 2")).is_true()


func test_foundations_cannot_lower_bearing() -> void:
	var terrain := _fields()
	terrain.foundation_max = 2

	assert_bool(_any(_library(terrain).validate(), "foundation_max 2 < bearing 4")).is_true()


func test_a_terrain_without_strata_is_valid() -> void:
	var terrain := _fields()
	terrain.strata = []

	assert_array(Array(_library(terrain).validate())).is_empty()


func test_duplicate_material_ids_are_errors() -> void:
	var library := _library(_fields())
	library.materials.append(_material("ROCK"))

	assert_bool(_any(library.validate(), "duplicate material id 'ROCK'")).is_true()

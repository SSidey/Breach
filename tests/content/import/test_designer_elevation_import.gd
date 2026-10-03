extends GdUnitTestSuite
## Elevation import, per Decision 56 and specs/23-ground-model.md (round 2): a tile's
## elevation override, the map's ceiling, and a terrain's default elevation.

const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")
const DesignerLibraryImporter = preload("res://content/import/designer_library_importer.gd")

const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


func _export() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))


func test_a_tiles_elevation_and_the_maps_ceiling_import() -> void:
	var export_data := _export()
	export_data["ceiling"] = 48
	var tile: Dictionary = export_data["tiles"][0]
	tile["elevation_override"] = 12
	var cell := Vector2i(int(tile["grid_position"]["col"]), int(tile["grid_position"]["row"]))

	var layout = DesignerMapImporter.import_map(export_data).map_def.layout

	assert_int(layout.ceiling).is_equal(48)
	assert_int(layout.elevation_at(cell)).is_equal(12)


func test_an_export_without_elevation_keeps_the_defaults() -> void:
	var layout = DesignerMapImporter.import_map(_export()).map_def.layout

	assert_int(layout.ceiling).is_equal(64)
	assert_int(layout.tiles[0].elevation).is_equal(-1)


func test_a_terrains_default_elevation_imports() -> void:
	var library_data := {"terrains": [{"id": "HILLY", "default_elevation": 8}]}

	var hills = DesignerLibraryImporter.import_library(library_data).library.terrain("HILLY")

	assert_int(hills.default_elevation).is_equal(8)

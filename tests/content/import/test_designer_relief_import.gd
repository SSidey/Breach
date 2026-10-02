extends GdUnitTestSuite
## Relief and channel import, per Decision 59: a terrain's relief, the map's seed, and
## channels along tile paths.

const DesignerMapImporter = preload("res://content/import/designer_map_importer.gd")
const DesignerLibraryImporter = preload("res://content/import/designer_library_importer.gd")

const LAYOUT_PATH := "res://tests/fixtures/designer/layout_map.designer.json"


func _export() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))


func test_a_terrains_relief_imports() -> void:
	var library_data := {"terrains": [{"id": "HILLY", "relief": {"amplitude": 4, "scale": 6}}]}

	var hills = DesignerLibraryImporter.import_library(library_data).library.terrain("HILLY")

	assert_int(hills.relief_amplitude).is_equal(4)
	assert_int(hills.relief_scale).is_equal(6)


func test_the_seed_and_channels_import() -> void:
	var export_data := _export()
	export_data["seed"] = 1234
	export_data["channels"] = [
		{
			"tiles": [{"row": 0, "col": 0}, {"row": 0, "col": 1}],
			"width": 4,
			"depth": 3,
			"liquid": "WATER",
			"liquid_depth": 2
		}
	]

	var result = DesignerMapImporter.import_map(export_data)
	var layout = result.map_def.layout

	assert_int(layout.seed).is_equal(1234)
	assert_array(layout.channels[0].tiles).is_equal([Vector2i(0, 0), Vector2i(1, 0)])
	assert_int(layout.channels[0].depth).is_equal(3)
	assert_str(layout.channels[0].liquid_id).is_equal("WATER")
	assert_array(Array(result.errors)).is_empty()


func test_an_export_without_them_has_seed_zero_and_no_channels() -> void:
	var layout = DesignerMapImporter.import_map(_export()).map_def.layout

	assert_int(layout.seed).is_equal(0)
	assert_array(layout.channels).is_empty()

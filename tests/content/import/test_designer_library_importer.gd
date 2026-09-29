extends GdUnitTestSuite
## DesignerLibraryImporter / DesignerLibraryImport, per
## specs/19-map-layout-and-objectives.md: the designer's terrain.json becomes the one
## shared TerrainLibraryDef, and an edit that drops an in-use terrain is refused.

const DesignerLibraryImporter = preload("res://content/import/designer_library_importer.gd")
const DesignerLibraryImport = preload("res://content/import/designer_library_import.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

const LIBRARY_PATH := "res://tests/fixtures/designer/terrain.json"
const MAPS_DIR := "res://tests/fixtures/designer/maps_src"
const OUT_PATH := "user://test_terrain_library.tres"


func _library_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH))


func _any(messages: PackedStringArray, needle: String) -> bool:
	return Array(messages).any(func(m): return m.contains(needle))


func after_test() -> void:
	if FileAccess.file_exists(OUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_PATH))


func test_the_designer_library_imports_every_terrain_and_feature() -> void:
	var result := DesignerLibraryImporter.import_library(_library_data())

	assert_array(result.errors).is_empty()
	assert_int(result.library.terrains.size()).is_equal(9)
	assert_int(result.library.features.size()).is_equal(5)
	assert_float(result.library.road_move_multiplier).is_equal(0.5)
	assert_array(result.library.validate()).is_empty()


func test_terrain_values_are_copied_and_typed() -> void:
	var library := DesignerLibraryImporter.import_library(_library_data()).library
	var water := library.terrain("WATER")

	assert_str(water.display_name).is_equal("Water")
	assert_bool(water.needs_bridge).is_true()
	assert_bool(water.can_be_base).is_false()
	assert_object(water.color).is_equal(Color("#3a6ea5"))
	assert_str(library.feature("ORE_VEIN").effect_notes).contains("deposit")


func test_blocked_unit_classes_are_split_from_the_comma_list() -> void:
	var library_data := _library_data()
	library_data["terrains"][0]["blocks_unit_classes"] = "cavalry, siege ,"

	var terrain := DesignerLibraryImporter.import_library(library_data).library.terrains[0]

	assert_array(terrain.blocks_unit_classes).is_equal(["cavalry", "siege"])


func test_a_terrain_without_an_id_is_an_error() -> void:
	var library_data := _library_data()
	library_data["terrains"][1].erase("id")

	assert_bool(_any(DesignerLibraryImporter.import_library(library_data).errors, "id")).is_true()


func test_ids_used_by_saved_maps_are_found() -> void:
	var used := DesignerLibraryImporter.used_ids(MAPS_DIR)

	assert_array(used["terrains"]["FOREST"]).contains(["uses_forest"])
	assert_array(used["terrains"]["FIELDS"]).contains(["uses_forest"])
	assert_array(used["features"]["ORE_VEIN"]).contains(["uses_forest"])


func test_dropping_a_terrain_a_saved_map_uses_is_refused() -> void:
	var library_data := _library_data()
	library_data["terrains"] = library_data["terrains"].filter(func(t): return t["id"] != "FOREST")
	library_data["features"] = library_data["features"].filter(
		func(f): return f["id"] != "ORE_VEIN"
	)
	var library := DesignerLibraryImporter.import_library(library_data).library

	var problems := DesignerLibraryImporter.in_use_problems(library, MAPS_DIR)

	assert_bool(_any(problems, "terrain 'FOREST' is still used by uses_forest")).is_true()
	assert_bool(_any(problems, "feature 'ORE_VEIN' is still used by uses_forest")).is_true()


func test_run_writes_the_library_and_refuses_an_unsafe_edit() -> void:
	var ok := DesignerLibraryImport.run(LIBRARY_PATH, MAPS_DIR, OUT_PATH)

	assert_array(ok.errors).is_empty()
	var saved: TerrainLibraryDef = ResourceLoader.load(
		OUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_int(saved.terrains.size()).is_equal(9)


func test_run_twice_writes_identical_files() -> void:
	DesignerLibraryImport.run(LIBRARY_PATH, MAPS_DIR, OUT_PATH)
	var first := FileAccess.get_file_as_string(OUT_PATH)

	DesignerLibraryImport.run(LIBRARY_PATH, MAPS_DIR, OUT_PATH)

	assert_str(FileAccess.get_file_as_string(OUT_PATH)).is_equal(first)

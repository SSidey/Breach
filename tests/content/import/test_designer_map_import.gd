extends GdUnitTestSuite
## DesignerMapImport.run(), the shared import-validate-save path behind the Inspector
## button and tools/import_designer_map.gd, per specs/16-designer-map-import.md. The
## button itself is engine glue (construction smoke test only); run() is testable
## headlessly by saving to user://.

const DesignerMapImport = preload("res://content/import/designer_map_import.gd")
const MapDef = preload("res://content/definitions/map_def.gd")

const DEMO_PATH := "res://tests/fixtures/designer/demo_map.designer.json"
const OUT_PATH := "user://test_designer_map_import.tres"


func after_test() -> void:
	if FileAccess.file_exists(OUT_PATH):
		DirAccess.remove_absolute(OUT_PATH)


func test_constructs() -> void:
	var importer: DesignerMapImport = auto_free(DesignerMapImport.new())
	assert_object(importer).is_not_null()


func test_run_saves_a_valid_map_that_loads_back() -> void:
	var result := DesignerMapImport.run(DEMO_PATH, OUT_PATH)

	assert_array(result.errors).is_empty()
	var loaded: MapDef = ResourceLoader.load(OUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(loaded).is_not_null()
	assert_array(loaded.validate()).is_empty()
	(
		assert_array(loaded.lanes[0].nodes.map(func(n): return n.id))
		. contains_exactly(["p", "f", "F", "c"])
	)


func test_reimport_is_byte_identical() -> void:
	DesignerMapImport.run(DEMO_PATH, OUT_PATH)
	var first := FileAccess.get_file_as_string(OUT_PATH)

	DesignerMapImport.run(DEMO_PATH, OUT_PATH)

	assert_str(FileAccess.get_file_as_string(OUT_PATH)).is_equal(first)


func test_errors_prevent_saving() -> void:
	var result := DesignerMapImport.run("res://tests/fixtures/designer/missing.json", OUT_PATH)

	assert_array(result.errors).is_not_empty()
	assert_bool(FileAccess.file_exists(OUT_PATH)).is_false()

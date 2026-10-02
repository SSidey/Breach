extends GdUnitTestSuite
## Importing the ground model from the designer's terrain.json, per Decisions 53, 54 and
## 57: the materials list, and each terrain's bearing, foundation maximum, dig depth,
## water table and strata. A library saved before the ground model still imports.

const DesignerLibraryImporter = preload("res://content/import/designer_library_importer.gd")


func _library() -> Dictionary:
	return {
		"materials":
		[
			{
				"id": "ROCK",
				"label": "Rock",
				"color": "#6f6c68",
				"dig_difficulty": 3,
				"climb_difficulty": 0,
				"weight": 2,
				"span": 4,
				"loose": false
			},
			{"id": "SAND", "label": "Sand", "dig_difficulty": 1, "span": 0, "loose": true}
		],
		"terrains":
		[
			{
				"id": "DESERT",
				"can_be_base": true,
				"bearing": 3,
				"foundation_max": 6,
				"dig_depth": 32,
				"water_table": {"min": 20, "max": 32},
				"strata":
				[
					{"material": "SAND", "min": 4, "max": 10},
					{"material": "ROCK", "min": 8, "max": 16}
				]
			},
			{"id": "OLD", "can_be_base": true}
		]
	}


func test_materials_import_with_their_properties() -> void:
	var library := DesignerLibraryImporter.import_library(_library()).library
	var rock = library.material("ROCK")

	assert_str(rock.display_name).is_equal("Rock")
	assert_int(rock.dig_difficulty).is_equal(3)
	assert_int(rock.weight).is_equal(2)
	assert_int(rock.span).is_equal(4)
	assert_bool(library.material("SAND").loose).is_true()


func test_a_terrains_ground_imports() -> void:
	var desert = DesignerLibraryImporter.import_library(_library()).library.terrain("DESERT")

	assert_int(desert.bearing).is_equal(3)
	assert_int(desert.foundation_max).is_equal(6)
	assert_int(desert.dig_depth).is_equal(32)
	assert_int(desert.water_table_min).is_equal(20)
	assert_int(desert.water_table_max).is_equal(32)
	assert_array(desert.strata.map(func(s): return s.material_id)).is_equal(["SAND", "ROCK"])
	assert_int(desert.strata[0].max_cells).is_equal(10)


func test_a_terrain_saved_before_the_ground_model_has_no_water_or_strata() -> void:
	var old = DesignerLibraryImporter.import_library(_library()).library.terrain("OLD")

	assert_int(old.water_table_min).is_equal(-1)
	assert_array(old.strata).is_empty()


func test_the_imported_library_validates() -> void:
	var result := DesignerLibraryImporter.import_library(_library())

	assert_array(Array(result.errors)).is_empty()
	assert_array(Array(result.library.validate())).is_empty()


func test_the_repos_library_has_a_ground_for_every_terrain() -> void:
	var library := (
		DesignerLibraryImporter.import_file("res://content/designer/terrain.json").library
	)

	assert_bool(library.materials.is_empty()).is_false()
	assert_array(Array(library.validate())).is_empty()
	for terrain in library.terrains:
		if terrain.can_be_base:
			assert_bool(terrain.strata.is_empty()).override_failure_message(terrain.id).is_false()

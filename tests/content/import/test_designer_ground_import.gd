extends GdUnitTestSuite
## Importing the ground model from the designer's terrain.json, per Decisions 53, 54 and
## 57: the materials list, and each terrain's bearing, foundation maximum, dig depth,
## strata and liquid bodies. A library saved before the ground model still imports, and
## one saved with a water table or a loose flag (before Decision 63) migrates.

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
				"traits": {}
			},
			{"id": "SAND", "label": "Sand", "dig_difficulty": 1, "span": 0, "loose": true}
		],
		"liquids": [{"id": "WATER", "label": "Water"}],
		"terrains":
		[
			{
				"id": "DESERT",
				"can_be_base": true,
				"bearing": 3,
				"foundation_max": 6,
				"dig_depth": 32,
				"liquids": [{"liquid": "WATER", "min": 20, "max": 32, "chance": 0.3}],
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
	assert_int(library.material("SAND").traits.get("loose", 0)).is_equal(1)  # the old flag


func test_a_terrains_ground_imports() -> void:
	var desert = DesignerLibraryImporter.import_library(_library()).library.terrain("DESERT")

	assert_int(desert.bearing).is_equal(3)
	assert_int(desert.foundation_max).is_equal(6)
	assert_int(desert.dig_depth).is_equal(32)
	assert_str(desert.liquids[0].liquid_id).is_equal("WATER")
	assert_int(desert.liquids[0].max_cells).is_equal(32)
	assert_float(desert.liquids[0].chance).is_equal(0.3)
	assert_array(desert.strata.map(func(s): return s.material_id)).is_equal(["SAND", "ROCK"])
	assert_int(desert.strata[0].max_cells).is_equal(10)


func test_a_terrain_saved_before_the_ground_model_has_no_liquids_or_strata() -> void:
	var old = DesignerLibraryImporter.import_library(_library()).library.terrain("OLD")

	assert_array(old.liquids).is_empty()
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


func test_a_water_table_saved_before_decision_63_becomes_a_water_body() -> void:
	var legacy := {"terrains": [{"id": "FIELDS", "water_table": {"min": 12, "max": 24}}]}

	var fields = DesignerLibraryImporter.import_library(legacy).library.terrain("FIELDS")

	assert_str(fields.liquids[0].liquid_id).is_equal("WATER")
	assert_int(fields.liquids[0].min_cells).is_equal(12)
	assert_float(fields.liquids[0].chance).is_equal(1.0)


func test_liquids_import_with_temperature_traits_and_transitions() -> void:
	var library_data := {
		"liquids":
		[
			{
				"id": "LAVA",
				"label": "Lava",
				"temperature": 1200,
				"traits": {"glows": 1},
				"heat_transitions": [{"below": 700, "becomes": "ROCK"}]
			}
		],
		"materials":
		[
			{"id": "TIMBER", "heat_transitions": [{"above": 300, "gains": "burning"}]},
			{"id": "ROCK"}
		],
		"terrains": [{"id": "FIELDS", "can_be_base": true}]
	}

	var library := DesignerLibraryImporter.import_library(library_data).library
	var lava = library.liquid("LAVA")

	assert_int(lava.temperature).is_equal(1200)
	assert_int(lava.traits["glows"]).is_equal(1)
	assert_str(lava.heat_transitions[0].describe()).is_equal("below 700: becomes ROCK")
	assert_str(library.material("TIMBER").heat_transitions[0].describe()).is_equal(
		"above 300: gains burning"
	)
	assert_array(Array(library.validate())).is_empty()

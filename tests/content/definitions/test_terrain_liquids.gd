extends GdUnitTestSuite
## Liquids and traits in the terrain library, per Decisions 62 and 63: a liquid library
## (water, lava) with temperatures; terrains list liquid bodies (a liquid, a depth range,
## a chance, a chance of reaching the surface); materials and liquids carry traits and
## heat transitions (above or below a temperature: become something, or gain a trait).

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const LiquidDef = preload("res://content/definitions/liquid_def.gd")
const LiquidBodyDef = preload("res://content/definitions/liquid_body_def.gd")
const HeatTransitionDef = preload("res://content/definitions/heat_transition_def.gd")


func _transition(
	threshold: int, rising: bool, becomes: String, gains: String = ""
) -> HeatTransitionDef:
	var transition := HeatTransitionDef.new()
	transition.threshold = threshold
	transition.rising = rising
	transition.becomes = becomes
	transition.gains_trait = gains
	return transition


func _body(liquid_id: String, min_cells: int, max_cells: int, chance: float) -> LiquidBodyDef:
	var body := LiquidBodyDef.new()
	body.liquid_id = liquid_id
	body.min_cells = min_cells
	body.max_cells = max_cells
	body.chance = chance
	return body


func _library() -> TerrainLibraryDef:
	var rock := MaterialDef.new()
	rock.id = "ROCK"
	rock.heat_transitions = [_transition(1100, true, "LAVA")]
	var timber := MaterialDef.new()
	timber.id = "TIMBER"
	timber.heat_transitions = [_transition(300, true, "", "burning")]
	var lava := LiquidDef.new()
	lava.id = "LAVA"
	lava.temperature = 1200
	lava.heat_transitions = [_transition(700, false, "ROCK")]
	var water := LiquidDef.new()
	water.id = "WATER"
	var mountain := TerrainDef.new()
	mountain.id = "MOUNTAIN"
	mountain.liquids = [_body("LAVA", 24, 48, 0.35)]
	var library := TerrainLibraryDef.new()
	library.materials = [rock, timber]
	library.liquids = [water, lava]
	library.terrains = [mountain]
	return library


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_library_of_liquids_bodies_and_transitions_validates() -> void:
	assert_array(Array(_library().validate())).is_empty()


func test_the_library_finds_a_liquid_by_id() -> void:
	assert_int(_library().liquid("LAVA").temperature).is_equal(1200)
	assert_object(_library().liquid("MERCURY")).is_null()


func test_a_body_of_an_unknown_liquid_is_an_error() -> void:
	var library := _library()
	library.terrains[0].liquids.append(_body("MERCURY", 1, 2, 0.5))

	assert_bool(_any(library.validate(), "unknown liquid 'MERCURY'")).is_true()


func test_a_chance_outside_zero_to_one_is_an_error() -> void:
	var library := _library()
	library.terrains[0].liquids[0].surface_chance = 1.5

	assert_bool(_any(library.validate(), "chance")).is_true()


func test_a_transition_becoming_an_unknown_thing_is_an_error() -> void:
	var library := _library()
	library.materials[0].heat_transitions = [_transition(1100, true, "GLASS")]

	assert_bool(_any(library.validate(), "becomes unknown 'GLASS'")).is_true()


func test_a_transition_must_become_something_or_gain_a_trait() -> void:
	var library := _library()
	library.materials[1].heat_transitions = [_transition(300, true, "")]

	assert_bool(_any(library.validate(), "becomes nothing and gains no trait")).is_true()


func test_a_transition_reads_as_its_rule() -> void:
	var library := _library()

	assert_str(library.materials[0].heat_transitions[0].describe()).is_equal(
		"above 1100: becomes LAVA"
	)
	assert_str(library.materials[1].heat_transitions[0].describe()).is_equal(
		"above 300: gains burning"
	)
	assert_str(library.liquid("LAVA").heat_transitions[0].describe()).is_equal(
		"below 700: becomes ROCK"
	)

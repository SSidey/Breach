extends GdUnitTestSuite
## Liquids, traits and heat in the terrain library, per Decisions 62-64: a liquid is a
## material that flows (flows N, its rate); terrains list liquid bodies of flowing
## materials (a depth range, a chance, a chance of reaching the surface); materials carry
## rated traits and heat transitions (above or below a temperature: become another
## material, or gain a trait).

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
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


func _body(material_id: String, min_cells: int, max_cells: int, chance: float) -> LiquidBodyDef:
	var body := LiquidBodyDef.new()
	body.material_id = material_id
	body.min_cells = min_cells
	body.max_cells = max_cells
	body.chance = chance
	return body


func _material(id: String, traits: Dictionary, transitions: Array = []) -> MaterialDef:
	var material := MaterialDef.new()
	material.id = id
	material.traits = traits
	material.heat_transitions.assign(transitions)
	return material


func _library() -> TerrainLibraryDef:
	var lava := _material("LAVA", {"flows": 1, "glows": 2}, [_transition(6, false, "ROCK")])
	lava.heat = 8
	var library := TerrainLibraryDef.new()
	library.materials = [
		_material("ROCK", {"dig_difficulty": 3}, [_transition(7, true, "LAVA")]),
		_material("TIMBER", {}, [_transition(3, true, "", "burning")]),
		_material("WATER", {"flows": 3}),
		lava,
	]
	var mountain := TerrainDef.new()
	mountain.id = "MOUNTAIN"
	mountain.liquids = [_body("LAVA", 24, 48, 0.35)]
	library.terrains = [mountain]
	return library


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_library_of_bodies_and_transitions_validates() -> void:
	assert_array(Array(_library().validate())).is_empty()


func test_a_trait_has_a_level_and_an_absent_trait_is_zero() -> void:
	var lava := _library().material("LAVA")

	assert_int(lava.trait_level("glows")).is_equal(2)
	assert_int(lava.trait_level("darksight")).is_equal(0)


func test_a_material_that_flows_is_a_liquid() -> void:
	assert_bool(_library().material("WATER").is_liquid()).is_true()
	assert_bool(_library().material("ROCK").is_liquid()).is_false()


func test_a_body_of_an_unknown_material_is_an_error() -> void:
	var library := _library()
	library.terrains[0].liquids.append(_body("MERCURY", 1, 2, 0.5))

	assert_bool(_any(library.validate(), "unknown material 'MERCURY'")).is_true()


func test_a_body_of_a_material_that_doesnt_flow_is_an_error() -> void:
	var library := _library()
	library.terrains[0].liquids.append(_body("ROCK", 1, 2, 0.5))

	assert_bool(_any(library.validate(), "'ROCK' doesn't flow")).is_true()


func test_a_chance_outside_zero_to_one_is_an_error() -> void:
	var library := _library()
	library.terrains[0].liquids[0].surface_chance = 1.5

	assert_bool(_any(library.validate(), "chance")).is_true()


func test_a_transition_becoming_an_unknown_material_is_an_error() -> void:
	var library := _library()
	library.materials[0].heat_transitions.assign([_transition(7, true, "GLASS")])

	assert_bool(_any(library.validate(), "becomes unknown 'GLASS'")).is_true()


func test_a_transition_must_become_something_or_gain_a_trait() -> void:
	var library := _library()
	library.materials[1].heat_transitions.assign([_transition(3, true, "")])

	assert_bool(_any(library.validate(), "becomes nothing and gains no trait")).is_true()


func test_a_transition_reads_as_its_rule() -> void:
	var library := _library()

	assert_str(library.material("ROCK").heat_transitions[0].describe()).is_equal(
		"above heat 7: becomes LAVA"
	)
	assert_str(library.material("TIMBER").heat_transitions[0].describe()).is_equal(
		"above heat 3: gains burning"
	)
	assert_str(library.material("LAVA").heat_transitions[0].describe()).is_equal(
		"below heat 6: becomes ROCK"
	)

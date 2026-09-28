extends GdUnitTestSuite

const FactionDef = preload("res://content/definitions/faction_def.gd")


func test_valid_faction_has_no_errors() -> void:
	var faction := FactionDef.new()
	faction.id = "the_kingdom"
	faction.display_name = "The Kingdom"

	assert_array(faction.validate()).is_empty()


func test_empty_id_is_invalid() -> void:
	var faction := FactionDef.new()
	faction.id = ""

	var errors := faction.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("id"))).is_true()

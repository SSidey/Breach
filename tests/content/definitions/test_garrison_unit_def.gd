extends GdUnitTestSuite

const GarrisonUnitDef = preload("res://content/definitions/garrison_unit_def.gd")


func test_valid_garrison_unit_has_no_errors() -> void:
	var unit := GarrisonUnitDef.new()
	unit.faction_id = "the_kingdom"

	assert_array(unit.validate()).is_empty()


func test_empty_faction_id_is_invalid() -> void:
	var unit := GarrisonUnitDef.new()
	unit.faction_id = ""

	var errors := unit.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("faction_id"))).is_true()

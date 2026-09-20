extends GdUnitTestSuite

const UnitDef = preload("res://content/definitions/unit_def.gd")


func test_valid_unit_def_has_no_errors() -> void:
	var unit := UnitDef.new()
	unit.cost_food = 5
	unit.hp = 10
	unit.dmg = 2
	unit.speed = 1.0

	assert_array(unit.validate()).is_empty()


func test_negative_hp_is_invalid() -> void:
	var unit := UnitDef.new()
	unit.cost_food = 5
	unit.hp = -1
	unit.dmg = 2
	unit.speed = 1.0

	var errors := unit.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("hp"))).is_true()

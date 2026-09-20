extends GdUnitTestSuite

const ResponseUnitDef = preload("res://content/definitions/response_unit_def.gd")


func test_valid_response_unit_def_has_no_errors() -> void:
	var response := ResponseUnitDef.new()
	response.purpose = "respond"
	response.hp = 20
	response.dmg = 5
	response.speed = 1.5

	assert_array(response.validate()).is_empty()


func test_negative_dmg_is_invalid() -> void:
	var response := ResponseUnitDef.new()
	response.purpose = "respond"
	response.hp = 20
	response.dmg = -5
	response.speed = 1.5

	var errors := response.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("dmg"))).is_true()


func test_empty_purpose_is_invalid() -> void:
	var response := ResponseUnitDef.new()
	response.purpose = ""
	response.hp = 20
	response.dmg = 5
	response.speed = 1.5

	var errors := response.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(message): return message.contains("purpose"))).is_true()

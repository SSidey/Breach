extends GdUnitTestSuite

const FactionRelationDef = preload("res://content/definitions/faction_relation_def.gd")


func _valid_relation() -> FactionRelationDef:
	var relation := FactionRelationDef.new()
	relation.faction_a_id = "player"
	relation.faction_b_id = "the_kingdom"
	relation.stance = FactionRelationDef.Stance.HOSTILE
	return relation


func test_valid_relation_has_no_errors() -> void:
	assert_array(_valid_relation().validate()).is_empty()


func test_self_relation_is_invalid() -> void:
	var relation := _valid_relation()
	relation.faction_b_id = relation.faction_a_id

	assert_array(relation.validate()).is_not_empty()


func test_empty_faction_a_id_is_invalid() -> void:
	var relation := _valid_relation()
	relation.faction_a_id = ""

	var errors := relation.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("faction_a_id"))).is_true()


func test_empty_faction_b_id_is_invalid() -> void:
	var relation := _valid_relation()
	relation.faction_b_id = ""

	var errors := relation.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("faction_b_id"))).is_true()

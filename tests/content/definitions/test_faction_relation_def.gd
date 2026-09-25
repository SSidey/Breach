extends GdUnitTestSuite

const FactionRelationDef = preload("res://content/definitions/faction_relation_def.gd")


func _valid_relation() -> FactionRelationDef:
	var relation := FactionRelationDef.new()
	relation.faction_a = FactionRelationDef.FactionId.PLAYER
	relation.faction_b = FactionRelationDef.FactionId.ENEMY
	relation.stance = FactionRelationDef.Stance.HOSTILE
	return relation


func test_valid_relation_has_no_errors() -> void:
	assert_array(_valid_relation().validate()).is_empty()


func test_self_relation_is_invalid() -> void:
	var relation := _valid_relation()
	relation.faction_b = relation.faction_a

	assert_array(relation.validate()).is_not_empty()

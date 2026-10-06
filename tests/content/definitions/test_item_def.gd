extends GdUnitTestSuite
## Items, per Decision 120 (spec 28): one group - weapons, armour, tools - each taking the
## slots it names on its carrier's body, with a weight, a strength needed and tags; a tool
## grants its traits to whoever carries it.

const ItemDef = preload("res://content/definitions/item_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _unit(slots: Array[String], items: Array[ItemDef]) -> UnitDef:
	var unit := UnitDef.new()
	unit.hp = 10
	unit.speed = 1.0
	unit.slots = slots
	unit.items = items
	return unit


func _item(item_name: String, slots: Array[String], traits := {}) -> ItemDef:
	var item := ItemDef.new()
	item.item_name = item_name
	item.slots = slots
	item.traits = traits
	return item


func test_items_fit_only_the_slots_a_body_has_free() -> void:
	var spear := WeaponDef.new()
	spear.item_name = "spear"
	spear.damage = 5
	spear.slots = ["hand", "hand"]

	assert_array(_unit(["hand", "hand"], [spear]).validate()).is_empty()
	var one_handed := _unit(["hand"], [spear]).validate()
	assert_bool(Array(one_handed).any(func(e): return e.contains("slots"))).is_true()
	var no_hands := _unit([], [_item("shovel", ["hand"])]).validate()
	assert_array(no_hands).is_not_empty()


func test_a_natural_weapon_takes_no_slot() -> void:
	var bite := WeaponDef.new()
	bite.item_name = "bite"
	bite.damage = 3

	assert_array(_unit([], [bite]).validate()).is_empty()


func test_a_tool_grants_its_traits_but_a_weapons_traits_are_its_own() -> void:
	var shovel := _item("shovel", ["hand"], {"burrower": 1})
	var ram := WeaponDef.new()
	ram.item_name = "ram"
	ram.traits = {"siege": 2}
	var unit := _unit(["hand"], [shovel, ram])
	unit.traits = {"burrower": 0, "climber": 2}

	assert_int(unit.trait_level("burrower")).is_equal(1)
	assert_int(unit.trait_level("climber")).is_equal(2)
	assert_int(unit.trait_level("siege")).is_equal(0)


func test_weight_and_strength_must_not_be_negative() -> void:
	var item := _item("anvil", [])
	item.weight = -1.0
	item.strength_requirement = -2

	assert_int(item.validate().size()).is_equal(2)


func test_the_units_in_play_carry_items_that_fit() -> void:
	for name in ["grem", "grem_brute", "grem_chieftain", "grem_spitter", "kingdom_militia"]:
		var unit: UnitDef = load("res://content/units/%s.tres" % name)
		assert_array(unit.validate()).is_empty()
		assert_bool(unit.items.is_empty()).is_false()

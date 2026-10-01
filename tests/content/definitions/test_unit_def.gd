extends GdUnitTestSuite

const UnitDef = preload("res://content/definitions/unit_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")


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


func test_a_unit_is_one_slot_by_default() -> void:
	var unit := UnitDef.new()

	assert_int(unit.footprint_depth).is_equal(1)
	assert_int(unit.footprint_width).is_equal(1)


func test_footprints_must_be_between_one_and_eight_slots() -> void:
	var unit := UnitDef.new()
	unit.footprint_depth = 0
	unit.footprint_width = 9

	var errors := unit.validate()

	(
		assert_bool(Array(errors).any(func(message): return message.contains("footprint_depth")))
		. is_true()
	)
	(
		assert_bool(Array(errors).any(func(message): return message.contains("footprint_width")))
		. is_true()
	)


func test_a_unit_takes_a_positive_time_to_build() -> void:
	var unit := UnitDef.new()
	unit.build_seconds = 0.0

	var errors := unit.validate()

	(
		assert_bool(Array(errors).any(func(message): return message.contains("build_seconds")))
		. is_true()
	)


func test_a_unit_prefers_the_front_by_default() -> void:
	var unit := UnitDef.new()

	assert_int(unit.preferred_position).is_equal(UnitDef.Position.FRONT)


func test_negative_priority_is_invalid() -> void:
	var unit := UnitDef.new()
	unit.position_priority = -1

	var errors := Array(unit.validate())

	assert_bool(errors.any(func(message): return message.contains("position_priority"))).is_true()


func test_melee_damage_is_the_sum_of_its_melee_weapons() -> void:
	var unit := UnitDef.new()
	unit.dmg = 9
	unit.weapons = [_weapon("bite", 3, 0), _weapon("claw", 3, 0), _weapon("spit", 4, 5)]

	assert_int(unit.melee_damage()).is_equal(6)
	assert_str(unit.ranged_weapon().weapon_name).is_equal("spit")


func test_a_unit_without_weapons_strikes_with_dmg() -> void:
	var unit := UnitDef.new()
	unit.dmg = 9

	assert_int(unit.melee_damage()).is_equal(9)
	assert_object(unit.ranged_weapon()).is_null()


func test_an_invalid_weapon_makes_the_unit_invalid() -> void:
	var unit := UnitDef.new()
	unit.weapons = [_weapon("claw", -1, 0)]

	(
		assert_bool(Array(unit.validate()).any(func(message): return message.contains("claw")))
		. is_true()
	)


func _weapon(weapon_name: String, damage: int, attack_range: int) -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.weapon_name = weapon_name
	weapon.damage = damage
	weapon.attack_range = attack_range
	return weapon

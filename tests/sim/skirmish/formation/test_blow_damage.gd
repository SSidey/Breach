extends GdUnitTestSuite
## BlowDamage and UnitArms, per Decisions 119 and 120 (spec 28 part 5): a landed blow's
## damage rolls between its weapons' floor - lifted by skill - and their full; each
## weapon's part meets the target's weakness, resistance or immunity to its type; armour
## comes off mundane parts and ward off magical ones; strength scales a weapon over its
## requirement, and a unit wields worse untrained or too weak.

const BlowDamage = preload("res://sim/skirmish/formation/blow_damage.gd")
const BlowRoll = preload("res://sim/skirmish/formation/blow_roll.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const UnitArms = preload("res://content/definitions/unit_arms.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")
const ArmourDef = preload("res://content/definitions/armour_def.gd")


## A striker of 10 slashing (floor half), at `skill`; the floor skill is the tuning's.
func _striker(skill: int, parts: Array = [[10.0, "slashing", false]]) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.melee_skill = skill
	unit.melee_parts = parts
	unit.melee_floor = 0.5
	unit.critical = 1.5
	return unit


func test_the_roll_falls_between_the_floor_skill_lifts_and_the_full() -> void:
	var target := SkirmishUnit.new()
	var full_skill := roundi(BattleTuning.current().damage_floor_skill)

	assert_int(BlowDamage.dealt(_striker(0), target, 10, BlowRoll.HIT, false, 0.0)).is_equal(5)
	assert_int(BlowDamage.dealt(_striker(0), target, 10, BlowRoll.HIT, false, 1.0)).is_equal(10)
	var skilled := BlowDamage.dealt(_striker(full_skill), target, 10, BlowRoll.HIT, false, 0.0)
	assert_int(skilled).is_equal(10)
	assert_float(BlowDamage.spill(_striker(full_skill + 10), false)).is_greater(0.0)
	assert_float(BlowDamage.spill(_striker(full_skill), false)).is_equal(0.0)


func test_how_it_landed_takes_its_share() -> void:
	var target := SkirmishUnit.new()
	var striker := _striker(0)

	assert_int(BlowDamage.dealt(striker, target, 10, BlowRoll.PARRIED, false, 1.0)).is_equal(0)
	assert_int(BlowDamage.dealt(striker, target, 10, BlowRoll.DODGED, false, 1.0)).is_equal(0)
	assert_int(BlowDamage.dealt(striker, target, 10, BlowRoll.GRAZED, false, 1.0)).is_equal(5)
	assert_int(BlowDamage.dealt(striker, target, 10, BlowRoll.CRITICAL, false, 1.0)).is_equal(15)


func test_weakness_resistance_and_immunity_by_part() -> void:
	var striker := _striker(0, [[6.0, "slashing", false], [4.0, "fire", false]])
	var troll := SkirmishUnit.new()
	troll.weaknesses = ["fire"]
	var golem := SkirmishUnit.new()
	golem.resistances = ["slashing"]
	golem.immunities = ["fire"]

	assert_int(BlowDamage.dealt(striker, troll, 10, BlowRoll.HIT, false, 1.0)).is_equal(12)
	assert_int(BlowDamage.dealt(striker, golem, 10, BlowRoll.HIT, false, 1.0)).is_equal(3)


func test_armour_stops_mundane_blows_and_ward_magical_ones() -> void:
	var mundane := _striker(0, [[6.0, "slashing", false]])
	var magical := _striker(0, [[6.0, "fire", true]])
	var knight := SkirmishUnit.new()
	knight.armour = 4
	var mage := SkirmishUnit.new()
	mage.ward = 10

	assert_int(BlowDamage.dealt(mundane, knight, 6, BlowRoll.HIT, false, 1.0)).is_equal(2)
	assert_int(BlowDamage.dealt(magical, knight, 6, BlowRoll.HIT, false, 1.0)).is_equal(6)
	assert_int(BlowDamage.dealt(magical, mage, 6, BlowRoll.HIT, false, 1.0)).is_equal(0)
	assert_int(BlowDamage.dealt(mundane, mage, 6, BlowRoll.GRAZED, false, 0.0)).is_equal(2)


func test_a_unit_made_without_weapons_parts_strikes_for_its_damage() -> void:
	var bare := SkirmishUnit.new()

	assert_int(BlowDamage.dealt(bare, SkirmishUnit.new(), 7, BlowRoll.HIT, false, 1.0)).is_equal(7)


func test_strength_scales_a_weapon_over_its_requirement() -> void:
	var maul := WeaponDef.new()
	maul.item_name = "maul"
	maul.damage = 8
	maul.strength_requirement = 12
	maul.strength_scaling = 0.5
	var ogre := UnitDef.new()
	ogre.strength = 16
	ogre.items = [maul]
	var weakling := UnitDef.new()
	weakling.strength = 9
	weakling.items = [maul]

	assert_float(UnitArms.parts(ogre, false)[0][0]).is_equal(10.0)
	assert_float(UnitArms.parts(weakling, false)[0][0]).is_equal(8.0)
	var lost := roundi(3 * BattleTuning.current().item_weak_skill)
	assert_int(UnitArms.skill(weakling, false)).is_equal(weakling.melee_skill - lost)


func test_proficiency_shifts_the_skill_a_weapon_is_wielded_at() -> void:
	var axe := WeaponDef.new()
	axe.item_name = "axe"
	axe.damage = 6
	axe.tags = ["axe"]
	var unit := UnitDef.new()
	unit.items = [axe]
	var tuning := BattleTuning.current()

	assert_int(UnitArms.skill(unit, false)).is_equal(
		roundi(unit.melee_skill + tuning.item_untrained_skill)
	)
	unit.proficiencies = {"axe": 1}
	assert_int(UnitArms.skill(unit, false)).is_equal(unit.melee_skill)
	unit.proficiencies = {"axe": 2}
	assert_int(UnitArms.skill(unit, false)).is_equal(
		roundi(unit.melee_skill + tuning.item_mastered_skill)
	)


func test_armour_worn_adds_to_its_own() -> void:
	var gambeson := ArmourDef.new()
	gambeson.item_name = "gambeson"
	gambeson.armour = 1
	var unit := UnitDef.new()
	unit.armour = 1
	unit.ward = 2
	unit.items = [gambeson]

	assert_object(UnitArms.protection(unit)).is_equal(Vector2i(2, 2))

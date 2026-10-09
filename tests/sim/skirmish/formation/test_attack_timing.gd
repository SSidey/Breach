extends GdUnitTestSuite
## Attack timing, per Decision 120 (spec 28): a weapon sets the seconds between its blows,
## the wielder's attack speed divides them, and a unit's melee weapons strike together as
## often as the slowest of them allows.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")


func _weapon(seconds: float, attack_range: int = 0) -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.item_name = "club"
	weapon.damage = 1
	weapon.attack_range = attack_range
	weapon.attack_seconds = seconds
	return weapon


func _def(weapons: Array, attack_speed := 1.0) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 10000
	unit_def.speed = 1.0
	unit_def.attack_speed = attack_speed
	unit_def.items.assign(weapons)
	return unit_def


func test_the_slowest_melee_weapon_and_attack_speed_set_the_interval() -> void:
	assert_float(_def([_weapon(1.0), _weapon(2.0)]).melee_seconds()).is_equal(2.0)
	assert_float(_def([_weapon(2.0)], 1.25).melee_seconds()).is_equal_approx(1.6, 0.0001)
	assert_float(_def([]).melee_seconds()).is_equal(1.0)
	assert_float(_def([_weapon(0.5, 4)]).melee_seconds()).is_equal(1.0)  # ranged only
	var bad := _weapon(0.0)
	assert_array(bad.validate()).is_not_empty()
	var slow_hands := _def([_weapon(1.0)], 0.0)
	assert_array(slow_hands.validate()).is_not_empty()


func _hits(seconds: float) -> int:
	var sim := FormationSimulation.new(9.0, 0.1)
	var mine := sim.spawn_squad(1, [[_def([_weapon(seconds)]), Vector2i(0, 0)]], "player", true)
	var theirs := sim.spawn_squad(1, [[_def([_weapon(1.0)]), Vector2i(0, 0)]], "the_kingdom", false)
	var counted := 0
	var fighting := 0
	for _i in range(2000):
		var events := sim.step()
		if theirs.state == theirs.State.FIGHTING:
			fighting += 1
		counted += (
			events.filter(func(e): return e["type"] == "hit" and e["faction"] == "player").size()
		)
		if fighting >= 100:  # ten seconds of fighting
			break
	assert_int(fighting).is_equal(100)
	return counted


func test_a_slow_weapon_strikes_half_as_often() -> void:
	var quick := _hits(1.0)
	var slow := _hits(2.0)

	assert_int(quick).is_between(9, 11)
	assert_int(slow).is_between(4, 6)

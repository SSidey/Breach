extends GdUnitTestSuite
## Bodies, per Decision 106 and spec 30 round 1: a unit's body is the circle in its
## footprint; friends' bodies that overlap are pushed apart by mass, a unit in its frame
## resisting but giving way (it leaves its place); overlapping foes each step back half,
## neither pushing the other; and nothing turns on the order units are listed in.

const UnitBodies = preload("res://sim/skirmish/formation/unit_bodies.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")


func _unit(unit_id: int, size: int = 1) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = unit_id
	unit.hp = 10
	unit.footprint_width = size
	unit.footprint_depth = size
	return unit


## A squad of these units, each loose at its point.
func _loose(squad_id: int, faction: String, units: Array, points: Array) -> SkirmishSquad:
	var members: Array[SkirmishUnit] = []
	members.assign(units)
	var squad := SkirmishSquad.new(squad_id, faction, 1, 0.0, units.size(), members)
	for index in range(units.size()):
		var unit: SkirmishUnit = units[index]
		squad.loose[unit.id] = {"unit": unit, "at": points[index], "goal": null}
		squad.loose[unit.id]["next"] = points[index]
	return squad


func _at(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	return UnitBodies.at(squad, unit)


func test_a_body_is_the_circle_in_its_footprint() -> void:
	assert_float(UnitBodies.radius(_unit(1))).is_equal(0.5)
	assert_float(UnitBodies.radius(_unit(2, 2))).is_equal(1.0)


func test_a_heavier_body_moves_a_lighter_one_more() -> void:
	var grem := _unit(1)
	var brute := _unit(2, 2)
	var squad := _loose(1, "player", [grem, brute], [Vector2(0, 0), Vector2(1.2, 0)])

	UnitBodies.step([squad], 7)

	assert_float(_at(squad, grem).distance_to(_at(squad, brute))).is_equal_approx(1.5, 0.0001)
	var grem_moved := absf(_at(squad, grem).x)  # 0.3 deep, split 4 : 1
	assert_float(grem_moved).is_equal_approx(0.24, 0.0001)


func test_overlapping_foes_each_step_back_half_whatever_their_mass() -> void:
	var grem := _unit(1)
	var brute := _unit(2, 2)
	var a := _loose(1, "player", [grem], [Vector2(0, 0)])
	var b := _loose(2, "the_kingdom", [brute], [Vector2(1.2, 0)])

	UnitBodies.step([a, b], 7)

	assert_vector(_at(a, grem)).is_equal_approx(Vector2(-0.15, 0), Vector2(0.0001, 0.0001))
	assert_vector(_at(b, brute)).is_equal_approx(Vector2(1.35, 0), Vector2(0.0001, 0.0001))


func test_a_unit_in_its_frame_resists_but_gives_way() -> void:
	var framed := _unit(1)
	var line := SkirmishSquad.new(1, "player", 1, 0.0, 1, [framed] as Array[SkirmishUnit])
	framed.position = Vector2(5, 5)
	var shover := _unit(2)
	var router := _loose(2, "player", [shover], [Vector2(5.5, 5)])

	UnitBodies.step([line, router], 7)

	assert_bool(line.loose.has(framed.id)).is_true()  # it left its place, to walk back
	var framed_moved := _at(line, framed).distance_to(Vector2(5, 5))
	var shover_moved := _at(router, shover).distance_to(Vector2(5.5, 5))
	assert_float(framed_moved).is_equal_approx(0.1, 0.0001)  # 0.5 deep, split 1 : 4
	assert_float(shover_moved).is_equal_approx(0.4, 0.0001)


func test_bodies_on_one_spot_part_the_same_whatever_the_list_order() -> void:
	var results := []
	for reversed in [false, true]:
		var units := [_unit(1), _unit(2), _unit(3)]
		var points := [Vector2(4, 4), Vector2(4, 4), Vector2(4.2, 4)]
		if reversed:
			units.reverse()
			points.reverse()
		var squad := _loose(1, "player", units, points)
		UnitBodies.step([squad], 9)
		var where := {}
		for unit in squad.units:
			where[unit.id] = _at(squad, unit).snapped(Vector2(0.0001, 0.0001))
		results.append(where)

	assert_dict(results[1]).is_equal(results[0])

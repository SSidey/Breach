extends GdUnitTestSuite
## GroundBodies.underfoot (spec 30 round 3, part 7): every unit that walks - to its place,
## or loose in a fight - is slowed by the bodies on the ground it steps over, by their
## weight against its own, and blocked by one bodies_ground_block times its mass.

const GroundBodies = preload("res://sim/skirmish/formation/ground_bodies.gd")
const FormationWalk = preload("res://sim/skirmish/formation/formation_walk.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _body(at: Vector2, size: int) -> SkirmishUnit:
	var body := SkirmishUnit.new()
	body.position = at
	body.footprint_width = size
	body.footprint_depth = size
	body.state = SkirmishUnit.State.DOWNED
	return body


func _walker(at: Vector2) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.position = at
	return unit


func test_a_body_underfoot_slows_by_its_weight_against_the_walkers() -> void:
	var drag := BattleTuning.current().bodies_ground_drag
	var walker := _walker(Vector2.ZERO)
	var grem := [_body(Vector2(0.5, 0), 1)]
	var brute := [_body(Vector2(1, 0), 2)]

	var over_grem := GroundBodies.underfoot(walker, Vector2(0.5, 0), grem)
	assert_float(over_grem).is_equal_approx(1.0 / (1.0 + drag), 0.0001)
	var over_brute := GroundBodies.underfoot(walker, Vector2(0.5, 0), brute)
	assert_float(over_brute).is_equal_approx(1.0 / (1.0 + 4.0 * drag), 0.0001)
	assert_float(GroundBodies.underfoot(walker, Vector2(5, 0), grem)).is_equal(1.0)


func test_a_body_too_heavy_blocks_the_step() -> void:
	var walker := _walker(Vector2.ZERO)
	var huge := [_body(Vector2(0.5, 0), 3)]

	assert_float(GroundBodies.underfoot(walker, Vector2(0.5, 0), huge)).is_equal(0.0)


func test_a_unit_walking_back_to_its_place_over_a_body_is_slowed() -> void:
	var paces := []
	for with_body in [false, true]:
		var sim := FormationSimulation.new(4.0, 0.1)
		var grem: UnitDef = load("res://content/units/grem.tres")
		var squad := sim.spawn_squad(1, [[grem, Vector2i(0, 0)]], "player", true)
		var unit: SkirmishUnit = squad.units[0]
		var place := FormationWalk.place_of(squad, unit)
		var back := -UnitMotion.vector(squad.heading)
		unit.position = place + back * 4.0
		var lying := [_body(unit.position - back * 0.5, 1)] if with_body else []
		FormationWalk.walk(squad, unit, place, [0.1, 8.0, lying])
		paces.append(4.0 - unit.position.distance_to(place))
	assert_float(paces[1]).is_less(paces[0])

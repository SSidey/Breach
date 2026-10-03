extends GdUnitTestSuite
## FormationField, per Decision 86 and spec 27 round 1: one simulation over a 128 x 64 cell
## field, the player's waves on routes A (straight at the line) and B (round through the
## wood, rejoining A before the line in round 1), and the kingdom's line holding across A.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(hp: int, dmg: int) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = 1.0
	unit_def.build_seconds = 0.1
	return unit_def


func _field(kingdom_hp: int = 60, wave_hp: int = 20) -> FormationField:
	return FormationField.new(TICK, _def(wave_hp, 3), 8, _def(kingdom_hp, 2))


func _run(field: FormationField, done: Callable, limit: int = 3000) -> Array:
	var log := []
	for _i in range(limit):
		log.append_array(field.step())
		if done.call(log):
			break
	return log


func _has(kind: String) -> Callable:
	return func(log): return log.any(func(e): return e["type"] == kind)


func test_the_kingdom_holds_a_line_across_route_a() -> void:
	var field := _field()
	field.step()

	var line := field.kingdom_line
	assert_vector(line.position).is_equal_approx(
		Vector2(FormationField.LINE_AT, 32), Vector2(0.01, 0.01)
	)
	assert_int(line.facing).is_equal(SquadFrame.WEST)
	assert_int(line.state).is_equal(SkirmishSquad.State.HOLDING)
	assert_int(line.living().size()).is_equal(
		FormationField.KINGDOM_WIDTH * FormationField.KINGDOM_RANKS
	)


func test_both_routes_end_at_the_far_side_along_the_centre() -> void:
	var field := _field()

	for key in ["A", "B"]:
		var route = field.routes[key]
		assert_vector(route.point_at(route.length_cells())).is_equal(Vector2(128, 32))
	assert_float(field.routes["B"].length_cells()).is_greater(field.routes["A"].length_cells())


func test_a_wave_sent_down_route_a_fights_the_line() -> void:
	var field := _field()
	_run(field, _has("wave_full"))

	field.send("A")
	_run(field, _has("engaged"))

	assert_int(field.kingdom_line.state).is_equal(SkirmishSquad.State.FIGHTING)


func test_a_wave_on_route_b_comes_round_and_reinforces_the_fight() -> void:
	var field := _field(400, 200)  # both sides last until route B's wave comes round
	_run(field, func(log): return field.waves["A"].built() == 8 and field.waves["B"].built() == 8)
	field.send("A")
	_run(field, _has("engaged"))

	field.send("B")
	var log := _run(field, _has("reinforced"))

	var reinforced: Array = log.filter(func(e): return e["type"] == "reinforced")
	assert_int(reinforced.size()).is_equal(1)
	assert_int(log.filter(func(e): return e["type"] == "turned").size()).is_greater_equal(2)


func test_waves_depart_on_their_own_when_set_to() -> void:
	var field := _field()
	field.set_auto("A", true)

	var log := _run(field, _has("departed"))

	assert_bool(log.any(func(e): return e["type"] == "departed")).is_true()
	assert_int(field.sim.squads().size()).is_equal(2)

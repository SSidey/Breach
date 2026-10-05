extends GdUnitTestSuite
## One unit to a cell, and one call on a threat, per spec 27 round 9 (the round 8 feel
## test): routers caught by a friend come to rest in free cells behind it, not inside it;
## units resting in one cell in the scrum step apart; and a line that has turned to meet
## one wave holds that call while it presses, rather than swinging between two.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const ScrumSpacing = preload("res://sim/skirmish/formation/scrum_spacing.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _def(hp: int = 100) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = 2
	unit_def.speed = 1.0
	return unit_def


func _line(count: int) -> Array:
	var placements := []
	for column in range(count):
		placements.append([_def(), Vector2i(0, column)])
	return placements


## The feel test's field with its content units, the kingdom's line led by a captain.
func _captained_field(battle_seed: int) -> FormationField:
	return FormationField.new(
		0.1,
		load("res://content/units/grem.tres"),
		8,
		load("res://content/units/kingdom_militia.tres"),
		load("res://content/units/grem_chieftain.tres"),
		load("res://content/units/kingdom_captain.tres"),
		battle_seed
	)


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x), floori(at.y))


func test_routers_caught_by_a_friend_rest_in_free_cells() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	var mine := sim.spawn_squad(4, _line(4), "player", true)
	mine.front_distance = 30.0 / 64.0
	var theirs := sim.spawn_squad(4, _line(4), "the_kingdom", false)
	theirs.front_distance = 32.0 / 64.0
	var friend := sim.spawn_squad(4, _line(4), "player", true)
	friend.front_distance = 15.0 / 64.0
	sim.order(friend.id, SkirmishUnit.Order.HOLD)
	for _i in range(5):
		sim.step()
	mine.morale = 0
	for _i in range(45):  # they run through the friend to rest behind it
		sim.step()

	var friend_cells := {}
	for unit in friend.living():
		friend_cells[_cell(unit.position)] = true
	var resting := {}
	var front: float = friend.living().map(func(u): return u.position.x).min()
	for unit in mine.living():
		if mine.fleeing[unit.id].get("caught", 0) > 0:
			assert_float(FormationRout.where(mine, unit.id).x).is_less_equal(front)  # behind it
			var spot := _cell(FormationRout.where(mine, unit.id))
			assert_bool(friend_cells.has(spot)).is_false()
			assert_bool(resting.has(spot)).is_false()
			resting[spot] = true
	assert_bool(resting.is_empty()).is_false()


func test_units_resting_in_one_cell_step_apart() -> void:
	var sim := FormationSimulation.new(2.0, 0.1)
	var squad := sim.spawn_squad(2, _line(2), "player", true)
	sim.step()
	for unit in squad.units:
		squad.loose[unit.id] = {"unit": unit, "at": Vector2(10.5, 10.5), "goal": null}
		squad.loose[unit.id]["next"] = Vector2(10.5, 10.5)

	for _i in range(5):
		ScrumSpacing.step([squad], 0.8, 1)

	var spots := squad.units.map(func(u): return _cell(squad.loose[u.id]["at"]))
	assert_that(spots[0]).is_not_equal(spots[1])


func test_a_captained_line_makes_one_call_between_two_waves() -> void:
	var field := _captained_field(2)
	for _i in range(3000):
		if field.waves["A"].built() == 8 and field.waves["B"].built() == 9:
			break
		field.step()
	field.send_together(["A", "B"])

	var faced := []
	for _i in range(600):
		for event in field.step():
			if event["type"] == "faced" and event["squad"] == field.kingdom_line.id:
				faced.append(event["facing"])

	assert_int(faced.size()).is_less_equal(1)


func test_a_captained_line_turning_to_a_flank_fills_its_front_rank() -> void:
	var field := _captained_field(680655)
	for _i in range(2000):
		if field.waves["B"].built() == 9:
			break
		field.step()
	field.send("B")
	var line := field.kingdom_line
	for _i in range(400):
		if field.step().any(func(e): return e["type"] == "faced" and e["squad"] == line.id):
			break
	for _i in range(15):
		field.step()

	assert_int(line.state).is_not_equal(SkirmishSquad.State.FIGHTING)
	for unit in line.living():  # none stuck short of its place, as one was in front of the captain
		var at := ScrumReach.at(line, unit)
		assert_float(at.distance_to(ScrumStance.anchor(line, unit))).is_less(0.05)

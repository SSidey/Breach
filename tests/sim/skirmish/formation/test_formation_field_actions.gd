extends GdUnitTestSuite
## The feel test's actions as words (Decision 93): applied to a field as its buttons would
## be, logged with their ticks, and a log replays the same battle tick for tick.

const FormationFieldActions = preload("res://sim/skirmish/formation/formation_field_actions.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")


func _state(field) -> String:
	var rows := []
	for squad in field.sim.squads():
		var units: Array = squad.units.map(func(u): return [u.id, u.hp, u.position])
		rows.append([squad.id, squad.state, squad.front_distance, units])
	return str(rows)


func test_actions_apply_as_the_buttons_do() -> void:
	var field := FormationFieldActions.field(7, false)

	assert_bool(FormationFieldActions.apply(field, "wait on")).is_true()
	assert_bool(field.waves["B"].staging.is_empty()).is_false()
	assert_bool(FormationFieldActions.apply(field, "via_c on")).is_true()
	assert_object(field.waves["A"].route).is_same(field.routes["C"])
	assert_bool(FormationFieldActions.apply(field, "pursues on")).is_true()
	assert_bool(field.kingdom_line.pursues).is_true()
	assert_bool(FormationFieldActions.apply(field, "dance")).is_false()


func test_a_log_replays_the_same_battle() -> void:
	var field := FormationFieldActions.field(446157, false)
	var log := ["seed 446157 captain off"]
	for _i in range(60):
		field.step()
	FormationFieldActions.apply(field, "send A+B")
	log.append("%d send A+B" % field.sim.tick_number())
	for _i in range(300):
		field.step()

	var replayed := FormationFieldActions.replay("\n".join(log), 300)

	assert_int(replayed.sim.tick_number()).is_equal(field.sim.tick_number())
	assert_str(_state(replayed)).is_equal(_state(field))

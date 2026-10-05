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


func test_a_log_reads_back_as_its_seed_and_actions() -> void:
	var read := FormationFieldActions.parse("seed 9 captain on\n0 wait on\n12 send A+B\n")

	assert_int(read["seed"]).is_equal(9)
	assert_bool(read["captained"]).is_true()
	assert_array(read["actions"]).is_equal([[0, "wait on"], [12, "send A+B"]])
	assert_bool(FormationFieldActions.parse("not a log").is_empty()).is_true()


func test_waves_that_merge_after_a_fight_regroup_and_march_on() -> void:
	# A feel-test log: A (via C) and B beat the line at the crossroads, their places
	# overlapping; they used to stand there regrouping forever, knocking each other loose.
	var log := "seed 492625 captain off\n96 via_c on\n158 send A+B"

	var field := FormationFieldActions.replay(log, 800)

	for squad in field.sim.squads():
		if squad.faction_id == "player" and squad.state != SkirmishSquad.State.DESTROYED:
			assert_bool(squad.loose.is_empty()).is_true()
			assert_int(squad.state).is_equal(SkirmishSquad.State.ARRIVED)


func test_waves_short_of_a_slot_wait_by_the_fight_not_in_their_places() -> void:
	# A feel-test log: as the line shrank, A's units with no slot left walked back into
	# their places while the rest fought on.
	var log := "seed 492625 captain off\n22 via_c on\n129 send A+B"
	var walked_back := {"units": 0}  # a lambda captures a local int by value
	var on_events := func(field, _events):
		if field.kingdom_line.is_destroyed():
			return
		for squad in field.sim.squads():
			if squad.faction_id != "player" or squad.state != SkirmishSquad.State.FIGHTING:
				continue
			for unit in squad.living():
				var entry: Dictionary = squad.loose.get(unit.id, {})
				var idle: bool = entry.get("goal") == null and not entry.get("touch", false)
				if unit.preferred_position == 0 and idle:
					walked_back["units"] += 1

	FormationFieldActions.replay(log, 280, on_events)

	assert_int(walked_back["units"]).is_equal(0)

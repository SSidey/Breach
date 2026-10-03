extends GdUnitTestSuite
## Wings, per Decision 81 and spec 27 round 2: with walking wings on, front units past the
## end of a narrower enemy line walk round onto its side instead of wrapping; they strike
## nothing on the way, hit the side with flank blows for one interval on arrival, draw the
## enemy's edge units round to them, and walk back when the fight ends. Off, the lane's
## abstract wrap is unchanged.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(hp: int, dmg: int) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = dmg
	unit_def.speed = 1.0
	return unit_def


func _block(unit_def: UnitDef, ranks: int, columns: int) -> Array:
	var placements := []
	for rank in range(ranks):
		for column in range(columns):
			placements.append([unit_def, Vector2i(rank, column)])
	return placements


## The player's line `width` wide against a kingdom line 4 wide and 2 deep.
func _fight(width: int, walk: bool = true, kingdom_hp: int = 200) -> FormationSimulation:
	var sim := FormationSimulation.new(2.0, TICK)
	sim.walk_wings = walk
	sim.spawn_squad(width, _block(_def(200, 4), 1, width), "player", true)
	var line := sim.spawn_squad(4, _block(_def(kingdom_hp, 2), 2, 4), "the_kingdom", false)
	sim.order(line.id, SkirmishUnit.Order.HOLD)
	return sim


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for _i in range(ticks):
		log.append_array(sim.step())
	return log


func _of(log: Array, kind: String) -> Array:
	return log.filter(func(e): return e["type"] == kind)


func test_the_units_past_the_line_end_walk_round_onto_its_sides() -> void:
	var sim := _fight(8)

	var log := _run(sim, 200)

	var arrived: Array = _of(log, "wing_arrived")
	assert_int(arrived.size()).is_equal(4)
	var edges := {}
	for event in arrived:
		edges[event["edge"]] = edges.get(event["edge"], 0) + 1
	assert_int(edges.size()).is_equal(2)  # two on each side
	var player: SkirmishSquad = sim.squads()[0]
	for wing in player.wings.values():
		var at: Vector2 = wing["at"]
		assert_bool(absf(at.y) > 2.0).is_true()  # beside the line, not in front of it


func test_only_units_past_the_line_end_go() -> void:
	var sim := _fight(6)

	var log := _run(sim, 200)

	assert_int(_of(log, "wing_arrived").size()).is_equal(2)


func test_wings_strike_nothing_while_walking_and_flank_on_arrival() -> void:
	var sim := _fight(8)

	var log := _run(sim, 200)

	var arrivals := {}
	for event in _of(log, "wing_arrived"):
		arrivals[event["unit"]] = event["tick"]
	for hit in _of(log, "hit"):
		if not arrivals.has(hit["unit"]):
			continue
		assert_int(hit["tick"]).is_greater_equal(arrivals[hit["unit"]])
		assert_bool(hit["flank"]).is_equal(hit["tick"] - arrivals[hit["unit"]] < 10)


func test_the_enemys_rear_rank_turns_to_strike_the_wings() -> void:
	var sim := _fight(8)
	var player: SkirmishSquad = sim.squads()[0]

	var log := _run(sim, 250)

	var wing_ids := {}
	for event in _of(log, "wing_arrived"):
		wing_ids[event["unit"]] = true
	var on_wings := _of(log, "hit").filter(
		func(h): return h["faction"] == "the_kingdom" and wing_ids.has(h["target"])
	)
	assert_bool(on_wings.is_empty()).is_false()
	assert_bool(player.living().size() > 0).is_true()


func test_wings_walk_back_when_the_fight_ends() -> void:
	var sim := _fight(8, true, 12)

	var log := _run(sim, 600)

	assert_int(_of(log, "destroyed").size()).is_equal(1)
	assert_bool(_of(log, "wing_returned").is_empty()).is_false()
	var player: SkirmishSquad = sim.squads()[0]
	assert_bool(player.wings.is_empty()).is_true()


func test_without_walking_wings_the_ends_still_wrap() -> void:
	var sim := _fight(8, false)

	var log := _run(sim, 250)

	assert_int(_of(log, "wing_arrived").size()).is_equal(0)
	var wraps := _of(log, "hit").filter(func(h): return h["faction"] == "player" and h["flank"])
	assert_bool(wraps.is_empty()).is_false()

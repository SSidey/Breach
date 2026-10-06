extends GdUnitTestSuite
## The downed and the caught, per Decision 121 (spec 28 part 6): a unit brought to 0 hp is
## downed, its hp stopping there, unless past minus its constitution, which kills it; an
## unguarded downed unit beside a foe with no fight of its own is finished - struck down
## through death's door - or captured by a captor, or sent home by a leader's messenger;
## a routing unit struck may surrender.

const FormationWounds = preload("res://sim/skirmish/formation/formation_wounds.gd")
const FormationDeaths = preload("res://sim/skirmish/formation/formation_deaths.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const SECOND := 10  # ticks


func _unit(unit_id: int, faction: String, at: Vector2) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = unit_id
	unit.faction_id = faction
	unit.hp = 10
	unit.max_hp = 10
	unit.dmg = 4
	unit.position = at
	unit.attributes = {"constitution": 6}
	return unit


func _squad(squad_id: int, faction: String, members: Array) -> SkirmishSquad:
	var typed: Array[SkirmishUnit] = []
	typed.assign(members)
	return SkirmishSquad.new(squad_id, faction, 1, 0.0, members.size(), typed)


## A downed kingdom unit at the origin and a player unit one cell off: [squads, body,
## taker].
func _scene() -> Array:
	var body := _unit(1, "the_kingdom", Vector2.ZERO)
	body.hp = 0
	body.state = SkirmishUnit.State.DOWNED
	var taker := _unit(2, "player", Vector2(1, 0))
	return [[_squad(1, "the_kingdom", [body]), _squad(2, "player", [taker])], body, taker]


func _types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func test_brought_to_zero_it_is_downed_and_past_its_constitution_it_dies() -> void:
	var downed := _unit(1, "player", Vector2.ZERO)
	downed.hp = -5  # within its constitution of 6: the excess is lost
	var killed := _unit(2, "player", Vector2(1, 0))
	killed.hp = -6
	var events := []

	FormationDeaths.bury([_squad(1, "player", [downed, killed])], 1, events)

	assert_int(downed.state).is_equal(SkirmishUnit.State.DOWNED)
	assert_int(downed.hp).is_equal(0)
	assert_int(killed.state).is_equal(SkirmishUnit.State.DEAD)
	assert_array(_types(events)).contains(["downed", "died"])
	assert_bool(downed.is_alive()).is_false()


func test_an_unguarded_body_is_struck_through_deaths_door_till_it_dies() -> void:
	var scene := _scene()
	var events := []
	for tick in range(1, 4 * SECOND):
		FormationWounds.tend(scene[0], tick, SECOND, 1, events)

	var body: SkirmishUnit = scene[1]
	assert_int(body.state).is_equal(SkirmishUnit.State.DEAD)
	assert_int(body.hp).is_less_equal(-6)
	assert_array(_types(events)).contains(["finished"])


func test_a_captor_captures_it_instead() -> void:
	var scene := _scene()
	scene[2].traits = {"captor": 1}
	var events := []

	FormationWounds.tend(scene[0], 1, SECOND, 1, events)

	assert_int(scene[1].state).is_equal(SkirmishUnit.State.TAKEN)
	assert_array(_types(events)).contains(["captured"])


func test_a_friend_near_guards_it_and_a_foe_near_keeps_the_taker_fighting() -> void:
	var guarded := _scene()
	guarded[0][0].units.append(_unit(3, "the_kingdom", Vector2(-3.5, 0)))  # guards it
	var pressed := _scene()
	pressed[0][0].units.append(_unit(3, "the_kingdom", Vector2(5, 0)))  # near the taker
	var events := []
	for tick in range(1, 4 * SECOND):
		FormationWounds.tend(guarded[0], tick, SECOND, 1, events)
		FormationWounds.tend(pressed[0], tick, SECOND, 1, events)

	assert_int(guarded[1].hp).is_equal(0)
	assert_int(pressed[1].hp).is_equal(0)
	assert_array(events).is_empty()


func test_a_leader_with_a_messenger_sends_one_home_to_shake_its_side() -> void:
	var scene := _scene()
	var leader := _unit(4, "player", Vector2(30, 0))
	leader.leadership = 2
	leader.traits = {"messenger": 1}
	scene[0][1].units.append(leader)
	var events := []

	FormationWounds.tend(scene[0], 1, SECOND, 1, events)

	assert_int(scene[1].state).is_equal(SkirmishUnit.State.RELEASED)
	assert_int(leader.traits["messenger"]).is_equal(0)
	assert_array(_types(events)).contains(["sent_home"])


func test_a_struck_router_may_surrender_unless_it_never_does() -> void:
	var cowards := []
	var proud := []
	for index in range(20):
		var coward := _unit(10 + index, "the_kingdom", Vector2(index, 0))
		coward.courage = 0
		cowards.append(coward)
		var stubborn := _unit(40 + index, "the_kingdom", Vector2(index, 5))
		stubborn.courage = 0
		stubborn.traits = {"never_surrenders": 1}
		proud.append(stubborn)
	var fleeing := _squad(1, "the_kingdom", cowards + proud)
	fleeing.state = SkirmishSquad.State.ROUTING
	var hunter := _unit(99, "player", Vector2(0, 1))
	var blows := (cowards + proud).map(func(u): return [hunter, u, 1, true, "hit"])
	var events := []

	FormationWounds.surrender(blows, [fleeing, _squad(2, "player", [hunter])], 1, 1, events)

	var taken := cowards.filter(func(u): return u.state == SkirmishUnit.State.TAKEN)
	assert_int(taken.size()).is_between(3, 17)  # half each, by the seeded roll
	assert_bool(proud.all(func(u): return u.is_alive())).is_true()
	assert_int(_types(events).count("surrendered")).is_equal(taken.size())


func test_regeneration_mends_to_its_max_and_no_further_than_its_limit() -> void:
	var troll := _unit(1, "player", Vector2.ZERO)
	troll.hp = 2
	troll.regeneration = 2.0
	troll.regeneration_left = 5.0
	var squads := [_squad(1, "player", [troll])]
	for tick in range(1, 31):
		FormationWounds.mend(squads, 0.1, tick, [])

	assert_int(troll.hp).is_equal(7)  # 5 regained: its limit until it rests
	assert_float(troll.regeneration_left).is_equal_approx(0.0, 0.0001)
	troll.regeneration_left = 100.0
	for tick in range(31, 101):
		FormationWounds.mend(squads, 0.1, tick, [])
	assert_int(troll.hp).is_equal(10)  # never past its max


func test_a_blow_of_a_type_it_fears_stops_its_regeneration_a_while() -> void:
	var troll := _unit(1, "player", Vector2.ZERO)
	troll.hp = 2
	troll.regeneration = 10.0
	troll.regeneration_left = 100.0
	troll.regeneration_stops = ["fire"]
	FormationWounds.scorch(troll, [[3.0, "slashing", false]], 3)
	assert_float(troll.regeneration_halt).is_equal(0.0)
	FormationWounds.scorch(troll, [[3.0, "fire", true]], 3)
	var squads := [_squad(1, "player", [troll])]
	FormationWounds.mend(squads, 1.0, 1, [])

	assert_int(troll.hp).is_equal(2)
	assert_float(troll.regeneration_halt).is_greater(0.0)


func test_a_downed_regenerator_rises_only_with_the_trait_and_rejoins_at_the_back() -> void:
	var plain := _unit(1, "player", Vector2.ZERO)
	var troll := _unit(2, "player", Vector2(1, 0))
	var standing := _unit(3, "player", Vector2(2, 0))
	for unit in [plain, troll]:
		unit.hp = 0
		unit.state = SkirmishUnit.State.DOWNED
		unit.regeneration = 10.0
		unit.regeneration_left = 100.0
	troll.traits = {"regenerates_downed": 1}
	var squads := [_squad(1, "player", [plain, troll, standing])]
	var events := []
	for tick in range(1, 6):
		FormationWounds.mend(squads, 0.1, tick, events)

	assert_int(plain.hp).is_equal(0)
	assert_bool(troll.is_alive()).is_true()
	assert_int(troll.rank).is_equal(1)
	assert_array(_types(events)).contains(["rose"])

extends GdUnitTestSuite
## Sight and high ground on terrain, per Decisions 85 and 87 and spec 27 round 4: a wood
## blocks a sight line deeper than its edge, and a striker on higher ground hits harder.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationMelee = preload("res://sim/skirmish/formation/formation_melee.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(dmg: int = 4) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 200
	unit_def.dmg = dmg
	unit_def.speed = 1.0
	return unit_def


func _at(sim: FormationSimulation, point: Vector2, faction: String):
	var route := FormationRoute.new(PackedVector2Array([point, point + Vector2(0, 30)]))
	return sim.spawn_squad(1, [[_def(), Vector2i(0, 0)]], faction, true, 0, route)


func test_a_wood_between_two_squads_hides_them() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var ground := FormationTerrain.new(Vector2i(64, 32))
	ground.paint(Rect2i(15, 0, 10, 32), {"blocks_sight": true})
	var watcher = _at(sim, Vector2(10, 10), "player")
	var other = _at(sim, Vector2(30, 10), "the_kingdom")

	assert_bool(FormationSight.detects(watcher, other)).is_true()
	assert_bool(FormationSight.detects(watcher, other, ground)).is_false()


func test_from_a_woods_edge_a_squad_sees_out() -> void:
	var sim := FormationSimulation.new(2.0, TICK)
	var ground := FormationTerrain.new(Vector2i(64, 32))
	ground.paint(Rect2i(15, 0, 2, 32), {"blocks_sight": true})
	var watcher = _at(sim, Vector2(16.5, 10), "player")
	var other = _at(sim, Vector2(30, 10), "the_kingdom")

	assert_bool(FormationSight.detects(watcher, other, ground)).is_true()
	assert_bool(FormationSight.detects(other, watcher, ground)).is_true()


func test_a_striker_on_higher_ground_hits_harder() -> void:
	var sim := FormationSimulation.new(1.0, TICK)
	sim.terrain = FormationTerrain.new(Vector2i(64, 32))
	sim.terrain.paint(Rect2i(40, 0, 24, 32), {"height": 4})  # the kingdom's hill
	var east := FormationRoute.new(PackedVector2Array([Vector2(0, 10), Vector2(64, 10)]))
	var west := FormationRoute.new(PackedVector2Array([Vector2(40, 10), Vector2(0, 10)]))
	sim.spawn_squad(1, [[_def(4), Vector2i(0, 0)]], "player", true, 0, east)
	var line := sim.spawn_squad(1, [[_def(4), Vector2i(0, 0)]], "the_kingdom", true, 0, west)
	sim.order(line.id, SkirmishUnit.Order.HOLD)

	var hits := []
	for _i in range(120):
		hits.append_array(sim.step().filter(func(e): return e["type"] == "hit"))

	var downhill := hits.filter(func(h): return h["faction"] == "the_kingdom")
	var uphill := hits.filter(func(h): return h["faction"] == "player")
	assert_bool(downhill.is_empty() or uphill.is_empty()).is_false()
	assert_int(downhill[0]["dmg"]).is_equal(roundi(4 * FormationMelee.HIGH_GROUND))
	assert_int(uphill[0]["dmg"]).is_equal(4)

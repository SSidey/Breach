extends GdUnitTestSuite
## Fairness of the scrum, per Decision 93's mirror trials and spec 27 round 8: two equal
## squads marching at each other meet in the middle whichever was spawned first, and the
## cells they stand on count every side on them, so neither side's paths depend on the
## order squads are stepped in.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _row(columns: int) -> Array:
	var unit_def := UnitDef.new()
	unit_def.hp = 400
	unit_def.items = [WeaponDef.innate_weapon(1)]
	unit_def.speed = 1.0
	var placements := []
	for column in range(columns):
		placements.append([unit_def, Vector2i(0, column)])
	return placements


## [player front x, kingdom front x] when they engage, the kingdom spawned first if asked.
func _meeting(kingdom_first: bool) -> Array:
	var sim := FormationSimulation.new(2.0, 0.1)
	var squads := []
	if kingdom_first:
		squads = [
			sim.spawn_squad(8, _row(8), "the_kingdom", false),
			sim.spawn_squad(8, _row(8), "player", true),
		]
		squads.reverse()
	else:
		squads = [
			sim.spawn_squad(8, _row(8), "player", true),
			sim.spawn_squad(8, _row(8), "the_kingdom", false),
		]
	for _i in range(300):
		if sim.step().any(func(e): return e["type"] == "engaged"):
			break
	return [squads[0].position.x, squads[1].position.x]


func test_squads_marching_at_each_other_meet_in_the_middle_either_way() -> void:
	for kingdom_first in [false, true]:
		var fronts := _meeting(kingdom_first)
		assert_float(fronts[0] + fronts[1]).is_equal_approx(128.0, 0.05)

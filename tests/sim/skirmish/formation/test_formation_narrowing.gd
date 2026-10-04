extends GdUnitTestSuite
## Narrowing at gaps, per Decision 85 and spec 27 round 4: a squad wider than a gap ahead
## folds into a column that fits, front band first, holds while it re-forms, passes, and
## widens back to its painted places on open ground; a unit too wide for the gap halts it.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(preferred: int = 0, wide: int = 1) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 20
	unit_def.dmg = 1
	unit_def.speed = 1.0
	unit_def.preferred_position = preferred
	unit_def.footprint_width = wide
	unit_def.footprint_depth = wide
	return unit_def


## A stream of deep water across x 20 to 22 with a ford `ford` cells wide on the route
## (y = 10); a squad from these placements marching east along y = 10.
func _crossing(placements: Array, width: int, ford: int) -> Array:
	var sim := FormationSimulation.new(1.0, TICK)
	sim.terrain = FormationTerrain.new(Vector2i(64, 32))
	sim.terrain.paint(Rect2i(20, 0, 2, 32), {"depth": 3.0})
	sim.terrain.paint(Rect2i(20, 10 - ford / 2, 2, ford), {"depth": 0.0})
	var route := FormationRoute.new(PackedVector2Array([Vector2(0, 10), Vector2(64, 10)]))
	var squad := sim.spawn_squad(width, placements, "player", true, 0, route)
	return [sim, squad]


func _run(sim: FormationSimulation, ticks: int) -> Array:
	var log := []
	for _i in range(ticks):
		log.append_array(sim.step())
	return log


func _of(log: Array, kind: String) -> Array:
	return log.filter(func(e): return e["type"] == kind)


func _eight_with_rear_band() -> Array:
	var placements := []
	for column in range(8):
		var band := 2 if column in [3, 4] else 0  # two back-band units in the middle
		placements.append([_def(band), Vector2i(0, column)])
	return placements


func test_a_wide_squad_narrows_to_the_ford_front_band_first() -> void:
	var setup := _crossing(_eight_with_rear_band(), 8, 4)
	var squad: SkirmishSquad = setup[1]

	var log := _run(setup[0], 40)

	var narrowed := _of(log, "narrowed")
	assert_int(narrowed.size()).is_equal(1)
	assert_int(narrowed[0]["width"]).is_equal(4)
	assert_int(squad.width).is_equal(4)
	var front := squad.fighters()
	assert_int(front.size()).is_equal(4)
	assert_bool(front.all(func(u): return u.preferred_position == 0)).is_true()


func test_it_crosses_then_widens_back_to_its_painted_places() -> void:
	var setup := _crossing(_eight_with_rear_band(), 8, 4)
	var squad: SkirmishSquad = setup[1]
	var places := {}
	for unit in squad.units:
		places[unit.id] = [unit.rank, unit.column]

	var log := _run(setup[0], 120)

	assert_int(_of(log, "widened").size()).is_equal(1)
	assert_float(squad.position.x).is_greater(25.0)
	assert_int(squad.width).is_equal(8)
	for unit in squad.units:
		assert_array([unit.rank, unit.column]).is_equal(places[unit.id])


func test_a_squad_that_fits_does_not_narrow() -> void:
	var placements := []
	for column in range(4):
		placements.append([_def(), Vector2i(0, column)])
	var setup := _crossing(placements, 4, 4)

	var log := _run(setup[0], 80)

	assert_int(_of(log, "narrowed").size()).is_equal(0)
	assert_float(setup[1].position.x).is_greater(25.0)


func test_a_small_squad_off_to_one_side_of_the_ford_moves_into_it() -> void:
	# a partial wave keeps its painted columns: one unit in column 0 of an 8-wide line
	# stands 3.5 cells off the route, outside a 4-cell ford, though it is narrower than it
	var setup := _crossing([[_def(), Vector2i(0, 0)]], 8, 4)
	var squad: SkirmishSquad = setup[1]

	var log := _run(setup[0], 120)

	assert_int(_of(log, "narrowed").size()).is_equal(1)
	assert_int(_of(log, "blocked").size()).is_equal(0)
	assert_float(squad.position.x).is_greater(25.0)


func test_a_unit_too_wide_for_the_gap_halts_the_squad() -> void:
	var placements := [[_def(0, 2), Vector2i(0, 0)], [_def(), Vector2i(0, 2)]]
	var setup := _crossing(placements, 3, 1)

	var log := _run(setup[0], 80)

	assert_int(_of(log, "too_wide").size()).is_equal(1)
	assert_float(setup[1].position.x).is_less(20.0)


func test_narrowing_replays_the_same() -> void:
	var logs := []
	for _r in range(2):
		var setup := _crossing(_eight_with_rear_band(), 8, 4)
		logs.append(_run(setup[0], 120))

	assert_array(logs[1]).is_equal(logs[0])

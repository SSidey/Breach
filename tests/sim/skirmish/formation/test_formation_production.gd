extends GdUnitTestSuite
## FormationProduction, per Decision 42 and specs/22-formation-feel-test.md (round 2): a
## lane builds toward its painted template; a new template takes effect at once, built
## units fold in, and leftovers are banked in a reserve that fills places first.

const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1

var _grem: UnitDef
var _brute: UnitDef


func before_test() -> void:
	_grem = _def(20)
	_brute = _def(60, 2, 2)


func _def(hp: int, depth: int = 1, width: int = 1) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = 5
	unit_def.speed = 1.0
	unit_def.footprint_depth = depth
	unit_def.footprint_width = width
	return unit_def


func _production(template: WaveTemplate) -> FormationProduction:
	var production := FormationProduction.new("player", true)
	production.build_seconds = 0.5  # 5 ticks for a 1x1 unit, 10 for a 2x2
	production.set_template(template)
	return production


func _run(production: FormationProduction, sim: FormationSimulation, ticks: int) -> Array:
	var events := []
	for i in range(ticks):
		events.append_array(production.step(sim))
	return events


func _count(events: Array, kind: String) -> int:
	return events.filter(func(e): return e["type"] == kind).size()


func test_units_are_built_front_first_one_per_build_time() -> void:
	var production := _production(WavePresets.line(_grem, 5, 5))
	var sim := FormationSimulation.new(9.0, TICK)

	_run(production, sim, 10)

	assert_int(production.built()).is_equal(2)
	var filled := production.preview().filter(func(p): return p[4])
	(
		assert_array(filled.map(func(p): return Vector2i(p[0], p[1])))
		. is_equal([Vector2i(0, 0), Vector2i(0, 1)])
	)


func test_a_new_template_takes_effect_at_once_and_folds_built_units_in() -> void:
	var production := _production(WavePresets.line(_grem, 5, 5))
	var sim := FormationSimulation.new(9.0, TICK)
	_run(production, sim, 20)  # 4 grems built

	var events := production.set_template(WavePresets.line(_grem, 3, 3))

	assert_int(production.built()).is_equal(3)
	assert_int(production.reserve_count()).is_equal(1)
	assert_bool(production.is_full()).is_true()
	assert_int(events.filter(func(e): return e["type"] == "folded")[0]["banked"]).is_equal(1)


func test_units_of_a_type_the_new_shape_lacks_are_all_banked() -> void:
	var production := _production(WavePresets.line(_grem, 4, 4))
	var sim := FormationSimulation.new(9.0, TICK)
	_run(production, sim, 10)  # 2 grems built
	var brute_only := WaveTemplate.new(4, 8)
	brute_only.paint(_brute, Vector2i(0, 1))

	production.set_template(brute_only)

	assert_int(production.built()).is_equal(0)
	assert_int(production.reserve_count()).is_equal(2)


func test_the_reserve_fills_matching_places_before_anything_is_built() -> void:
	var production := _production(WavePresets.line(_grem, 4, 4))
	var sim := FormationSimulation.new(9.0, TICK)
	_run(production, sim, 20)  # 4 grems built
	production.set_template(WavePresets.line(_grem, 1, 4))  # 3 banked
	production.send(sim)

	var events := _run(production, sim, 1)

	assert_int(_count(events, "from_reserve")).is_equal(1)
	assert_int(production.built()).is_equal(1)
	assert_int(production.reserve_count()).is_equal(2)


func test_a_full_wave_is_announced_once() -> void:
	var production := _production(WavePresets.line(_grem, 3, 3))
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 60)

	assert_int(_count(events, "wave_full")).is_equal(1)
	assert_array(sim.squads()).is_empty()


func test_send_deploys_the_painted_layout_and_restarts_the_same_template() -> void:
	var template := WaveTemplate.new(5, 8)
	template.paint(_brute, Vector2i(0, 1))
	template.paint(_grem, Vector2i(2, 1))
	template.paint(_grem, Vector2i(2, 2))
	var production := _production(template)
	var sim := FormationSimulation.new(9.0, TICK)
	_run(production, sim, 40)

	var squad = production.send(sim)

	assert_int(squad.width).is_equal(2)  # painted columns 1..2
	var brute_unit = squad.units.filter(func(u): return u.footprint_width == 2)[0]
	assert_int(brute_unit.rank).is_equal(0)  # the brute leads
	assert_int(production.built()).is_equal(0)
	assert_int(production.preview().size()).is_equal(3)


func test_auto_departure_sends_the_wave_when_it_fills() -> void:
	var production := _production(WavePresets.line(_grem, 3, 3))
	production.departure = FormationProduction.Departure.AUTO_WHEN_FULL
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 15)

	assert_int(_count(events, "departed")).is_equal(1)
	assert_int(sim.squads().size()).is_equal(1)
	assert_int(sim.squads()[0].units.size()).is_equal(3)


func test_an_empty_template_builds_nothing() -> void:
	var production := _production(WaveTemplate.new(3, 0))
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 50)

	assert_int(_count(events, "built")).is_equal(0)
	assert_object(production.send(sim)).is_null()


func test_sending_a_partial_wave_keeps_the_progress_on_the_unit_underway() -> void:
	var sim := FormationSimulation.new(9.0, TICK)
	var production := _production(WavePresets.line(_grem, 5, 5))
	_run(production, sim, 8)  # one grem built, the next 3 of its 5 ticks in

	production.send(sim)

	assert_float(production.progress).is_equal_approx(0.6, 0.001)
	_run(production, sim, 2)
	assert_int(production.built()).is_equal(1)


func test_switching_unit_type_keeps_the_partly_built_unit() -> void:
	var sim := FormationSimulation.new(9.0, TICK)
	var production := _production(WavePresets.line(_grem, 3, 3))
	_run(production, sim, 3)  # a grem 3 of its 5 ticks in
	var reshaped := WaveTemplate.new(3, 8)
	reshaped.paint(_brute, Vector2i(0, 0))  # a brute now leads, so it builds first
	reshaped.paint(_grem, Vector2i(2, 0))
	production.set_template(reshaped)

	_run(production, sim, 10)  # the brute
	_run(production, sim, 2)  # the grem resumes where it left off

	assert_int(production.built()).is_equal(2)

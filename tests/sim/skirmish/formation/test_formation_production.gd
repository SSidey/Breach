extends GdUnitTestSuite
## FormationProduction, per specs/22-formation-feel-test.md and Decision 40: a lane builds
## each wave into a formation snapshot, so a slot-pool change applies to the next wave.

const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1


func _def(hp: int, depth: int = 1, width: int = 1) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = hp
	unit_def.dmg = 5
	unit_def.speed = 1.0
	unit_def.footprint_depth = depth
	unit_def.footprint_width = width
	return unit_def


func _production(preset: int = FormationProduction.Preset.LIGHT) -> FormationProduction:
	var production := FormationProduction.new("player", true, _def(20), _def(60, 2, 2))
	production.lane_width = 5
	production.build_seconds = 0.5  # 5 ticks for a light unit, 10 for a heavy one
	production.preset = preset
	return production


func _run(production: FormationProduction, sim: FormationSimulation, ticks: int) -> Array:
	var events := []
	for i in range(ticks):
		events.append_array(production.step(sim))
	return events


func _count(events: Array, kind: String) -> int:
	return events.filter(func(e): return e["type"] == kind).size()


func test_one_light_unit_is_built_every_build_seconds() -> void:
	var production := _production()
	production.configure(5, 5)
	var sim := FormationSimulation.new(9.0, TICK)

	_run(production, sim, 10)

	assert_int(production.built()).is_equal(2)


func test_a_pool_change_applies_to_the_next_wave_not_the_one_building() -> void:
	var production := _production()
	production.configure(5, 5)
	var sim := FormationSimulation.new(9.0, TICK)
	_run(production, sim, 1)  # the wave starts: its formation is fixed now

	production.configure(3, 3)
	_run(production, sim, 30)
	assert_int(production.built()).is_equal(5)
	production.send(sim)
	_run(production, sim, 30)

	assert_int(production.wave_slots()).is_equal(3)
	assert_int(production.built()).is_equal(3)


func test_brute_front_puts_one_brute_at_the_front_centre_and_fills_with_light_units() -> void:
	var production := _production(FormationProduction.Preset.HEAVY_FRONT)
	production.lane_width = 4
	production.configure(8, 4)
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 60)

	var layout := production.preview()
	assert_array(layout[0]).is_equal([0, 1, 2, 2])  # rank, column, depth, width
	assert_int(layout.size()).is_equal(5)
	assert_int(_count(events, "wave_full")).is_equal(1)
	assert_bool(production.is_full()).is_true()


func test_a_full_wave_is_announced_once_and_manual_departure_waits() -> void:
	var production := _production()
	production.configure(3, 3)
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 60)

	assert_int(_count(events, "wave_full")).is_equal(1)
	assert_array(sim.squads()).is_empty()


func test_auto_departure_sends_the_wave_as_one_squad() -> void:
	var production := _production()
	production.departure = FormationProduction.Departure.AUTO_WHEN_FULL
	production.configure(3, 3)
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 15)

	assert_int(_count(events, "departed")).is_equal(1)
	assert_int(sim.squads().size()).is_equal(1)
	assert_int(sim.squads()[0].units.size()).is_equal(3)
	assert_int(sim.squads()[0].width).is_equal(3)


func test_a_lane_with_no_slots_builds_nothing() -> void:
	var production := _production()
	production.configure(0, 3)
	var sim := FormationSimulation.new(9.0, TICK)

	var events := _run(production, sim, 50)

	assert_int(production.built()).is_equal(0)
	assert_int(_count(events, "built")).is_equal(0)
	assert_object(production.send(sim)).is_null()

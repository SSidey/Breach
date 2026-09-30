extends GdUnitTestSuite
## SkirmishProduction, per specs/21-realtime-skirmish-feel-test.md and Decision 39: a
## lane builds a wave, announces it once when full, and departs manually or automatically.

const SkirmishProduction = preload("res://sim/skirmish/skirmish_production.gd")
const SkirmishSimulation = preload("res://sim/skirmish/skirmish_simulation.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


func _production(departure: int) -> SkirmishProduction:
	var unit_def := UnitDef.new()
	unit_def.hp = 20
	unit_def.dmg = 6
	unit_def.speed = 1.0
	var production := SkirmishProduction.new(unit_def, "player", true)
	production.wave_size = 3
	production.build_ticks = 8
	production.departure = departure
	return production


func _run(production: SkirmishProduction, sim: SkirmishSimulation, ticks: int) -> Array:
	var events := []
	for i in range(ticks):
		events.append_array(production.step(sim))
	return events


func _count(events: Array, kind: String) -> int:
	return events.filter(func(e): return e["type"] == kind).size()


func test_one_unit_is_built_every_build_ticks() -> void:
	var production := _production(SkirmishProduction.Departure.MANUAL)
	var sim := SkirmishSimulation.new(9.0, 0.25)

	_run(production, sim, 16)

	assert_int(production.built).is_equal(2)
	assert_float(production.progress()).is_equal(0.0)


func test_a_full_wave_is_announced_once_and_building_stops() -> void:
	var production := _production(SkirmishProduction.Departure.MANUAL)
	var sim := SkirmishSimulation.new(9.0, 0.25)

	var events := _run(production, sim, 60)

	assert_int(_count(events, "wave_full")).is_equal(1)
	assert_int(production.built).is_equal(3)
	assert_bool(production.is_full()).is_true()
	assert_array(sim.units()).is_empty()  # manual: nothing departs on its own


func test_send_spawns_the_wave_staggered_and_restarts_building() -> void:
	var production := _production(SkirmishProduction.Departure.MANUAL)
	var sim := SkirmishSimulation.new(9.0, 0.25)
	_run(production, sim, 24)

	var sent := production.send(sim)

	assert_int(sent.size()).is_equal(3)
	assert_array(sent.map(func(u): return u.wait_ticks)).is_equal([0, 2, 4])
	assert_int(production.built).is_equal(0)
	assert_bool(production.is_full()).is_false()
	_run(production, sim, 8)
	assert_int(production.built).is_equal(1)


func test_auto_departure_sends_the_wave_on_the_tick_it_fills() -> void:
	var production := _production(SkirmishProduction.Departure.AUTO_WHEN_FULL)
	var sim := SkirmishSimulation.new(9.0, 0.25)

	var events := _run(production, sim, 24)

	assert_int(_count(events, "wave_full")).is_equal(1)
	assert_int(_count(events, "departed")).is_equal(1)
	assert_int(sim.units().size()).is_equal(3)
	assert_int(production.built).is_equal(0)


func test_sending_an_empty_wave_does_nothing() -> void:
	var production := _production(SkirmishProduction.Departure.MANUAL)
	var sim := SkirmishSimulation.new(9.0, 0.25)

	assert_array(production.send(sim)).is_empty()
	assert_array(sim.units()).is_empty()

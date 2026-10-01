extends GdUnitTestSuite
## DomainProduction, per Decision 45: the domain's builders each build one unit of their
## type at a time and share finished units across the lanes that want them, by priority
## or round robin; with nothing wanted they build into a capped domain reserve, which in
## turn fills any lane's matching places at once.

const DomainProduction = preload("res://sim/skirmish/formation/domain_production.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const TICK := 0.1

var _grem: UnitDef


func before_test() -> void:
	_grem = UnitDef.new()
	_grem.hp = 20
	_grem.build_seconds = 0.5  # 5 ticks


func _wave(count: int) -> FormationProduction:
	var wave := FormationProduction.new("player", true)
	wave.set_template(WavePresets.line(_grem, count, 5) if count > 0 else WaveTemplate.new(5, 0))
	return wave


func _domain(builders: int) -> DomainProduction:
	var domain := DomainProduction.new("player")
	domain.set_builders(_grem, builders)
	return domain


func _run(domain: DomainProduction, lanes: Dictionary, ticks: int) -> Array:
	var events := []
	for tick in range(ticks):
		events.append_array(domain.step(lanes, TICK, tick))
	return events


func test_two_builders_finish_two_units_in_one_build_time() -> void:
	var lanes := {"c": _wave(4)}

	_run(_domain(2), lanes, 5)

	assert_int(lanes["c"].built()).is_equal(2)


func test_priority_serves_the_first_lane_in_the_players_order() -> void:
	var lanes := {"c": _wave(2), "k": _wave(2)}
	var domain := _domain(1)
	domain.lane_order = ["k", "c"]

	_run(domain, lanes, 10)

	assert_int(lanes["k"].built()).is_equal(2)
	assert_int(lanes["c"].built()).is_equal(0)


func test_round_robin_takes_turns() -> void:
	var lanes := {"c": _wave(2), "k": _wave(2)}
	var domain := _domain(1)
	domain.distribution = DomainProduction.Distribution.ROUND_ROBIN

	_run(domain, lanes, 10)

	assert_int(lanes["c"].built()).is_equal(1)
	assert_int(lanes["k"].built()).is_equal(1)


func test_with_nothing_wanted_builders_fill_the_reserve_to_its_cap() -> void:
	var domain := _domain(2)
	domain.reserve_cap = 3

	_run(domain, {"c": _wave(0)}, 50)

	assert_int(domain.reserve.size()).is_equal(3)


func test_the_reserve_fills_a_lanes_places_at_once() -> void:
	var domain := _domain(0)
	domain.bank([_grem])
	var lanes := {"c": _wave(1)}

	var events := _run(domain, lanes, 1)

	assert_int(lanes["c"].built()).is_equal(1)
	assert_array(domain.reserve).is_empty()
	assert_bool(events.any(func(e): return e["type"] == "from_reserve")).is_true()


func test_a_build_whose_place_is_erased_goes_to_the_reserve_even_over_the_cap() -> void:
	var domain := _domain(1)
	domain.reserve_cap = 0
	var lanes := {"c": _wave(1)}
	_run(domain, lanes, 3)  # under way for lane c

	lanes["c"].set_template(WaveTemplate.new(5, 0))
	_run(domain, lanes, 2)

	assert_int(domain.reserve.size()).is_equal(1)


func test_builds_report_their_type_lane_and_progress() -> void:
	var domain := _domain(1)

	_run(domain, {"c": _wave(1)}, 2)

	var builds := domain.builds()
	assert_int(builds.size()).is_equal(1)
	assert_object(builds[0][0]).is_same(_grem)
	assert_str(builds[0][1]).is_equal("c")
	assert_float(builds[0][2]).is_equal_approx(0.4, 0.001)


func test_fewer_builders_keep_the_remaining_builders_work() -> void:
	var domain := _domain(2)
	_run(domain, {"c": _wave(4)}, 3)

	domain.set_builders(_grem, 1)

	assert_int(domain.builds().size()).is_equal(1)
	assert_float(domain.builds()[0][2]).is_equal_approx(0.6, 0.001)

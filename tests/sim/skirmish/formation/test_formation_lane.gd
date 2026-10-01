extends GdUnitTestSuite
## FormationLane, per specs/22-formation-feel-test.md (round 2) and Decision 42: one lane's
## simulation, the player's production and painted template, and the kingdom's line.

const FormationLane = preload("res://sim/skirmish/formation/formation_lane.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")

const GREM := preload("res://content/units/grem.tres")
const BRUTE := preload("res://content/units/grem_brute.tres")
const MILITIA := preload("res://content/units/kingdom_militia.tres")


func _lane() -> FormationLane:
	var lane := FormationLane.new("c", 5, 9.0, 0.1, MILITIA, 3, 5.0)
	lane.apply(WavePresets.line(GREM, 5, 5))
	return lane


func _build(lane: FormationLane, ticks: int) -> Array:
	var events := []
	for i in range(ticks):
		events.append_array(lane.step(false))
	return events


func test_stepping_builds_the_players_wave() -> void:
	var lane := _lane()

	var events := _build(lane, 40)  # a grem takes 2 s: two built

	assert_int(lane.production.built()).is_equal(2)
	assert_bool(events.any(func(e): return e["type"] == "built")).is_true()


func test_painting_a_brute_over_built_grems_banks_the_grems_it_displaces() -> void:
	var lane := _lane()
	_build(lane, 100)  # all five grems built
	lane.brush = BRUTE

	var banked := lane.paint(Vector2i(0, 1), 8)

	assert_int(banked).is_equal(2)  # the brute replaces the grems in columns 1 and 2
	assert_int(lane.production.reserve_count()).is_equal(2)


func test_painting_nothing_new_reports_no_change() -> void:
	var lane := _lane()

	assert_int(lane.paint(Vector2i(0, 7), 8)).is_equal(-1)  # outside the lane's width


func test_erasing_with_no_brush_clears_the_cell() -> void:
	var lane := _lane()
	lane.brush = null

	lane.paint(Vector2i(0, 0), 8)

	assert_int(lane.template.ordered().size()).is_equal(4)


func test_painting_is_limited_by_the_allowance() -> void:
	var lane := _lane()
	lane.brush = GREM

	assert_int(lane.paint(Vector2i(1, 0), 5)).is_equal(-1)  # 5 cells used, none spare
	assert_int(lane.paint(Vector2i(1, 0), 6)).is_equal(0)
	assert_int(lane.cells_used()).is_equal(6)


func test_the_kingdom_steps_only_when_asked() -> void:
	var lane := _lane()
	for i in range(160):
		lane.step(true)  # 3 militia at 5 s each depart automatically at 15 s

	assert_bool(lane.sim.squads().any(func(s): return s.faction_id == "the_kingdom")).is_true()


func test_auto_departure_sends_the_wave_once_full() -> void:
	var lane := _lane()
	lane.set_auto_departure(true)

	var events := _build(lane, 110)  # five grems at 2 s each

	assert_bool(events.any(func(e): return e["type"] == "departed")).is_true()

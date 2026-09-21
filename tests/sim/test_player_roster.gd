extends GdUnitTestSuite
## Regression coverage: found via manual playtest. A composition root recomputing
## "player unit count" purely from LaneSimulation.waves() undercounts once a wave
## auto-extracts (specs/03, Decision 2) - the despawned wave's units are still alive
## (now harvesting), but no longer tracked in any wave, so the count read 0 and fired
## a false defeat. PlayerRoster tracks the "roster + anything on the lane" total
## specs/00's loss condition actually means.

const PlayerRoster = preload("res://sim/player_roster.gd")


func test_total_with_no_harvesting_units_is_just_the_marching_count() -> void:
	var roster := PlayerRoster.new()

	assert_int(roster.total(3)).is_equal(3)


func test_mark_harvesting_adds_to_the_total_even_with_zero_marching_units() -> void:
	var roster := PlayerRoster.new()

	roster.mark_harvesting(3)

	assert_int(roster.total(0)).is_equal(3)


func test_total_combines_harvesting_and_marching_counts() -> void:
	var roster := PlayerRoster.new()
	roster.mark_harvesting(3)

	roster.mark_harvesting(2)

	assert_int(roster.total(4)).is_equal(9)

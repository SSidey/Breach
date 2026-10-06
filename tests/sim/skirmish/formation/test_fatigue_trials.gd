extends GdUnitTestSuite
## FatigueTrials, per Decision 125: a line kept in a long fight tires - blows spend its
## stamina and it never gets its breather - so it pursues a wave that turns away less far
## than a fresh line does, and gives the chase up tired.

const FatigueTrials = preload("res://sim/skirmish/formation/fatigue_trials.gd")


func test_a_line_long_in_contact_pursues_less_and_gives_up_tired() -> void:
	var fresh := FatigueTrials.run(3.0, 1)
	var worn := FatigueTrials.run(60.0, 1)

	assert_float(worn["stamina"]).is_less(fresh["stamina"] - 0.4)
	assert_float(worn["pursued"]).is_less(fresh["pursued"])
	assert_int(fresh["tired"]).is_equal(0)
	assert_int(worn["tired"]).is_equal(1)

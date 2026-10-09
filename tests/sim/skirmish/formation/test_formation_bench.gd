extends GdUnitTestSuite
## A tick has 100 ms at 10 ticks a second (spec 30 round 3). The small battle - 40 grems
## against 40 militia, 10 wide - takes well under that marching and mid-fight
## (tools/formation_bench.gd); the bounds here are loose, three times the budget, so a
## slower machine passes and only a search gone back to looking at everything fails.

const FormationBench = preload("res://sim/skirmish/formation/formation_bench.gd")

const BUDGET_MS := 100.0
const SLACK := 3.0


func test_a_small_battle_keeps_well_within_a_ticks_budget() -> void:
	var result := FormationBench.measure(40, {"width": 10, "march": 5, "settle": 10, "fight": 10})

	assert_int(result["contact"]).is_greater(0)
	assert_float(result["march"][0]).is_less(BUDGET_MS * SLACK)
	assert_float(result["fight"][0]).is_less(BUDGET_MS * SLACK)

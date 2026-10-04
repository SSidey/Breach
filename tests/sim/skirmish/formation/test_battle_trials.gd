extends GdUnitTestSuite
## Battle seeds and trials, per Decision 93: each blow's damage rolls within its band,
## seeded by the battle; the same seed replays a battle exactly, a new one varies it; and
## the trials runner fights a scenario once per seed and summarises the spread.

const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const BattleTrials = preload("res://sim/skirmish/formation/battle_trials.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")


func test_damage_rolls_within_its_band() -> void:
	var seen := {}
	for index in range(200):
		var rolled := BattleRolls.damage(8, 0.25, 7, [index])
		assert_int(rolled).is_between(6, 10)
		seen[rolled] = true

	assert_int(seen.size()).is_greater(2)
	assert_int(BattleRolls.damage(8, 0.0, 7, [1])).is_equal(8)
	assert_int(BattleRolls.damage(1, 0.25, 7, [1])).is_greater_equal(1)


func test_the_same_seed_replays_a_battle() -> void:
	var first := BattleTrials.run("mirror_headon", 1, {"first_seed": 5})
	var again := BattleTrials.run("mirror_headon", 1, {"first_seed": 5})

	assert_array(again).is_equal(first)


func test_new_seeds_vary_a_battle() -> void:
	var rolled := BattleTrials.run("mirror_headon", 6, {"band": 0.25})

	var outcomes := {}
	for result in rolled:
		outcomes[[result["lost"], result["ticks"]]] = true
	assert_int(outcomes.size()).is_greater(1)


func test_a_mirror_fight_is_even_and_a_mirror_flank_is_not() -> void:
	var headon := BattleTrials.summary(BattleTrials.run("mirror_headon", 12))
	var flank := BattleTrials.summary(BattleTrials.run("mirror_flank", 6))

	var lost: Dictionary = headon["lost"]
	assert_float(absf(lost["player"][0] - lost["the_kingdom"][0])).is_less(1.5)
	assert_int(flank["wins"]["player"]).is_equal(6)


func test_a_trial_restores_the_flank_bonus() -> void:
	BattleTrials.run("mirror_headon", 1, {"flank_bonus": 3.0})

	assert_float(FormationCombat.flank_bonus).is_equal(FormationCombat.FLANK_BONUS)

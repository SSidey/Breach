extends GdUnitTestSuite

const CombatResolver = preload("res://sim/combat_resolver.gd")


func test_horde_destroys_blocker_outright_with_zero_casualties() -> void:
	var horde := [{"hp": 10, "dmg": 6}, {"hp": 8, "dmg": 5}]  # total dmg = 11
	var blocker := {"hp": 10, "dmg": 7}

	var outcome := CombatResolver.resolve(horde, blocker)

	assert_bool(outcome["blocker_destroyed"]).is_true()
	assert_int(outcome["remaining_blocker_hp"]).is_equal(0)
	assert_array(outcome["surviving_horde"]).is_equal(horde)


func test_surviving_blocker_retaliates_weakest_unit_first_with_overkill_spill() -> void:
	# Total horde dmg (4+3+2=9) does not destroy a 50-hp blocker.
	var horde := [{"hp": 10, "dmg": 2}, {"hp": 4, "dmg": 3}, {"hp": 6, "dmg": 4}]
	var blocker := {"hp": 50, "dmg": 7}

	var outcome := CombatResolver.resolve(horde, blocker)

	assert_bool(outcome["blocker_destroyed"]).is_false()
	assert_int(outcome["remaining_blocker_hp"]).is_equal(41)

	var survivors: Array = outcome["surviving_horde"]
	# hp-4 unit dies to the first 4 of the 7 retaliation damage; the 3 overkill spills
	# onto the hp-6 unit, leaving it at hp 3. The hp-10 unit is untouched.
	assert_int(survivors.size()).is_equal(2)
	assert_int(survivors[0]["hp"]).is_equal(3)
	assert_int(survivors[1]["hp"]).is_equal(10)


func test_blocker_survives_and_wipes_the_entire_horde() -> void:
	var horde := [{"hp": 2, "dmg": 1}, {"hp": 3, "dmg": 1}]  # total dmg = 2
	var blocker := {"hp": 50, "dmg": 10}

	var outcome := CombatResolver.resolve(horde, blocker)

	assert_bool(outcome["blocker_destroyed"]).is_false()
	assert_array(outcome["surviving_horde"]).is_empty()


func test_blocker_exactly_destroyed_counts_as_destroyed() -> void:
	var horde := [{"hp": 5, "dmg": 10}]
	var blocker := {"hp": 10, "dmg": 3}

	var outcome := CombatResolver.resolve(horde, blocker)

	assert_bool(outcome["blocker_destroyed"]).is_true()

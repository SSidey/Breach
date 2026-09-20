extends GdUnitTestSuite

const EconomySystem = preload("res://sim/economy_system.gd")


func test_new_pool_starts_at_zero() -> void:
	var economy := EconomySystem.new()

	assert_int(economy.balance("food")).is_equal(0)


func test_add_increases_balance() -> void:
	var economy := EconomySystem.new()

	economy.add("food", 10)
	economy.add("food", 5)

	assert_int(economy.balance("food")).is_equal(15)


func test_spend_decreases_balance_when_sufficient() -> void:
	var economy := EconomySystem.new()
	economy.add("wood", 10)

	var spent := economy.spend("wood", 4)

	assert_bool(spent).is_true()
	assert_int(economy.balance("wood")).is_equal(6)


func test_spend_fails_and_leaves_balance_unchanged_when_insufficient() -> void:
	var economy := EconomySystem.new()
	economy.add("stone", 3)

	var spent := economy.spend("stone", 10)

	assert_bool(spent).is_false()
	assert_int(economy.balance("stone")).is_equal(3)


func test_pools_are_independent() -> void:
	var economy := EconomySystem.new()

	economy.add("metal", 7)

	assert_int(economy.balance("metal")).is_equal(7)
	assert_int(economy.balance("crystal")).is_equal(0)


func test_decayed_yield_with_zero_intervals_elapsed_returns_base_yield() -> void:
	var economy := EconomySystem.new()

	var result := economy.decayed_yield(10, 0, 5, 2)

	assert_int(result).is_equal(10)


func test_decayed_yield_drops_by_ten_percent_after_one_interval() -> void:
	var economy := EconomySystem.new()

	# base 10, one decay_interval_ticks(=5)-sized interval elapsed (ticks_elapsed=5)
	var result := economy.decayed_yield(10, 5, 5, 2)

	assert_int(result).is_equal(9)


func test_decayed_yield_floors_after_enough_intervals() -> void:
	var economy := EconomySystem.new()

	# 20 intervals of -10% decay from a base of 10 would fall well below the floor.
	var result := economy.decayed_yield(10, 100, 5, 2)

	assert_int(result).is_equal(2)


func test_decayed_yield_does_not_go_below_the_floor_even_with_a_floor_of_zero() -> void:
	var economy := EconomySystem.new()

	var result := economy.decayed_yield(10, 1000, 5, 0)

	assert_int(result).is_equal(0)

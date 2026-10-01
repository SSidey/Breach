extends GdUnitTestSuite
## SkirmishSlotPool, per specs/22-formation-feel-test.md and Decision 40: one pool of
## unlocked slots, split across lanes as the player chooses.

const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")


func _pool() -> SkirmishSlotPool:
	return SkirmishSlotPool.new(8, {"c": 20, "k": 16})


func test_lanes_start_empty_and_everything_is_free() -> void:
	var pool := _pool()

	assert_int(pool.assigned("c")).is_equal(0)
	assert_int(pool.free_slots()).is_equal(8)


func test_an_assignment_is_clamped_to_what_is_free() -> void:
	var pool := _pool()
	pool.assign("k", 3)

	assert_int(pool.assign("c", 6)).is_equal(5)
	assert_int(pool.free_slots()).is_equal(0)


func test_any_split_is_allowed_including_nothing_on_a_lane() -> void:
	var pool := _pool()

	pool.assign("c", 8)
	assert_int(pool.assigned("k")).is_equal(0)
	pool.assign("c", 0)
	pool.assign("k", 8)
	assert_int(pool.assigned("k")).is_equal(8)


func test_each_lane_is_capped_by_its_own_limit() -> void:
	var pool := SkirmishSlotPool.new(40, {"c": 20, "k": 16})

	assert_int(pool.assign("k", 30)).is_equal(16)


func test_the_total_never_exceeds_the_pool() -> void:
	var pool := _pool()
	pool.assign("c", 5)
	pool.assign("k", 5)

	assert_int(pool.assigned("c") + pool.assigned("k")).is_equal(8)

extends GdUnitTestSuite
## Each cell's speed share cached per kind of walker (spec 30): a lookup gives what the
## terrain's crossing gives, walkers of one kind share the cache, and painting the ground
## drops it.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const WalkerShares = preload("res://sim/skirmish/formation/walker_shares.gd")


func _ground() -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(8, 6))
	ground.paint(Rect2i(3, 0, 1, 6), {"cost": 0.5, "height": 2})
	ground.paint(Rect2i(5, 0, 1, 6), {"depth": 1.2})
	ground.paint(Rect2i(6, 0, 2, 6), {"height": 8})
	return ground


func test_a_share_looked_up_is_the_crossing_and_none_leaves_the_grid() -> void:
	var ground := _ground()
	var walker := TerrainWalker.new(1.0)
	var shares := WalkerShares.of(ground, walker)
	var centre := Vector2(0.5, 0.5)

	for index in 8 * 6:
		var cell := Vector2i(index % 8, index / 8)
		for step in WalkerShares.STEPS.size():
			var next: Vector2i = cell + WalkerShares.STEPS[step]
			var expected := 0.0
			if Rect2i(0, 0, 8, 6).has_point(next):
				expected = ground.crossing(walker, Vector2(cell) + centre, Vector2(next) + centre)
			assert_float(shares.into(index, step)).is_equal_approx(expected, 0.000001)


func test_walkers_of_one_kind_share_a_cache_that_painting_drops() -> void:
	var ground := _ground()
	var one := WalkerShares.of(ground, TerrainWalker.new(1.0))

	assert_object(WalkerShares.of(ground, TerrainWalker.new(1.0))).is_same(one)
	assert_object(WalkerShares.of(ground, TerrainWalker.new(1.0, 0, 2))).is_not_same(one)
	assert_object(WalkerShares.of(ground, TerrainWalker.new(1.5))).is_not_same(one)
	assert_float(one.into(1 * 8 + 2, 0)).is_less(1.0)  # into the wood up the slope
	ground.paint(Rect2i(3, 0, 1, 6), {"cost": 1.0, "height": 0})
	var fresh := WalkerShares.of(ground, TerrainWalker.new(1.0))
	assert_object(fresh).is_not_same(one)
	assert_float(fresh.into(1 * 8 + 2, 0)).is_equal(1.0)

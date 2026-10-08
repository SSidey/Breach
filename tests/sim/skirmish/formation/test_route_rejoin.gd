extends GdUnitTestSuite
## Rejoining a route by time to the goal (spec 30): a group off its route rejoins it where
## the walk to it plus the march along it to its end is quickest; of the ways within
## path_rejoin_slack (3%) of the quickest, it takes the one back on the route soonest. It
## doesn't double back when a point ahead is quicker, and does when that is the only way.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const RouteRejoin = preload("res://sim/skirmish/formation/route_rejoin.gd")

const WALL := {"height": 8, "climb": 3}
const FROM := Vector2(20.5, 14.5)


func _grem() -> TerrainWalker:
	return TerrainWalker.new(1.0)


func _east() -> FormationRoute:
	return FormationRoute.new(PackedVector2Array([Vector2(0, 20.5), Vector2(60, 20.5)]))


func test_the_march_along_the_route_is_timed_at_the_walkers_pace() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(40, 0, 10, 30), {"cost": 0.5})
	var rejoin := RouteRejoin.new(ground, _grem(), _east(), 0.0)

	assert_float(rejoin.march(55.0)).is_equal_approx(5.0, 0.01)
	assert_float(rejoin.march(30.0)).is_equal_approx(10.0 + 20.0 + 10.0, 0.01)
	assert_float(rejoin.march(60.0)).is_equal_approx(0.0, 0.01)


func test_it_rejoins_ahead_soonest_within_the_slack_of_the_quickest() -> void:
	var open := FormationTerrain.new(Vector2i(60, 30))
	var back := TerrainPaths.rejoin(open, _grem(), FROM, _east())

	# On the grid every rejoin from 6 diagonals on (at 26.5) ties as quickest, 41.99 s; at
	# 24.5 it is 43.16 s, within 3%; at 23.5 43.74 s, not. Straight down (20.5) is 45.5 s.
	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_equal_approx(24.5, 0.0001)
	var tuning := BattleTuning.current()
	var slack: float = tuning.path_rejoin_slack
	assert_float(slack).is_equal(0.03)
	tuning.path_rejoin_slack = 0.0
	var quickest: Dictionary = TerrainPaths.rejoin(open, _grem(), FROM, _east())
	tuning.path_rejoin_slack = slack
	assert_float(quickest["along"]).is_equal_approx(26.5, 0.0001)  # soonest of the quickest


func test_it_goes_round_an_obstacle_ahead_rather_than_back() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(13, 17, 15, 2), WALL)  # centred on the group: either way is as near
	var back := TerrainPaths.rejoin(ground, _grem(), FROM, _east())

	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_greater(28.0)


func test_it_doubles_back_when_that_is_the_only_way() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(10, 17, 50, 2), WALL)  # to the field's east edge
	var back := TerrainPaths.rejoin(ground, _grem(), FROM, _east())

	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_less(12.0)


func test_the_ground_and_route_mirrored_give_the_rejoin_mirrored() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(14, 17, 12, 2), WALL)
	var mirrored := FormationTerrain.new(Vector2i(60, 30))
	mirrored.paint(Rect2i(60 - 26, 17, 12, 2), WALL)
	var west := FormationRoute.new(PackedVector2Array([Vector2(60, 20.5), Vector2(0, 20.5)]))
	var there := TerrainPaths.rejoin(ground, _grem(), FROM, _east())
	var back := TerrainPaths.rejoin(mirrored, _grem(), Vector2(60.0 - FROM.x, FROM.y), west)

	assert_float(back["along"]).is_equal_approx(there["along"], 0.0001)
	assert_int(back["cells"].size()).is_equal(there["cells"].size())
	for index in there["cells"].size():
		var cell: Vector2i = there["cells"][index]
		assert_object(back["cells"][index]).is_equal(Vector2i(59 - cell.x, cell.y))


func test_with_no_way_to_the_route_there_is_no_rejoin() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(0, 17, 60, 2), WALL)
	var back := TerrainPaths.rejoin(ground, _grem(), FROM, _east())

	assert_bool(back["reaches"]).is_false()
	assert_array(back["cells"]).is_empty()

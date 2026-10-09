extends GdUnitTestSuite
## Rejoining a route (spec 30, the user's rule): one outward search by walking time from
## the group over the ground it knows (unseen counts as open), stopping at the first route
## point reached that lies ahead of where the group left the route - its furthest progress
## along it. With no point ahead in reach it takes the first point behind: it doubles
## back only when that is the only way. The route is a guide, no faster than open ground,
## so the nearest point ahead is near enough the quickest to the goal.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const PathSearch = preload("res://sim/skirmish/formation/path_search.gd")

const WALL := {"height": 8, "climb": 3}
const RIVER := {"depth": 2.0}
const FROM := Vector2(20.5, 14.5)
const LEFT_AT := 20.5  # how far along the route the group was when it left it


func _grem() -> TerrainWalker:
	return TerrainWalker.new(1.0)


func _east() -> FormationRoute:
	return FormationRoute.new(PackedVector2Array([Vector2(0, 20.5), Vector2(60, 20.5)]))


## A river, too deep for a grem that can't swim, cutting the group off from the route
## below it and ahead (it crosses the route there): open only to the west, behind it.
func _cut_off(rows_first: bool = false) -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	var areas := [Rect2i(24, 0, 2, 30), Rect2i(16, 17, 8, 2), Rect2i(16, 19, 2, 11)]
	if rows_first:
		areas.reverse()
	for area in areas:
		ground.paint(area, RIVER)
	return ground


func _rejoin(ground: FormationTerrain, walker: TerrainWalker = _grem()) -> Dictionary:
	return TerrainPaths.rejoin(ground, walker, FROM, _east(), null, null, LEFT_AT)


func test_on_open_ground_it_rejoins_at_or_just_ahead_of_where_it_left() -> void:
	var back := _rejoin(FormationTerrain.new(Vector2i(60, 30)))

	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_between(20.0, 22.0)


func test_round_a_wall_it_rejoins_beyond_the_far_end_ahead() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(13, 17, 15, 2), WALL)  # centred on the group: either end as near
	var back := _rejoin(ground)

	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_greater(27.0)


func test_cut_off_by_a_river_it_doubles_back() -> void:
	var back := _rejoin(_cut_off(), TerrainWalker.grounded(1.0))

	assert_bool(back["reaches"]).is_true()
	assert_float(back["along"]).is_less(16.0)


func test_the_same_ground_gives_the_same_rejoin_whatever_was_painted_first() -> void:
	var grounded := TerrainWalker.grounded(1.0)
	assert_array(_rejoin(_cut_off(true), grounded)["cells"]).is_equal(
		_rejoin(_cut_off(), grounded)["cells"]
	)


func test_the_ground_and_route_mirrored_give_the_rejoin_mirrored() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(14, 17, 12, 2), WALL)
	var mirrored := FormationTerrain.new(Vector2i(60, 30))
	mirrored.paint(Rect2i(60 - 26, 17, 12, 2), WALL)
	var west := FormationRoute.new(PackedVector2Array([Vector2(60, 20.5), Vector2(0, 20.5)]))
	var there := _rejoin(ground)
	var back := TerrainPaths.rejoin(
		mirrored, _grem(), Vector2(60.0 - FROM.x, FROM.y), west, null, null, LEFT_AT
	)

	assert_float(back["along"]).is_equal_approx(there["along"], 0.0001)
	assert_int(back["cells"].size()).is_equal(there["cells"].size())
	for index in there["cells"].size():
		var cell: Vector2i = there["cells"][index]
		assert_object(back["cells"][index]).is_equal(Vector2i(59 - cell.x, cell.y))


func test_with_no_way_to_the_route_there_is_no_rejoin() -> void:
	var ground := FormationTerrain.new(Vector2i(60, 30))
	ground.paint(Rect2i(0, 17, 60, 2), WALL)
	var back := _rejoin(ground)

	assert_bool(back["reaches"]).is_false()
	assert_array(back["cells"]).is_empty()


func test_the_search_stops_at_the_first_point_ahead_so_it_stays_small() -> void:
	var open := PathSearch.new(FormationTerrain.new(Vector2i(60, 30)), _grem(), Vector2i(20, 14))
	open.to_route(_east(), LEFT_AT)
	var walled := FormationTerrain.new(Vector2i(60, 30))
	walled.paint(Rect2i(13, 17, 15, 2), WALL)
	var round := PathSearch.new(walled, _grem(), Vector2i(20, 14))
	round.to_route(_east(), LEFT_AT)

	assert_int(open.expanded).is_less_equal(30)
	assert_int(round.expanded).is_less(200)

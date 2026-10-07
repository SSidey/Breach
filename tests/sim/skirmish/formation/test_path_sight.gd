extends GdUnitTestSuite
## Planning on what is seen (spec 30): no leash; a pathfinder's sight has a shape (far
## ahead, nearer to the sides, near behind), seen cells cost what they cost, unseen ones
## count as open, and where the best plan runs out of sight it heads for that edge - so a
## wall is felt along until the gap comes into view, what it has seen remembered.
## Rejoining a route plans to the nearest place on it in sight. Mirrored ground and sight
## give the plan mirrored.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const PathSight = preload("res://sim/skirmish/formation/path_sight.gd")
const PathMemory = preload("res://sim/skirmish/formation/path_memory.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const START := Vector2(5.5, 4.5)
const GOAL := Vector2(35.5, 4.5)
const GAP := Rect2i(20, 22, 2, 8)
const WALL := {"height": 8, "climb": 3}


func _grem() -> TerrainWalker:
	return TerrainWalker.new(1.0)


func _eyes(at: Vector2, way: Vector2) -> PathSight:
	return PathSight.new(at, way, 20.0, 10.0, 5.0)


## A wall across the north of the field, x 20-21, open to the south from y 22.
func _walled(mirrored: bool = false) -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(40, 30))
	ground.paint(Rect2i(18 if mirrored else 20, 0, 2, 22), WALL)
	return ground


func _touches(cells: Array, area: Rect2i) -> bool:
	return cells.any(func(cell): return area.has_point(cell))


func test_sight_has_a_shape_far_ahead_near_behind() -> void:
	var sight := PathSight.new(Vector2.ZERO, Vector2.RIGHT, 20.0, 10.0, 5.0)

	assert_bool(sight.sees(Vector2(19.5, 0))).is_true()
	assert_bool(sight.sees(Vector2(20.5, 0))).is_false()
	assert_bool(sight.sees(Vector2(0, 9.5))).is_true()
	assert_bool(sight.sees(Vector2(0, -10.5))).is_false()
	assert_bool(sight.sees(Vector2(-4.5, 0))).is_true()
	assert_bool(sight.sees(Vector2(-5.5, 0))).is_false()
	assert_float(sight.reach(Vector2(1, 1).normalized())).is_equal_approx(15.0, 0.0001)
	var grem := UnitDef.new()
	var shaped := PathSight.of(grem, Vector2.ZERO, Vector2.UP)
	assert_float(shaped.ahead).is_equal(grem.detection_range * grem.sight_ahead)
	assert_float(shaped.behind).is_equal(grem.detection_range * grem.sight_behind)


func test_a_goal_in_sight_is_reached_and_one_beyond_is_planned_towards() -> void:
	var open := FormationTerrain.new(Vector2i(40, 30))
	var near := TerrainPaths.plan(
		open, _grem(), START, Vector2(15.5, 4.5), _eyes(START, Vector2.RIGHT)
	)
	var far := TerrainPaths.plan(open, _grem(), START, GOAL, _eyes(START, Vector2.RIGHT))

	assert_bool(near["reaches"]).is_true()
	assert_array(near["waypoints"]).is_equal(PackedVector2Array([START, Vector2(15.5, 4.5)]))
	assert_bool(far["reaches"]).is_false()
	assert_int(far["cells"].back().y).is_equal(4)  # straight on, to the edge of sight ahead
	assert_int(far["cells"].back().x).is_greater(22)


func test_what_it_cannot_see_counts_as_open() -> void:
	var blind := FormationTerrain.new(Vector2i(60, 12))
	blind.paint(Rect2i(40, 0, 2, 11), WALL)  # a wall far ahead, its gap at y 11
	var start := Vector2(2.5, 5.5)
	var goal := Vector2(57.5, 5.5)
	var planned := TerrainPaths.plan(blind, _grem(), start, goal, _eyes(start, Vector2.RIGHT))

	assert_bool(planned["reaches"]).is_false()
	assert_bool(planned["cells"].all(func(cell): return cell.y == 5)).is_true()
	(
		assert_bool(_touches(TerrainPaths.cells(blind, _grem(), start, goal), Rect2i(40, 11, 2, 1)))
		. is_true()
	)


func test_a_wall_is_felt_along_until_the_gap_comes_into_view() -> void:
	var ground := _walled()
	var first := TerrainPaths.plan(ground, _grem(), START, GOAL, _eyes(START, Vector2.RIGHT))
	assert_bool(first["reaches"]).is_false()
	var edge: Vector2i = first["cells"].back()
	assert_int(edge.x).is_less(20)
	assert_int(edge.y).is_greater(4)  # along the wall, south, the only way open

	var walked := []
	var at := START
	var way := Vector2.RIGHT
	var planned := first
	var memory := PathMemory.new()
	for attempt in 12:
		planned = TerrainPaths.plan(ground, _grem(), at, GOAL, _eyes(at, way), memory)
		walked.append_array(planned["cells"])
		if planned["reaches"]:
			break
		var points: PackedVector2Array = planned["waypoints"]
		way = (points[-1] - points[-2]).normalized()
		at = points[-1]
	assert_bool(planned["reaches"]).is_true()
	assert_bool(_touches(walked, GAP)).is_true()


func test_mirrored_ground_and_sight_give_the_plan_mirrored() -> void:
	var flip := func(at: Vector2) -> Vector2: return Vector2(40.0 - at.x, at.y)
	var plan := TerrainPaths.plan(_walled(), _grem(), START, GOAL, _eyes(START, Vector2.RIGHT))
	var back := TerrainPaths.plan(
		_walled(true),
		_grem(),
		flip.call(START),
		flip.call(GOAL),
		_eyes(flip.call(START), Vector2.LEFT)
	)

	assert_int(back["cells"].size()).is_equal(plan["cells"].size())
	for index in plan["cells"].size():
		var cell: Vector2i = plan["cells"][index]
		assert_object(back["cells"][index]).is_equal(Vector2i(39 - cell.x, cell.y))


func _route() -> FormationRoute:
	return FormationRoute.new(PackedVector2Array([Vector2(0, 20.5), Vector2(40, 20.5)]))


func test_rejoining_a_route_plans_to_the_nearest_place_on_it_in_sight() -> void:
	var open := FormationTerrain.new(Vector2i(40, 30))
	var from := Vector2(10.5, 10.5)
	var back := TerrainPaths.rejoin(open, _grem(), from, _route(), _eyes(from, Vector2.DOWN))

	assert_bool(back["reaches"]).is_true()
	assert_object(back["cells"].back()).is_equal(Vector2i(10, 20))
	assert_float(back["along"]).is_equal_approx(10.5, 0.0001)
	var walled := FormationTerrain.new(Vector2i(40, 30))
	walled.paint(Rect2i(0, 15, 15, 2), WALL)
	var round := TerrainPaths.rejoin(walled, _grem(), from, _route(), _eyes(from, Vector2.DOWN))
	assert_bool(round["reaches"]).is_true()
	assert_bool(_touches(round["cells"], Rect2i(15, 15, 25, 2))).is_true()


func test_on_the_route_it_is_already_there_and_out_of_sight_it_heads_for_it() -> void:
	var open := FormationTerrain.new(Vector2i(40, 30))
	var on := Vector2(10.5, 20.5)
	var there := TerrainPaths.rejoin(open, _grem(), on, _route(), _eyes(on, Vector2.RIGHT))
	var from := Vector2(10.5, 3.5)
	var short := PathSight.new(from, Vector2.RIGHT, 6.0, 3.0, 2.0)
	var toward := TerrainPaths.rejoin(open, _grem(), from, _route(), short)

	assert_bool(there["reaches"]).is_true()
	assert_array(there["cells"]).is_equal([Vector2i(10, 20)])
	assert_bool(toward["reaches"]).is_false()
	assert_float(toward["along"]).is_equal(-1.0)
	assert_int(toward["cells"].back().y).is_greater(4)

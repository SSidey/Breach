extends GdUnitTestSuite
## Paths over the terrain grid, per spec 30 round 3 (Decisions 64, 75, 85 and 97): a unit
## goes the way that takes it least time at its own pace on each cell - round a wood,
## through a ford rather than swimming, swimming where no ford is in reach, over a cliff
## if it climbs; the leash bounds how far aside the search looks; the same ground mirrored
## gives the same path mirrored, ties going to geometry.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const ItemDef = preload("res://content/definitions/item_def.gd")


func _grem() -> TerrainWalker:
	return TerrainWalker.new(1.0)


func _touches(cells: Array, area: Rect2i) -> bool:
	return cells.any(func(cell): return area.has_point(cell))


func _stream(ford: bool) -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(24, 12))
	ground.paint(Rect2i(10, 0, 3, 12), {"depth": 1.2})
	if ford:
		ground.paint(Rect2i(10, 1, 3, 2), {"depth": 0.4})
	return ground


func _across(ground: FormationTerrain, walker: TerrainWalker) -> Array:
	return TerrainPaths.cells(ground, walker, Vector2(2.5, 6.5), Vector2(21.5, 6.5))


func test_a_unit_goes_round_a_wood_when_that_is_quicker() -> void:
	var ground := FormationTerrain.new(Vector2i(20, 12))
	ground.paint(Rect2i(8, 0, 4, 9), {"cost": 0.5})
	var cells := TerrainPaths.cells(ground, _grem(), Vector2(2.5, 5.5), Vector2(17.5, 5.5))

	assert_array(cells).is_not_empty()
	assert_bool(_touches(cells, Rect2i(8, 0, 4, 9))).is_false()
	assert_object(cells.back()).is_equal(Vector2i(17, 5))


func test_a_ford_is_preferred_to_swimming_by_cost_alone() -> void:
	var cells := _across(_stream(true), _grem())

	assert_bool(_touches(cells, Rect2i(10, 1, 3, 2))).is_true()
	assert_bool(_touches(cells, Rect2i(10, 3, 3, 9))).is_false()
	assert_bool(_touches(cells, Rect2i(10, 0, 3, 1))).is_false()


func test_with_no_ford_in_reach_a_unit_swims_and_a_non_swimmer_cannot_cross() -> void:
	assert_bool(_touches(_across(_stream(false), _grem()), Rect2i(10, 0, 3, 12))).is_true()
	assert_array(_across(_stream(false), TerrainWalker.new(1.0, 0, 0, false))).is_empty()


func test_a_loaded_or_sinking_unit_refuses_deep_water() -> void:
	var loaded := UnitDef.new()
	var pack := ItemDef.new()
	pack.weight = 19.0
	loaded.items = [pack]
	var cart := UnitDef.new()
	cart.traits = {"sinks": 1}

	for unit_def in [loaded, cart]:
		var walker := TerrainWalker.of(unit_def)
		assert_array(_across(_stream(false), walker)).is_empty()
		assert_bool(_touches(_across(_stream(true), walker), Rect2i(10, 1, 3, 2))).is_true()


func test_a_cliff_blocks_a_non_climber_and_slows_one_a_level_short() -> void:
	var ground := FormationTerrain.new(Vector2i(20, 8))
	ground.paint(Rect2i(10, 0, 10, 8), {"height": 8, "climb": 2})
	var start := Vector2(3.5, 3.5)
	var goal := Vector2(15.5, 3.5)
	var short := TerrainWalker.new(1.0, 0, 1)
	var able := TerrainWalker.new(1.0, 0, 2)

	assert_array(TerrainPaths.cells(ground, TerrainWalker.new(1.0), start, goal)).is_empty()
	var slow := TerrainPaths.find(ground, short, start, goal)
	var quick := TerrainPaths.find(ground, able, start, goal)
	assert_array(slow).is_not_empty()
	assert_float(TerrainPaths.cost(ground, short, slow)).is_greater(
		TerrainPaths.cost(ground, able, quick)
	)


func test_the_leash_bounds_how_far_aside_the_search_looks() -> void:
	var ground := FormationTerrain.new(Vector2i(30, 40))
	ground.paint(Rect2i(14, 0, 2, 34), {"height": 8, "climb": 3})
	var start := Vector2(3.5, 4.5)
	var goal := Vector2(26.5, 4.5)

	assert_array(TerrainPaths.cells(ground, _grem(), start, goal, 8.0)).is_empty()
	var way := TerrainPaths.find(ground, _grem(), start, goal, 32.0)
	assert_array(way).is_not_empty()
	var length := 0.0
	for index in range(1, way.size()):
		length += way[index - 1].distance_to(way[index])
	assert_float(length).is_greater(32.0)  # once found, it is followed past the leash


func test_no_corner_is_cut_between_impassable_cells() -> void:
	var ground := FormationTerrain.new(Vector2i(10, 10))
	ground.paint(Rect2i(4, 4, 1, 1), {"height": 8, "climb": 3})
	ground.paint(Rect2i(5, 5, 1, 1), {"height": 8, "climb": 3})
	var cells := TerrainPaths.cells(ground, _grem(), Vector2(4.5, 5.5), Vector2(5.5, 4.5))

	assert_int(cells.size()).is_greater(2)


func test_open_ground_gives_a_straight_line_hugged_by_its_cells() -> void:
	var ground := FormationTerrain.new(Vector2i(20, 10))
	var start := Vector2(1.5, 1.5)
	var goal := Vector2(13.5, 5.5)

	for cell in TerrainPaths.cells(ground, _grem(), start, goal):
		var centre := Vector2(cell) + Vector2(0.5, 0.5)
		var nearest := Geometry2D.get_closest_point_to_segment(centre, start, goal)
		assert_float(centre.distance_to(nearest)).is_less(0.8)
	assert_array(TerrainPaths.find(ground, _grem(), start, goal)).is_equal(
		PackedVector2Array([start, goal])
	)


func _mirrorable(mirrored: bool) -> FormationTerrain:
	var ground := FormationTerrain.new(Vector2i(24, 16))
	var areas := [Rect2i(6, 2, 3, 8), Rect2i(12, 0, 2, 11), Rect2i(16, 10, 4, 4)]
	var props := [{"cost": 0.5}, {"height": 8, "climb": 3}, {"depth": 1.2}]
	for index in areas.size():
		var area: Rect2i = areas[index]
		if mirrored:
			area.position.x = 24 - area.end.x
		ground.paint(area, props[index])
	return ground


func test_the_ground_mirrored_gives_the_path_mirrored() -> void:
	var start := Vector2(2.5, 6.5)
	var goal := Vector2(21.5, 12.5)
	var flip := func(at: Vector2) -> Vector2: return Vector2(24.0 - at.x, at.y)
	var cells := TerrainPaths.cells(_mirrorable(false), _grem(), start, goal)
	var mirrored := TerrainPaths.cells(
		_mirrorable(true), _grem(), flip.call(start), flip.call(goal)
	)

	assert_array(cells).is_not_empty()
	assert_int(mirrored.size()).is_equal(cells.size())
	for index in cells.size():
		assert_object(mirrored[index]).is_equal(Vector2i(23 - cells[index].x, cells[index].y))
	var way := TerrainPaths.find(_mirrorable(false), _grem(), start, goal)
	var back := TerrainPaths.find(_mirrorable(true), _grem(), flip.call(start), flip.call(goal))
	for index in way.size():
		assert_vector(back[index]).is_equal_approx(flip.call(way[index]), Vector2.ONE * 0.0001)


func test_the_same_ground_gives_the_same_path_whatever_was_painted_first() -> void:
	var first := FormationTerrain.new(Vector2i(24, 16))
	first.paint(Rect2i(6, 2, 3, 8), {"cost": 0.5})
	first.paint(Rect2i(12, 0, 2, 11), {"height": 8, "climb": 3})
	var second := FormationTerrain.new(Vector2i(24, 16))
	second.paint(Rect2i(12, 0, 2, 11), {"height": 8, "climb": 3})
	second.paint(Rect2i(6, 2, 3, 8), {"cost": 0.5})
	var start := Vector2(2.5, 6.5)
	var goal := Vector2(21.5, 12.5)

	var path := TerrainPaths.cells(first, _grem(), start, goal)
	assert_array(TerrainPaths.cells(second, _grem(), start, goal)).is_equal(path)
	assert_array(TerrainPaths.cells(first, _grem(), start, goal)).is_equal(path)

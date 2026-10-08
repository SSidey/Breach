extends GdUnitTestSuite
## The path trials (spec 30): paths over the feel test's field for a grem, a loaded
## militiaman, a cart that neither swims nor climbs and a climber, with a crag added for
## the climber - each its own way by its own costs, drawn as text and timed - planning on
## what a grem sees, rejoining a route, and a grem feeling along a wall to its gap.

const PathTrials = preload("res://sim/skirmish/formation/path_trials.gd")
const SightTrials = preload("res://sim/skirmish/formation/sight_trials.gd")


func _row(rows: Array, trip: String, walker: String) -> Dictionary:
	for row in rows:
		if row["trip"] == trip and row["walker"] == walker:
			return row
	return {}


func _touches(cells: Array, area: Rect2i) -> bool:
	return cells.any(func(cell): return area.has_point(cell))


func test_each_walker_goes_its_own_way_over_the_field_drawn_as_text() -> void:
	var rows := PathTrials.run(1)
	var deep := Rect2i(28, 0, 3, 19)  # the stream above its ford

	assert_int(rows.size()).is_equal(PathTrials.TRIPS.size() * PathTrials.WALKERS.size())
	assert_bool(_touches(_row(rows, "stream", "grem")["cells"], deep)).is_true()
	for walker in ["loaded militiaman", "cart (sinks)"]:
		var cells: Array = _row(rows, "stream", walker)["cells"]
		assert_array(cells).is_not_empty()
		assert_bool(_touches(cells, deep)).is_false()
	assert_bool(_touches(_row(rows, "across", "climber")["cells"], PathTrials.CRAG)).is_true()
	assert_bool(_touches(_row(rows, "across", "grem")["cells"], PathTrials.CRAG)).is_false()
	assert_bool(_row(rows, "sight 40 ahead", "grem")["reaches"]).is_false()
	var back := _row(rows, "rejoin route A", "grem")
	assert_bool(back["reaches"]).is_true()
	assert_int(absi(back["cells"].back().y * 2 + 1 - 64)).is_less_equal(1)  # on y = 32
	assert_float(back["along"]).is_between(50.0, 52.0)  # at or just ahead of where it left
	var drawn := PathTrials.drawing(
		_row(rows, "stream", "grem")["cells"], PathTrials.STREAM_VIEW, 1
	)
	assert_int(drawn.size()).is_equal(PathTrials.STREAM_VIEW.size.y)
	assert_bool("\n".join(drawn).contains("*")).is_true()
	assert_bool("\n".join(drawn).contains("~")).is_true()


func test_a_grem_feels_along_the_wall_to_its_gap() -> void:
	var walk := SightTrials.feel_along()

	assert_bool(walk["reaches"]).is_true()
	assert_int(walk["plans"]).is_greater(1)
	assert_bool(_touches(walk["cells"], SightTrials.GAP)).is_true()

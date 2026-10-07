extends GdUnitTestSuite
## The path trial (spec 30 round 3): paths over the feel test's field for a grem, a loaded
## militiaman, a cart that sinks and a climber, with a crag added for the climber - each
## going its own way by its own costs, drawn as text and timed.

const PathTrials = preload("res://sim/skirmish/formation/path_trials.gd")


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
	var drawn := PathTrials.drawing(
		_row(rows, "stream", "grem")["cells"], PathTrials.STREAM_VIEW, 1
	)
	assert_int(drawn.size()).is_equal(PathTrials.STREAM_VIEW.size.y)
	assert_bool("\n".join(drawn).contains("*")).is_true()
	assert_bool("\n".join(drawn).contains("~")).is_true()

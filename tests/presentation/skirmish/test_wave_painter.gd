extends GdUnitTestSuite
## WavePainter, per Decision 43: the front of the formation is on the right (the direction
## of travel) - ranks run right to left, formation columns top to bottom.

const WavePainter = preload("res://presentation/skirmish/formation/wave_painter.gd")


func test_the_rightmost_display_column_is_the_front_rank() -> void:
	var painter: WavePainter = auto_free(WavePainter.new())
	var cell := WavePainter.CELL

	var front := painter.cell_at(
		Vector2((WavePainter.RANKS - 0.5) * cell, WavePainter.TOP + 0.5 * cell)
	)
	var back_bottom := painter.cell_at(Vector2(0.5 * cell, WavePainter.TOP + 2.5 * cell))

	assert_object(front).is_equal(Vector2i(0, 0))  # rank 0, formation column 0
	assert_object(back_bottom).is_equal(Vector2i(WavePainter.RANKS - 1, 2))


func test_a_click_on_a_covered_cell_erases_and_on_an_empty_cell_paints() -> void:
	var painter: WavePainter = auto_free(WavePainter.new())
	painter.places = [[0, 1, 2, 2, true]]  # a brute at ranks 0-1, columns 1-2

	assert_bool(painter.covers(Vector2i(1, 2))).is_true()
	assert_bool(painter.covers(Vector2i(0, 0))).is_false()

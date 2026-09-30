class_name WavePainter
extends Control
## Paints a lane's wave template (Decision 42, specs/22-formation-feel-test.md): an 8 x 4
## grid, front rank at the top, columns past the lane's width shaded. Template places are
## outlined; built ones are filled, the one being built fills with its progress. Left
## click or drag paints with the lane's brush, right click erases - the scene applies the
## change at once (built units fold in, leftovers are banked).

signal painted(cell: Vector2i)
signal erased(cell: Vector2i)

const CELL := 20.0
const TOP := 14.0
const COLUMNS := 8
const RANKS := 4

## Columns this lane allows (the rest are shaded).
var lane_width := COLUMNS
## [[rank, column, depth, width, filled], ...] from FormationProduction.preview().
var places := []
var progress := 0.0
var fill_color := Color("#b3761d")

var _last_cell := Vector2i(-1, -1)


func _ready() -> void:
	custom_minimum_size = Vector2(COLUMNS * CELL + 2.0, TOP + RANKS * CELL + 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.y - TOP) / CELL), floori(point.x / CELL))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_last_cell = Vector2i(-1, -1)
		_act(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
	elif (
		event is InputEventMouseMotion
		and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)
	):
		_act(event.position, event.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0)


func _act(point: Vector2, erase: bool) -> void:
	var cell := cell_at(point)
	if cell == _last_cell or cell.x < 0 or cell.y < 0 or cell.x >= RANKS or cell.y >= lane_width:
		return
	_last_cell = cell
	if erase:
		erased.emit(cell)
	else:
		painted.emit(cell)
	accept_event()


func _draw() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, TOP - 3.0),
		"front ▲",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(1, 1, 1, 0.7)
	)
	for rank in range(RANKS):
		for column in range(COLUMNS):
			var usable := column < lane_width
			var shade := Color(1, 1, 1, 0.12) if usable else Color(0, 0, 0, 0.35)
			draw_rect(_rect(rank, column, 1, 1).grow(-1.0), shade)
	var in_progress := places.find_custom(func(p): return not p[4])
	for index in range(places.size()):
		var place: Array = places[index]
		var body := _rect(place[0], place[1], place[2], place[3]).grow(-2.0)
		if place[4]:
			draw_rect(body, fill_color)
		elif index == in_progress:
			draw_rect(
				Rect2(body.position, Vector2(body.size.x * progress, body.size.y)),
				fill_color.darkened(0.3)
			)
		draw_rect(body, Color.WHITE, false, 1.5)


func _rect(rank: int, column: int, depth: int, width: int) -> Rect2:
	return Rect2(Vector2(column * CELL, TOP + rank * CELL), Vector2(width * CELL, depth * CELL))

class_name FormationSkirmishHud
extends CanvasLayer
## Controls and readouts for the formation feel test (specs/22-formation-feel-test.md):
## time, the shared slot pool, each lane's formation (slots, width, composition, a live
## preview of the wave being built, send, auto departure), the kingdom, orders for the
## selected squad, and a log. Builds its widgets in code and only emits signals.

signal pause_toggled
signal speed_chosen(multiplier: float)
signal pause_on_full_toggled(enabled: bool)
signal kingdom_auto_toggled(enabled: bool)
signal order_chosen(order: int)
signal slots_changed(lane_key: String, delta: int)
signal width_changed(lane_key: String, delta: int)
signal preset_chosen(lane_key: String, preset: int)
signal send_wave_pressed(lane_key: String)
signal auto_departure_toggled(lane_key: String, enabled: bool)
signal spawn_kingdom_pressed(lane_key: String)

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const PANEL_WIDTH := 330.0
const LOG_LINES := 9
const BANNER_SECONDS := 3.0
const PRESETS := ["Grems", "Brute front + grems", "Brutes"]


## A tiny grid of the wave being built: the formation's usable cells and the units in it.
class WavePreview:
	extends Control
	const CELL := 9.0
	var width := 1
	var slots := 0
	var cells := []  # [[rank, column, depth, width], ...]

	func _draw() -> void:
		for index in range(slots):
			var at := Vector2(index % width, index / width) * CELL
			draw_rect(Rect2(at, Vector2(CELL - 1, CELL - 1)), Color(1, 1, 1, 0.15))
		for unit in cells:
			var at := Vector2(unit[1], unit[0]) * CELL
			var size := Vector2(unit[3], unit[2]) * CELL - Vector2.ONE
			draw_rect(Rect2(at, size), Color("#b3761d"))


var _status: Label
var _pool: Label
var _pause_button: Button
var _selected: Label
var _log: RichTextLabel
var _banner: Label
var _lanes := {}  # lane key -> {"label": Label, "bar": ProgressBar, "preview": WavePreview}
var _lines: PackedStringArray = []
var _banner_left := 0.0


func build(lane_keys: Array) -> void:
	var scroll := ScrollContainer.new()  # the panel is taller than small windows
	scroll.position = Vector2(10, 10)
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH + 24.0, 0)
	scroll.size = Vector2(
		PANEL_WIDTH + 24.0, maxf(get_viewport().get_visible_rect().size.y - 20.0, 200.0)
	)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var panel := PanelContainer.new()
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_child(box)
	_status = _label(box, "")
	var time_row := _row(box)
	_pause_button = _button(time_row, "Pause (Space)", func(): pause_toggled.emit())
	for multiplier in [1.0, 2.0, 4.0]:
		_button(time_row, "×%d" % multiplier, func(): speed_chosen.emit(multiplier))
	_toggle(
		box,
		"Pause when a wave is full (Send resumes)",
		true,
		func(on): pause_on_full_toggled.emit(on)
	)
	_pool = _label(box, "")
	for lane_key in lane_keys:
		_build_lane(box, lane_key)
	_build_kingdom_and_orders(box, lane_keys)
	_banner = Label.new()
	_banner.position = Vector2(PANEL_WIDTH + 40.0, 14)
	_banner.add_theme_font_size_override("font_size", 20)
	add_child(_banner)


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.text = ""


func set_status(text: String, paused: bool) -> void:
	_status.text = text
	_pause_button.text = "Resume (Space)" if paused else "Pause (Space)"


func set_pool(text: String) -> void:
	_pool.text = text


## text: the lane's summary; share: build progress; preview: [width, slots, cells].
func set_lane(lane_key: String, text: String, share: float, preview: Array) -> void:
	var lane: Dictionary = _lanes[lane_key]
	lane["label"].text = text
	lane["bar"].value = share
	lane["preview"].width = preview[0]
	lane["preview"].slots = preview[1]
	lane["preview"].cells = preview[2]
	lane["preview"].custom_minimum_size = Vector2(
		PANEL_WIDTH, ceilf(float(preview[1]) / maxf(preview[0], 1)) * WavePreview.CELL + 2
	)
	lane["preview"].queue_redraw()


func set_selected(text: String) -> void:
	_selected.text = text


func add_log(line: String) -> void:
	_lines.append(line)
	if _lines.size() > LOG_LINES:
		_lines = _lines.slice(_lines.size() - LOG_LINES)
	_log.text = "\n".join(_lines)


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS


func _build_lane(box: VBoxContainer, lane_key: String) -> void:
	var title := "Lane P → %s  (Send: %s)" % [lane_key, "S" if lane_key == "c" else "Shift+S"]
	_label(box, title)
	var row := _row(box)
	_button(row, "slots −", func(): slots_changed.emit(lane_key, -1))
	_button(row, "+", func(): slots_changed.emit(lane_key, 1))
	_button(row, "width −", func(): width_changed.emit(lane_key, -1))
	_button(row, "+", func(): width_changed.emit(lane_key, 1))
	var presets := OptionButton.new()
	presets.focus_mode = Control.FOCUS_NONE
	for name in PRESETS:
		presets.add_item(name)
	presets.item_selected.connect(func(index): preset_chosen.emit(lane_key, index))
	box.add_child(presets)
	var label := _label(box, "")
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	box.add_child(bar)
	var preview := WavePreview.new()
	box.add_child(preview)
	var send_row := _row(box)
	_button(send_row, "Send wave", func(): send_wave_pressed.emit(lane_key))
	_toggle(send_row, "Auto depart", false, func(on): auto_departure_toggled.emit(lane_key, on))
	_lanes[lane_key] = {"label": label, "bar": bar, "preview": preview}


func _build_kingdom_and_orders(box: VBoxContainer, lane_keys: Array) -> void:
	var kingdom_row := _row(box)
	for lane_key in lane_keys:
		_button(
			kingdom_row, "Militia → %s" % lane_key, func(): spawn_kingdom_pressed.emit(lane_key)
		)
	_toggle(kingdom_row, "Auto", false, func(on): kingdom_auto_toggled.emit(on))
	_selected = _label(box, "Click a squad (or Tab) to select it")
	var order_row := _row(box)
	var orders := [
		["Advance (A)", SkirmishUnit.Order.ADVANCE],
		["Hold (H)", SkirmishUnit.Order.HOLD],
		["Retreat (R)", SkirmishUnit.Order.RETREAT]
	]
	for pair in orders:
		_button(order_row, pair[0], func(): order_chosen.emit(pair[1]))
	_log = RichTextLabel.new()
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	box.add_child(_log)


func _label(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	parent.add_child(label)
	return label


func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _button(parent: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _toggle(parent: Container, text: String, on: bool, action: Callable) -> void:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(action)
	parent.add_child(check)

class_name SkirmishHud
extends CanvasLayer
## The skirmish feel test's controls and readouts (specs/21-realtime-skirmish-feel-test.md).
## Builds its widgets in code and only emits signals - SkirmishScene decides what they do.

signal pause_toggled
signal speed_chosen(multiplier: float)
signal send_wave_pressed
signal spawn_player_pressed
signal spawn_kingdom_pressed
signal auto_departure_toggled(enabled: bool)
signal pause_on_full_toggled(enabled: bool)
signal kingdom_auto_toggled(enabled: bool)
signal order_chosen(order: int)

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const LOG_LINES := 12
const PANEL_WIDTH := 300.0
const BANNER_SECONDS := 3.0

var _status: Label
var _wave: Label
var _wave_bar: ProgressBar
var _selected: Label
var _log: RichTextLabel
var _banner: Label
var _pause_button: Button
var _lines: PackedStringArray = []
var _banner_left := 0.0


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_child(box)
	_status = _label(box, "")
	var time_row := _row(box)
	_pause_button = _button(time_row, "Pause (Space)", func(): pause_toggled.emit())
	for multiplier in [1.0, 2.0, 4.0]:
		_button(time_row, "×%d" % multiplier, func(): speed_chosen.emit(multiplier))
	_build_lane_controls(box)
	_build_orders_and_log(box)
	_banner = Label.new()
	_banner.position = Vector2(340, 16)
	_banner.add_theme_font_size_override("font_size", 22)
	add_child(_banner)


func _build_lane_controls(box: VBoxContainer) -> void:
	_label(box, "Your lane (P → c)")
	_wave = _label(box, "")
	_wave_bar = ProgressBar.new()
	_wave_bar.max_value = 1.0
	_wave_bar.show_percentage = false
	box.add_child(_wave_bar)
	var wave_row := _row(box)
	_button(wave_row, "Send wave (S)", func(): send_wave_pressed.emit())
	_button(wave_row, "Spawn 1 now", func(): spawn_player_pressed.emit())
	_toggle(box, "Depart automatically when full", false, func(on): auto_departure_toggled.emit(on))
	_toggle(
		box,
		"Pause when a wave is full (off = notify)",
		true,
		func(on): pause_on_full_toggled.emit(on)
	)
	_label(box, "The kingdom")
	var kingdom_row := _row(box)
	_button(kingdom_row, "Spawn militia", func(): spawn_kingdom_pressed.emit())
	_toggle(kingdom_row, "Auto every 10 s", false, func(on): kingdom_auto_toggled.emit(on))


func _build_orders_and_log(box: VBoxContainer) -> void:
	_selected = _label(box, "Click a unit (or Tab) to select it")
	var order_row := _row(box)
	for pair in [
		["Advance (A)", SkirmishUnit.Order.ADVANCE],
		["Hold (H)", SkirmishUnit.Order.HOLD],
		["Retreat (R)", SkirmishUnit.Order.RETREAT]
	]:
		_button(order_row, pair[0], func(): order_chosen.emit(pair[1]))
	_log = RichTextLabel.new()
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	box.add_child(_log)


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.text = ""


func set_status(text: String) -> void:
	_status.text = text


func set_paused(paused: bool) -> void:
	_pause_button.text = "Resume (Space)" if paused else "Pause (Space)"


func set_wave(text: String, share: float) -> void:
	_wave.text = text
	_wave_bar.value = share


func set_selected(text: String) -> void:
	_selected.text = text


func add_log(line: String) -> void:
	_lines.append(line)
	if _lines.size() > LOG_LINES:
		_lines = _lines.slice(_lines.size() - LOG_LINES)
	_log.text = "\n".join(_lines)


## A notification that fades after a few seconds (the "notify" half of Decision 39).
func show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS


func _label(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # the panel keeps its width
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
	button.focus_mode = Control.FOCUS_NONE  # keep Space/A/H/R for the game, not the button
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

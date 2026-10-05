class_name FormationFieldHud
extends CanvasLayer
## The 2D feel test's controls and status (spec 27): two rows of buttons - send each route's
## wave or let it go when full, or retreat it; send A down the slanted route C, send A and
## B together, have B wait for A, give the line a captain, have it pursue, reset with a
## seed, pause - and a status row under it: the tick (and seconds of battle), waves built
## (leaders counted apart), the line, the reserve and the battle seed. Reset starts a
## fresh field, with the seed typed in or a random one, keeping the ticked options. Below,
## the session's action log (FormationFieldActions) with Copy and Replay: paste a log in
## and Replay restarts on its seed and plays its actions at their ticks, live (pause still
## works). Engine glue.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationFieldActions = preload("res://sim/skirmish/formation/formation_field_actions.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")

const WAYS := ["north", "east", "south", "west"]

var _scene: Node
var _autos := {}  # route key -> CheckBox
var _wait: CheckBox
var _via_c: CheckBox
var _pursues: CheckBox
var _captain: CheckBox
var _seed: LineEdit
var _status: Label
var _log_view: TextEdit


## Builds the controls for `scene` (FormationFieldScene).
func build(scene: Node) -> void:
	_scene = scene
	var rows := VBoxContainer.new()
	rows.position = Vector2(12, 8)
	add_child(rows)
	var bar := HBoxContainer.new()
	rows.add_child(bar)
	for key in ["A", "B"]:
		_button(bar, "Send %s" % key, func(): scene.act("send " + key))
		_autos[key] = _check(bar, "Auto %s" % key, func(on): scene.act(_toggle("auto " + key, on)))
		_button(bar, "Retreat %s" % key, func(): scene.act("retreat " + key))
	_button(bar, "Send A+B", func(): scene.act("send A+B"))
	var options := HBoxContainer.new()  # a second row, so the controls fit the window
	rows.add_child(options)
	_via_c = _check(options, "A goes via C", func(on): scene.act(_toggle("via_c", on)))
	_wait = _check(options, "B waits for A", func(on): scene.act(_toggle("wait", on)))
	_captain = _check(options, "Line has a captain", func(_on): reset())
	_pursues = _check(options, "Line pursues", func(on): scene.act(_toggle("pursues", on)))
	_seed = LineEdit.new()
	_seed.placeholder_text = "seed (random)"
	_seed.custom_minimum_size = Vector2(110, 0)
	options.add_child(_seed)
	_button(options, "Reset", reset)
	_button(options, "Pause (Space)", scene.toggle_pause)
	_status = Label.new()
	rows.add_child(_status)
	var logged := HBoxContainer.new()
	rows.add_child(logged)
	_log_view = TextEdit.new()
	_log_view.custom_minimum_size = Vector2(420, 72)
	logged.add_child(_log_view)
	var log_buttons := VBoxContainer.new()
	logged.add_child(log_buttons)
	_button(log_buttons, "Copy log", func(): DisplayServer.clipboard_set(scene.action_log()))
	_button(log_buttons, "Replay log", replay)


## Restarts on the pasted log's seed and replays its actions; the options are the log's.
func replay() -> void:
	var read := FormationFieldActions.parse(_log_view.text)
	if read.is_empty():
		return
	_log_view.release_focus()
	_seed.text = str(read["seed"])
	_captain.set_pressed_no_signal(read["captained"])
	for box in [_wait, _via_c, _pursues] + _autos.values():
		box.set_pressed_no_signal(false)
	_scene.restart(read["captained"], read["seed"], read["actions"])


## A fresh field: the seed typed in, or a random one; the ticked options kept (and logged).
func reset() -> void:
	var text := _seed.text.strip_edges()
	var battle_seed := int(text) if text.is_valid_int() else randi() % 1000000
	_scene.restart(_captain.button_pressed, battle_seed)
	for key in _autos:
		if _autos[key].button_pressed:
			_scene.act(_toggle("auto " + key, true))
	for option in [[_wait, "wait"], [_via_c, "via_c"], [_pursues, "pursues"]]:
		if option[0].button_pressed:
			_scene.act(_toggle(option[1], true))


## An on/off action's words.
static func _toggle(action: String, on: bool) -> String:
	return "%s %s" % [action, "on" if on else "off"]


func show_status(field: FormationField, paused: bool, battle_seed: int) -> void:
	var built := []
	for key in field.waves:
		built.append(_built(field, key))
	var line := field.kingdom_line
	var state: String = SkirmishSquad.State.keys()[line.state].to_lower()
	if not line.stance.is_empty():
		state += ", faced " + WAYS[line.stance["facing"]]
	var halted := field.sim.squads().any(func(s): return s.blocked)
	_status.text = (
		"Tick %d (%.1fs)   Waves: %s   Line: %d (%s)   Reserve: %d   Seed: %d%s%s"
		% [
			field.sim.tick_number(),
			field.sim.tick_number() * FormationFieldActions.TICK_SECONDS,
			", ".join(built),
			line.living().size(),
			state,
			field.kingdom_reserve.living().size(),
			battle_seed,
			"   BLOCKED" if halted else "",
			"   (paused)" if paused else "",
		]
	)
	var log: String = _scene.action_log()
	if _log_view.text != log and not _log_view.has_focus():  # not while a log is pasted in
		_log_view.text = log
		_log_view.scroll_vertical = _log_view.get_line_count()


## "B 8/8 + leader 1/1": rank and file and leaders counted apart.
func _built(field: FormationField, key: String) -> String:
	var counts := [0, 0, 0, 0]  # rank and file built, places, leaders built, places
	for place in field.waves[key].preview():
		var leads: bool = place[5].leadership > 0
		counts[2 if leads else 0] += 1 if place[4] else 0
		counts[3 if leads else 1] += 1
	var text := "%s %d/%d" % [key, counts[0], counts[1]]
	if counts[3] > 0:
		text += " + leader %d/%d" % [counts[2], counts[3]]
	return text


func _button(bar: Container, text: String, pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	bar.add_child(button)


func _check(bar: Container, text: String, toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.toggled.connect(toggled)
	bar.add_child(box)
	return box

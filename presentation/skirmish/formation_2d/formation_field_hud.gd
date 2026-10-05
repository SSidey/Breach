class_name FormationFieldHud
extends CanvasLayer
## The 2D feel test's controls and status (spec 27): two rows of buttons - send each route's
## wave or let it go when full, or retreat it; send A down the slanted route C, send A and
## B together, have B wait for A, give the line a captain, have it pursue, reset with a
## seed, pause - and a status row under it: the tick (and seconds of battle), waves built
## (leaders counted apart), the line (how far it has pursued, of its leash), the reserve
## and the battle seed. Reset starts a fresh field, with the seed typed in or a random
## one, keeping the ticked options. Below, this run's action log (FormationFieldActions)
## to copy, and a box to paste a log into: Replay restarts on its seed and plays its
## actions at their ticks, live (pause still works), counting them off. Engine glue.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationFieldActions = preload("res://sim/skirmish/formation/formation_field_actions.gd")
const FormationPursuit = preload("res://sim/skirmish/formation/formation_pursuit.gd")
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
var _replay_view: TextEdit
var _replay_status: Label
var _replaying := 0  # how many actions the replay running holds (0: not a replay)


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
	var logs := HBoxContainer.new()
	rows.add_child(logs)
	_log_view = _log_box(logs, "This run's actions")
	_log_view.editable = false
	_button(logs, "Copy", func(): DisplayServer.clipboard_set(scene.action_log()))
	_replay_view = _log_box(logs, "Paste a log to replay")
	_button(logs, "Replay", replay)
	_replay_status = Label.new()
	logs.add_child(_replay_status)


## Restarts on the pasted log's seed and replays its actions; the options are the log's.
func replay() -> void:
	var read := FormationFieldActions.parse(_replay_view.text)
	if read.is_empty():
		_replay_status.text = 'Not a log: it starts\n"seed <n> captain <on|off>"'
		_replaying = 0
		return
	_seed.text = str(read["seed"])
	_captain.set_pressed_no_signal(read["captained"])
	for box in [_wait, _via_c, _pursues] + _autos.values():
		box.set_pressed_no_signal(false)
	_scene.restart(read["captained"], read["seed"], read["actions"])
	_replaying = read["actions"].size()


## A fresh field: the seed typed in, or a random one; the ticked options kept (and logged).
func reset() -> void:
	var text := _seed.text.strip_edges()
	var battle_seed := int(text) if text.is_valid_int() else randi() % 1000000
	_scene.restart(_captain.button_pressed, battle_seed)
	_replaying = 0
	_replay_status.text = ""
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
	if not line.pursuit.is_empty() and not line.pursuit["returning"]:
		var reached := FormationPursuit.reach(line)  # Decision 107's leash
		var leash := "unleashed" if is_inf(reached[1]) else "%d" % reached[1]
		state += ", pursuing %d/%s cells" % [reached[0], leash]
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
	if _log_view.text != log:
		_log_view.text = log
		_log_view.scroll_vertical = _log_view.get_line_count()
	if _replaying > 0:  # the replayed actions are logged again as they're played
		var played := mini(_log_view.get_line_count() - 1, _replaying)
		_replay_status.text = (
			"Replaying seed %d\n%d of %d actions played" % [battle_seed, played, _replaying]
		)


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


func _log_box(bar: Container, hint: String) -> TextEdit:
	var box := TextEdit.new()
	box.placeholder_text = hint
	box.custom_minimum_size = Vector2(260, 72)
	bar.add_child(box)
	return box


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

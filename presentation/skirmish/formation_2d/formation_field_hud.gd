class_name FormationFieldHud
extends CanvasLayer
## The 2D feel test's controls and status (spec 27): a row of buttons - send each route's
## wave or let it go when full, or retreat it; send A down the slanted route C, send A and
## B together, have B wait for A, give the line a captain, have it pursue, reset with a
## seed, pause - and a status row
## under it: waves built (leaders counted apart), the line, the reserve and the battle
## seed. Reset starts a fresh field, with the seed typed in or a random one, keeping the
## ticked options. Engine glue.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
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


## Builds the controls for `scene` (FormationFieldScene).
func build(scene: Node) -> void:
	_scene = scene
	var rows := VBoxContainer.new()
	rows.position = Vector2(12, 8)
	add_child(rows)
	var bar := HBoxContainer.new()
	rows.add_child(bar)
	for key in ["A", "B"]:
		_button(bar, "Send %s" % key, func(): scene.field().send(key))
		_autos[key] = _check(bar, "Auto %s" % key, func(on): scene.field().set_auto(key, on))
		_button(bar, "Retreat %s" % key, func(): scene.retreat(key))
	_via_c = _check(bar, "A goes via C", func(on): _route_a(on))
	_button(bar, "Send A+B", func(): scene.field().send_together(["A", "B"]))
	_wait = _check(bar, "B waits for A", func(on): scene.field().set_wait(on))
	_captain = _check(bar, "Line has a captain", func(_on): reset())
	_pursues = _check(bar, "Line pursues", func(on): _line_pursues(on))
	_seed = LineEdit.new()
	_seed.placeholder_text = "seed (random)"
	_seed.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_seed)
	_button(bar, "Reset", reset)
	_button(bar, "Pause (Space)", scene.toggle_pause)
	_status = Label.new()
	rows.add_child(_status)


## A fresh field: the seed typed in, or a random one; the ticked options kept.
func reset() -> void:
	var text := _seed.text.strip_edges()
	var battle_seed := int(text) if text.is_valid_int() else randi() % 1000000
	_scene.restart(_captain.button_pressed, battle_seed)
	for key in _autos:
		_scene.field().set_auto(key, _autos[key].button_pressed)
	_scene.field().set_wait(_wait.button_pressed)
	_route_a(_via_c.button_pressed)
	_line_pursues(_pursues.button_pressed)


## The kingdom's line and reserve follow a retreating wave (Decision 95), or hold.
func _line_pursues(on: bool) -> void:
	_scene.field().kingdom_line.pursues = on
	_scene.field().kingdom_reserve.pursues = on


## Sends A's waves down route C (the slanted path) or back down route A.
func _route_a(via_c: bool) -> void:
	var field: FormationField = _scene.field()
	field.waves["A"].route = field.routes["C" if via_c else "A"]


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
		"Waves: %s   Line: %d (%s)   Reserve: %d   Seed: %d%s%s"
		% [
			", ".join(built),
			line.living().size(),
			state,
			field.kingdom_reserve.living().size(),
			battle_seed,
			"   BLOCKED" if halted else "",
			"   (paused)" if paused else "",
		]
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

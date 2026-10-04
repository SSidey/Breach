class_name FormationFieldScene
extends Node2D
## The 2D formation feel test (Decision 86, spec 27 rounds 1 and 2): a top-down view of the
## FormationField - the kingdom's line across the middle, the player's routes A and B with
## their corridors, and every unit drawn in its cells, turned to its squad's facing and
## eased between ticks. Send a route's wave, let it depart when full, send both timed to
## arrive together, or have B wait in the wood (its detection range ringed) until it sees
## A engage (Decision 87). Engine glue - the rules live in sim/skirmish/formation/.
##
##   godot --path . res://presentation/skirmish/formation_2d/formation_field.tscn

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")
const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")

const GREM := preload("res://content/units/grem.tres")
const MILITIA := preload("res://content/units/kingdom_militia.tres")

const CELL_PX := 8.0
const ORIGIN := Vector2(16, 56)
const BUILDERS := 4
const FLASH_SECONDS := 0.3
const COLOURS := {
	"grass": Color(0.33, 0.45, 0.25),
	"wood": Color(0.16, 0.3, 0.14),
	"ford": Color(0.25, 0.45, 0.7),
	"hill": Color(0.5, 0.45, 0.3),
	"A": Color(0.95, 0.85, 0.3),
	"B": Color(0.95, 0.55, 0.2),
	"player": Color(0.6, 0.3, 0.75),
	"the_kingdom": Color(0.3, 0.5, 0.9),
	"flash": Color(1, 0.2, 0.2),
	"staging": Color(1, 1, 1, 0.8),
	"sight": Color(1, 1, 1, 0.25),
}

var _clock := SkirmishClock.new()
var _field: FormationField
var _previous := {}  # unit id -> position (cells) at the previous tick
var _current := {}  # unit id -> position (cells) at the latest tick
var _flashes := {}  # unit id -> seconds left
var _status: Label


func field() -> FormationField:
	return _field


func clock() -> SkirmishClock:
	return _clock


## Runs `count` ticks at once (the frame loop runs whatever the clock says is due).
func run_ticks(count: int) -> void:
	for _i in range(count):
		for event in _field.step():
			if event["type"] == "hit" and event["flank"]:
				_flashes[event["target"]] = FLASH_SECONDS
		_snapshot()


func _ready() -> void:
	_field = FormationField.new(_clock.tick_seconds, GREM, BUILDERS, MILITIA)
	_snapshot()
	_build_hud()
	var camera := Camera2D.new()
	camera.position = ORIGIN + Vector2(FormationField.SIZE) * CELL_PX * 0.5 - Vector2(0, 20)
	add_child(camera)


func _process(delta: float) -> void:
	var due := _clock.advance(delta)
	run_ticks(due)
	for unit_id in _flashes.keys():
		_flashes[unit_id] -= delta
		if _flashes[unit_id] <= 0.0:
			_flashes.erase(unit_id)
	_status.text = _describe()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_toggle_pause()


func _draw() -> void:
	var size := Vector2(FormationField.SIZE) * CELL_PX
	draw_rect(Rect2(ORIGIN, size), COLOURS["grass"])
	for scenery in [["wood", FormationField.WOOD], ["hill", FormationField.HILL]]:
		draw_rect(_cells(scenery[1]), COLOURS[scenery[0]])
	draw_rect(_cells(FormationField.FORD), COLOURS["ford"])
	for key in _field.routes:
		_draw_route(key)
	var fraction := 1.0 if _clock.is_paused() else _clock.fraction()
	_draw_staging()
	for squad in _field.sim.squads():
		for unit in squad.living():
			_draw_unit(squad, unit, fraction)


func _draw_route(key: String) -> void:
	var points: PackedVector2Array = FormationField.route_points()[key]
	var drawn := PackedVector2Array()
	for point in points:
		drawn.append(ORIGIN + point * CELL_PX)
	var corridor: Color = COLOURS[key]
	corridor.a = 0.12
	draw_polyline(drawn, corridor, _field.routes[key].corridor_half_width * 2.0 * CELL_PX)
	draw_polyline(drawn, COLOURS[key], 2.0)


func _draw_unit(squad, unit, fraction: float) -> void:
	var before: Vector2 = _previous.get(unit.id, unit.position)
	var after: Vector2 = _current.get(unit.id, unit.position)
	var centre := ORIGIN + before.lerp(after, fraction) * CELL_PX
	var across := absf(SquadFrame.right(squad.facing).x) > 0.5
	var cells := (
		Vector2(unit.footprint_width, unit.footprint_depth)
		if across
		else Vector2(unit.footprint_depth, unit.footprint_width)
	)
	var size := cells * CELL_PX - Vector2.ONE
	var colour: Color = COLOURS["flash"] if _flashes.has(unit.id) else COLOURS[squad.faction_id]
	draw_rect(Rect2(centre - size * 0.5, size), colour)
	if unit.rank == 0:
		var front := centre + SquadFrame.forward(squad.facing) * size * 0.5
		draw_circle(front, 1.5, Color.WHITE)


## The staging point in the wood, and a ring of detection round any wave waiting there.
func _draw_staging() -> void:
	if _field.waves["B"].staging.is_empty():
		return
	var point := ORIGIN + FormationField.STAGING * CELL_PX
	draw_colored_polygon(
		PackedVector2Array(
			[
				point + Vector2(0, -5),
				point + Vector2(5, 0),
				point + Vector2(0, 5),
				point + Vector2(-5, 0)
			]
		),
		COLOURS["staging"]
	)
	for squad in _field.sim.squads():
		if squad.staging.is_empty() or squad.living().is_empty():
			continue
		var reach: float = squad.living().map(func(u): return u.detection).max()
		var centre := ORIGIN + squad.position * CELL_PX
		draw_arc(centre, reach * CELL_PX, 0.0, TAU, 64, COLOURS["sight"], 1.5)


func _cells(area: Rect2) -> Rect2:
	return Rect2(ORIGIN + area.position * CELL_PX, area.size * CELL_PX)


func _snapshot() -> void:
	_previous = _current
	_current = {}
	for squad in _field.sim.squads():
		for unit in squad.units:
			_current[unit.id] = unit.position


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 8)
	layer.add_child(bar)
	for key in ["A", "B"]:
		var send := Button.new()
		send.text = "Send %s" % key
		send.pressed.connect(_on_send.bind(key))
		bar.add_child(send)
		var auto := CheckBox.new()
		auto.text = "Auto %s" % key
		auto.toggled.connect(func(on): _field.set_auto(key, on))
		bar.add_child(auto)
	var together := Button.new()
	together.text = "Send together"
	together.pressed.connect(func(): _field.send_together(["A", "B"]))
	bar.add_child(together)
	var wait := CheckBox.new()
	wait.text = "B waits for A"
	wait.toggled.connect(func(on): _field.set_wait(on))
	bar.add_child(wait)
	var pause := Button.new()
	pause.text = "Pause (Space)"
	pause.pressed.connect(_toggle_pause)
	bar.add_child(pause)
	_status = Label.new()
	bar.add_child(_status)


func _on_send(key: String) -> void:
	_field.send(key)


func _toggle_pause() -> void:
	if _clock.is_paused():
		_clock.resume()
	else:
		_clock.pause()


func _describe() -> String:
	var built := []
	for key in _field.waves:
		built.append("%s %d/%d" % [key, _field.waves[key].built(), FormationField.WAVE_WIDTH])
	var line := _field.kingdom_line
	return (
		"  Waves: %s   Kingdom line: %d left%s"
		% [", ".join(built), line.living().size(), "   (paused)" if _clock.is_paused() else ""]
	)

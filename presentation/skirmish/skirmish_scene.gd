class_name SkirmishScene
extends Node2D
## The real-time skirmish feel test (specs/21-realtime-skirmish-feel-test.md,
## Decisions 38-39): the P-c map (drawn by the map viewer's MapView as a debug board),
## a live SkirmishSimulation stepped by a fixed-tick SkirmishClock, the player's lane
## building waves, and live orders. Engine glue: the rules live in sim/skirmish/.
##
##   godot --path . res://presentation/skirmish/skirmish.tscn    (or open it, F6)

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")
const SkirmishSimulation = preload("res://sim/skirmish/skirmish_simulation.gd")
const SkirmishProduction = preload("res://sim/skirmish/skirmish_production.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishRoute = preload("res://presentation/skirmish/skirmish_route.gd")
const SkirmishUnitLayer = preload("res://presentation/skirmish/skirmish_unit_layer.gd")
const SkirmishHud = preload("res://presentation/skirmish/skirmish_hud.gd")
const MapView = preload("res://presentation/map_view.gd")

const MAP := preload("res://content/maps/skirmish_p_c.tres")
const PLAYER_UNIT := preload("res://content/units/grem.tres")
const KINGDOM_UNIT := preload("res://content/units/kingdom_militia.tres")
const KINGDOM_AUTO_TICKS := 40  # 10 s at 0.25 s ticks

## Decision 39: what a full wave does - pause the game (true) or only notify (false).
var pause_on_wave_full := true

var _clock := SkirmishClock.new()
var _sim: SkirmishSimulation
var _lane: SkirmishProduction
var _kingdom: SkirmishProduction
var _kingdom_auto := false
var _hud: SkirmishHud


func map_view() -> MapView:
	return $MapView


func simulation() -> SkirmishSimulation:
	return _sim


func clock() -> SkirmishClock:
	return _clock


func _ready() -> void:
	map_view().map = MAP
	var link = MAP.layout.routes[0]
	var points: PackedVector2Array = map_view().model.layout_view.route_points(
		link.node_a_id, link.node_b_id
	)
	_sim = SkirmishSimulation.new(
		SkirmishRoute.length_cells(points, MAP.layout.cell_size), _clock.tick_seconds
	)
	_lane = SkirmishProduction.new(PLAYER_UNIT, "player", true)
	_kingdom = SkirmishProduction.new(KINGDOM_UNIT, "the_kingdom", false)
	_kingdom.wave_size = 1
	_kingdom.build_ticks = KINGDOM_AUTO_TICKS
	_kingdom.departure = SkirmishProduction.Departure.AUTO_WHEN_FULL
	var layer: SkirmishUnitLayer = $Units
	layer.simulation = _sim
	layer.route_points = points
	layer.cell_size = MAP.layout.cell_size
	_hud = SkirmishHud.new()
	add_child(_hud)
	_connect_hud()
	_frame_camera()
	_refresh_hud()


func _process(delta: float) -> void:
	var due := _clock.advance(delta)
	for i in range(due):
		var events := _lane.step(_sim)
		if _kingdom_auto:
			events.append_array(_kingdom.step(_sim))
		events.append_array(_sim.step())
		$Units.snapshot()
		handle_events(events)
		if _clock.is_paused():
			break  # a wave-full pause stops the remaining catch-up ticks
	$Units.fraction = 1.0 if _clock.is_paused() else _clock.fraction()
	_refresh_hud()


## Reacts to a tick's events: the log, the wave-full option (Decision 39), and banners.
func handle_events(events: Array) -> void:
	for event in events:
		match event["type"]:
			"wave_full":
				if event["faction"] == "player":
					_on_wave_full()
			"engaged", "died", "arrived", "returned", "departed":
				_hud_log(event)


func _on_wave_full() -> void:
	if pause_on_wave_full:
		_clock.pause()
		_hud_banner("Lane P → c: wave ready - paused (Space to resume)")
	else:
		_hud_banner("Lane P → c: wave ready")
	_hud_log({"type": "wave_full", "tick": _sim.tick_number() if _sim else 0, "faction": "player"})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_A:
				_order_selected(SkirmishUnit.Order.ADVANCE)
			KEY_H:
				_order_selected(SkirmishUnit.Order.HOLD)
			KEY_R:
				_order_selected(SkirmishUnit.Order.RETREAT)
			KEY_TAB:
				_cycle_selection()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		$Units.selected_id = $Units.unit_at($Units.get_local_mouse_position())


func _connect_hud() -> void:
	_hud.pause_toggled.connect(_toggle_pause)
	_hud.speed_chosen.connect(func(multiplier): _clock.speed_multiplier = multiplier)
	_hud.send_wave_pressed.connect(func(): _lane.send(_sim))
	_hud.spawn_player_pressed.connect(func(): _sim.spawn(PLAYER_UNIT, "player", true))
	_hud.spawn_kingdom_pressed.connect(func(): _sim.spawn(KINGDOM_UNIT, "the_kingdom", false))
	_hud.auto_departure_toggled.connect(
		func(on):
			_lane.departure = (
				SkirmishProduction.Departure.AUTO_WHEN_FULL
				if on
				else SkirmishProduction.Departure.MANUAL
			)
	)
	_hud.pause_on_full_toggled.connect(func(on): pause_on_wave_full = on)
	_hud.kingdom_auto_toggled.connect(func(on): _kingdom_auto = on)
	_hud.order_chosen.connect(_order_selected)


func _toggle_pause() -> void:
	if _clock.is_paused():
		_clock.resume()
	else:
		_clock.pause()


func _order_selected(new_order: int) -> void:
	var selected: int = $Units.selected_id
	if selected != 0 and _sim.unit(selected) != null and _sim.unit(selected).is_alive():
		_sim.order(selected, new_order)


func _cycle_selection() -> void:
	var mine := _sim.units().filter(func(u): return u.is_alive() and u.faction_id == "player")
	if mine.is_empty():
		$Units.selected_id = 0
		return
	var ids: Array = mine.map(func(u): return u.id)
	var at := ids.find($Units.selected_id)
	$Units.selected_id = ids[(at + 1) % ids.size()]


func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.set_status(_status_text())
	_hud.set_paused(_clock.is_paused())
	var status := "ready - send it" if _lane.is_full() else "building"
	_hud.set_wave(
		"wave %d/%d %s" % [_lane.built, _lane.wave_size, status],
		1.0 if _lane.is_full() else _lane.progress()
	)
	_hud.set_selected(_selected_text())


func _status_text() -> String:
	var units := _sim.units()
	var alive := func(faction):
		return units.filter(func(u): return u.is_alive() and u.faction_id == faction).size()
	var arrived := units.filter(func(u): return u.state == SkirmishUnit.State.ARRIVED).size()
	return (
		"tick %d · %.1f s · ×%d%s\nplayer %d · kingdom %d · arrived %d"
		% [
			_sim.tick_number(),
			_sim.tick_number() * _clock.tick_seconds,
			int(_clock.speed_multiplier),
			" · PAUSED" if _clock.is_paused() else "",
			alive.call("player"),
			alive.call("the_kingdom"),
			arrived
		]
	)


func _selected_text() -> String:
	var selected := _sim.unit($Units.selected_id)
	if selected == null or not selected.is_alive():
		return "Click a unit (or Tab) to select it"
	return (
		"Selected #%d (%s) hp %d/%d · %s · %s"
		% [
			selected.id,
			selected.faction_id,
			selected.hp,
			selected.max_hp,
			SkirmishUnit.Order.keys()[selected.order],
			SkirmishUnit.State.keys()[selected.state]
		]
	)


func _hud_log(event: Dictionary) -> void:
	if _hud == null:
		return
	var who: String = " #%d" % event["unit"] if event.has("unit") else ""
	var detail := ""
	if event.has("with"):
		detail = " with #%d" % event["with"]
	elif event.has("units"):
		detail = " (%d units)" % event["units"]
	_hud.add_log(
		(
			"t%d %s%s %s%s"
			% [event.get("tick", 0), event.get("faction", ""), who, event["type"], detail]
		)
	)


func _hud_banner(text: String) -> void:
	if _hud != null:
		_hud.show_banner(text)


func _frame_camera() -> void:
	var bounds: Rect2 = map_view().model.bounds
	var viewport_size := get_viewport_rect().size
	var usable := Vector2(maxf(viewport_size.x - 330.0, 1.0), viewport_size.y)
	var fit := minf(usable.x / bounds.size.x, usable.y / bounds.size.y) * 0.9
	var camera: Camera2D = $Camera
	camera.zoom = Vector2(fit, fit)
	camera.position = bounds.get_center() - Vector2(165.0, 0.0) / fit

class_name FormationSkirmishScene
extends Node2D
## The formation feel test (specs/22-formation-feel-test.md, Decisions 39-43): two lanes
## from P (a FormationLane each), stepped by one SkirmishClock; a shared slot pool that
## each lane draws on as it paints (erasing frees slots for any lane); each lane's wave
## applied at once (fold + bank); the player's saved presets; kingdom militia lines;
## wave-level orders. Engine glue - the rules live in sim/skirmish/formation/.
##
##   godot --path . res://presentation/skirmish/formation/formation_skirmish.tscn

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationLane = preload("res://sim/skirmish/formation/formation_lane.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const WavePresetStore = preload("res://presentation/skirmish/formation/wave_preset_store.gd")
const SkirmishRoute = preload("res://presentation/skirmish/skirmish_route.gd")
const SkirmishCamera = preload("res://presentation/skirmish/skirmish_camera.gd")
const FormationSkirmishHud = preload(
	"res://presentation/skirmish/formation/formation_skirmish_hud.gd"
)
const MapView = preload("res://presentation/map_view.gd")
const FormationSkirmishReadout = preload(
	"res://presentation/skirmish/formation/formation_skirmish_readout.gd"
)

const MAP := preload("res://content/maps/skirmish_two_lanes.tres")
const GREM := preload("res://content/units/grem.tres")
const BRUTE := preload("res://content/units/grem_brute.tres")
const MILITIA := preload("res://content/units/kingdom_militia.tres")

const POOL_TOTAL := 8
## Each lane's maximum frontline width (feel-test config; maps author this later).
const LANE_WIDTHS := {"c": 5, "k": 4}
const START_SLOTS := {"c": 5, "k": 3}
const KINGDOM_LINE := 3
const KINGDOM_UNIT_SECONDS := 5.0  # a 3-wide militia line every 15 s when auto is on
## Brushes in HUD order (hotkeys 1, 2, E); null erases.
const BRUSHES := [GREM, BRUTE, null]

## Decision 39: a full wave pauses the game (true) or only notifies (false).
var pause_on_wave_full := true
## Where the player's presets are kept; empty keeps them in memory only.
var presets_path := "user://formation_presets.json"

var _clock := SkirmishClock.new()
var _pool: SkirmishSlotPool
var _lanes := {}  # lane key -> FormationLane
var _kingdom_auto := false
var _paused_for_wave := false
var _hud: FormationSkirmishHud
var _brush := 0
var _presets := []  # WavePresets dictionaries, the player's own


func lane_keys() -> Array:
	return _lanes.keys()


func simulation(lane_key: String) -> FormationSimulation:
	return _lanes[lane_key].sim


func pool() -> SkirmishSlotPool:
	return _pool


func clock() -> SkirmishClock:
	return _clock


func _ready() -> void:
	var view: MapView = $MapView
	view.map = MAP
	var caps := {}
	for key in LANE_WIDTHS:
		caps[key] = LANE_WIDTHS[key] * WaveTemplate.MAX_RANKS
	_pool = SkirmishSlotPool.new(POOL_TOTAL, caps)
	for route in MAP.layout.routes:
		_add_lane(
			route.node_b_id, view.model.layout_view.route_points(route.node_a_id, route.node_b_id)
		)
	for key in START_SLOTS:
		_pool.assign(key, START_SLOTS[key])
		_lanes[key].apply(WavePresets.line(GREM, START_SLOTS[key], LANE_WIDTHS[key]))
	_presets = WavePresetStore.load_presets(presets_path)
	_hud = FormationSkirmishHud.new()
	add_child(_hud)
	_hud.build(lane_keys())
	_hud.set_tools(_brush, WavePresetStore.names(_presets))
	_connect_hud()
	var panel := FormationSkirmishHud.PANEL_WIDTH + 30.0
	SkirmishCamera.frame($Camera, $MapView.model.bounds, get_viewport_rect().size, panel)
	_refresh_hud()


func _add_lane(lane_key: String, points: PackedVector2Array) -> void:
	var length := SkirmishRoute.length_cells(points, MAP.layout.cell_size)
	var lane := FormationLane.new(
		lane_key,
		LANE_WIDTHS[lane_key],
		length,
		_clock.tick_seconds,
		MILITIA,
		KINGDOM_LINE,
		KINGDOM_UNIT_SECONDS
	)
	lane.brush = GREM
	_lanes[lane_key] = lane
	$Squads.cell_size = MAP.layout.cell_size
	$Squads.add_lane(lane_key, lane.sim, points)


func _process(delta: float) -> void:
	var due := _clock.advance(delta)
	for i in range(due):
		for key in _lanes:
			handle_events(key, _lanes[key].step(_kingdom_auto))
		$Squads.snapshot()
		if _clock.is_paused():
			break
	$Squads.fraction = 1.0 if _clock.is_paused() else _clock.fraction()
	_refresh_hud()


## A tick's events for one lane: wave-full (Decision 39), flank flashes and the log.
func handle_events(lane_key: String, events: Array) -> void:
	for event in events:
		match event["type"]:
			"wave_full":
				if event["faction"] == "player":
					_on_wave_full(lane_key)
			"hit":
				if event["flank"]:
					$Squads.flash(lane_key, event["target"])
					_log(lane_key, event, "flank hit on #%d (%d)" % [event["target"], event["dmg"]])
			"engaged", "destroyed", "stepped_up", "arrived", "departed", "returned":
				_log(lane_key, event, event["type"].replace("_", " "))


## Sends the lane's wave; after a wave-full pause it also resumes (spec 21, playtest 1).
func send_wave(lane_key: String) -> void:
	_lanes[lane_key].production.send(_lanes[lane_key].sim)
	if _paused_for_wave:
		_paused_for_wave = false
		_clock.resume()


## Paints (or erases) one cell of a lane's wave. The lane may grow into any free slot of
## the pool, and the pool then records what it uses - so erasing frees slots for any lane
## at once (Decision 43).
func _paint_cell(lane_key: String, cell: Vector2i, erase: bool = false) -> void:
	_reshaped(lane_key, _lanes[lane_key].paint(cell, _allowance(lane_key), erase))


func _save_preset(lane_key: String) -> void:
	var preset_name := "Preset %d" % (_presets.size() + 1)
	_presets.append(WavePresets.to_dict(_lanes[lane_key].template, preset_name, GREM))
	WavePresetStore.save_presets(presets_path, _presets)
	if _hud != null:
		_hud.set_tools(_brush, WavePresetStore.names(_presets))
	_log(lane_key, {"faction": "player"}, "saved the shape as %s" % preset_name)


## Applies a saved preset, fitted to the lane's width and the slots it can reach.
func _apply_preset(lane_key: String, index: int) -> void:
	var width: int = LANE_WIDTHS[lane_key]
	var fitted := WavePresets.from_dict(_presets[index], GREM, BRUTE, width, _allowance(lane_key))
	_reshaped(lane_key, _lanes[lane_key].apply(fitted))


## The cells a lane may paint: its own plus whatever the pool has free.
func _allowance(lane_key: String) -> int:
	return _pool.assigned(lane_key) + _pool.free_slots()


## After a template change: the pool records the lane's cells and the log notes any bank.
func _reshaped(lane_key: String, banked: int) -> void:
	_pool.assign(lane_key, _lanes[lane_key].cells_used())
	if banked > 0:
		var at := {"tick": simulation(lane_key).tick_number(), "faction": "player"}
		_log(lane_key, at, "reshaped: %d banked in the reserve" % banked)


func _on_wave_full(lane_key: String) -> void:
	if pause_on_wave_full and not _clock.is_paused():
		_clock.pause()
		_paused_for_wave = true
		_banner("Lane %s: wave ready - paused. Send it to go" % lane_key)
	else:
		_banner("Lane %s: wave ready" % lane_key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_S:
				send_wave("k" if event.shift_pressed else "c")
			KEY_A:
				_order(SkirmishUnit.Order.ADVANCE)
			KEY_H:
				_order(SkirmishUnit.Order.HOLD)
			KEY_R:
				_order(SkirmishUnit.Order.RETREAT)
			KEY_TAB:
				_cycle_selection()
			KEY_1, KEY_2, KEY_E:
				_choose_brush({KEY_1: 0, KEY_2: 1, KEY_E: 2}[event.keycode])
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		$Squads.selected = $Squads.squad_at($Squads.get_local_mouse_position())


func _connect_hud() -> void:
	_hud.pause_toggled.connect(_toggle_pause)
	_hud.speed_chosen.connect(func(multiplier): _clock.speed_multiplier = multiplier)
	_hud.pause_on_full_toggled.connect(func(on): pause_on_wave_full = on)
	_hud.kingdom_auto_toggled.connect(func(on): _kingdom_auto = on)
	_hud.order_chosen.connect(_order)
	_hud.brush_chosen.connect(_choose_brush)
	_hud.preset_saved.connect(_save_preset)
	_hud.preset_applied.connect(_apply_preset)
	_hud.cell_painted.connect(func(key, cell): _paint_cell(key, cell))
	_hud.cell_erased.connect(func(key, cell): _paint_cell(key, cell, true))
	_hud.send_wave_pressed.connect(send_wave)
	_hud.auto_departure_toggled.connect(func(key, on): _lanes[key].set_auto_departure(on))
	_hud.spawn_kingdom_pressed.connect(
		func(key): _lanes[key].spawn_kingdom_line(MILITIA, KINGDOM_LINE)
	)


func _choose_brush(brush: int) -> void:
	_brush = brush
	for key in _lanes:
		_lanes[key].brush = BRUSHES[brush]
	if _hud != null:
		_hud.set_tools(_brush, WavePresetStore.names(_presets))


func _toggle_pause() -> void:
	_paused_for_wave = false
	if _clock.is_paused():
		_clock.resume()
	else:
		_clock.pause()


func _order(new_order: int) -> void:
	var selected: Array = $Squads.selected
	if not selected.is_empty():
		_lanes[selected[0]].sim.order(selected[1], new_order)


func _cycle_selection() -> void:
	var options := []
	for key in _lanes:
		for squad in _lanes[key].sim.squads():
			if squad.faction_id == "player" and not squad.is_destroyed():
				options.append([key, squad.id])
	var at := options.find($Squads.selected)
	$Squads.selected = [] if options.is_empty() else options[(at + 1) % options.size()]


func _refresh_hud() -> void:
	if _hud == null:
		return
	var seconds := simulation(lane_keys()[0]).tick_number() * _clock.tick_seconds
	var paused := _clock.is_paused()
	var status := FormationSkirmishReadout.status(seconds, _clock.speed_multiplier, paused)
	_hud.set_status(status, FormationSkirmishReadout.pool(_pool), paused)
	for key in _lanes:
		var line := FormationSkirmishReadout.lane(_lanes[key].production, _allowance(key))
		_hud.set_lane(key, line[0], line[1], line[2], LANE_WIDTHS[key])
	var chosen: Array = $Squads.selected
	var squad = null if chosen.is_empty() else _lanes[chosen[0]].sim.squad(chosen[1])
	_hud.set_selected(FormationSkirmishReadout.selected(chosen, squad))


func _log(lane_key: String, event: Dictionary, text: String) -> void:
	if _hud != null:
		_hud.add_log(
			"t%d %s %s: %s" % [event.get("tick", 0), lane_key, event.get("faction", ""), text]
		)


func _banner(text: String) -> void:
	if _hud != null:
		_hud.show_banner(text)

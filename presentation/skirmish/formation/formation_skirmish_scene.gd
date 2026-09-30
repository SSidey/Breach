class_name FormationSkirmishScene
extends Node2D
## The formation feel test (specs/22-formation-feel-test.md, Decisions 39-41): two lanes
## from P, one FormationSimulation each, stepped by one SkirmishClock; a shared slot pool
## split across the lanes; each lane's wave built into its formation; kingdom militia
## lines; wave-level orders. Engine glue - the rules live in sim/skirmish/formation/.
##
##   godot --path . res://presentation/skirmish/formation/formation_skirmish.tscn

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishFormation = preload("res://sim/skirmish/formation/skirmish_formation.gd")
const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const SkirmishRoute = preload("res://presentation/skirmish/skirmish_route.gd")
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
const START_WIDTHS := {"c": 5, "k": 3}
const KINGDOM_LINE := 3
const KINGDOM_UNIT_SECONDS := 5.0  # a 3-wide militia line every 15 s when auto is on

## Decision 39: a full wave pauses the game (true) or only notifies (false).
var pause_on_wave_full := true

var _clock := SkirmishClock.new()
var _pool: SkirmishSlotPool
var _lanes := {}  # lane key -> {"sim", "production", "kingdom", "width"}
var _kingdom_auto := false
var _paused_for_wave := false
var _hud: FormationSkirmishHud


func lane_keys() -> Array:
	return _lanes.keys()


func simulation(lane_key: String) -> FormationSimulation:
	return _lanes[lane_key]["sim"]


func pool() -> SkirmishSlotPool:
	return _pool


func clock() -> SkirmishClock:
	return _clock


func _ready() -> void:
	var view: MapView = $MapView
	view.map = MAP
	var caps := {}
	for key in LANE_WIDTHS:
		caps[key] = LANE_WIDTHS[key] * SkirmishFormation.MAX_RANKS
	_pool = SkirmishSlotPool.new(POOL_TOTAL, caps)
	for route in MAP.layout.routes:
		_add_lane(
			route.node_b_id, view.model.layout_view.route_points(route.node_a_id, route.node_b_id)
		)
	for key in START_SLOTS:
		assign_slots(key, START_SLOTS[key])
	_hud = FormationSkirmishHud.new()
	add_child(_hud)
	_hud.build(lane_keys())
	_connect_hud()
	_frame_camera()
	_refresh_hud()


func _add_lane(lane_key: String, points: PackedVector2Array) -> void:
	var sim := FormationSimulation.new(
		SkirmishRoute.length_cells(points, MAP.layout.cell_size), _clock.tick_seconds
	)
	var production := FormationProduction.new("player", true, GREM, BRUTE)
	production.lane_width = LANE_WIDTHS[lane_key]
	var kingdom := FormationProduction.new("the_kingdom", false, MILITIA, null)
	kingdom.lane_width = LANE_WIDTHS[lane_key]
	kingdom.build_seconds = KINGDOM_UNIT_SECONDS
	kingdom.departure = FormationProduction.Departure.AUTO_WHEN_FULL
	kingdom.configure(KINGDOM_LINE, KINGDOM_LINE)
	_lanes[lane_key] = {
		"sim": sim, "production": production, "kingdom": kingdom, "width": START_WIDTHS[lane_key]
	}
	$Squads.cell_size = MAP.layout.cell_size
	$Squads.add_lane(lane_key, sim, points)


func _process(delta: float) -> void:
	var due := _clock.advance(delta)
	for i in range(due):
		for key in _lanes:
			var lane: Dictionary = _lanes[key]
			var events: Array = lane["production"].step(lane["sim"])
			if _kingdom_auto:
				events.append_array(lane["kingdom"].step(lane["sim"]))
			events.append_array(lane["sim"].step())
			handle_events(key, events)
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
	var lane: Dictionary = _lanes[lane_key]
	lane["production"].send(lane["sim"])
	if _paused_for_wave:
		_paused_for_wave = false
		_clock.resume()


## Moves slots in the pool; each lane's production picks it up from its next wave.
func assign_slots(lane_key: String, slot_count: int) -> void:
	_pool.assign(lane_key, slot_count)
	for key in _lanes:
		_lanes[key]["production"].configure(_pool.assigned(key), _lanes[key]["width"])


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
	_hud.slots_changed.connect(func(key, delta): assign_slots(key, _pool.assigned(key) + delta))
	_hud.width_changed.connect(_change_width)
	_hud.preset_chosen.connect(func(key, preset): _lanes[key]["production"].preset = preset)
	_hud.send_wave_pressed.connect(send_wave)
	_hud.auto_departure_toggled.connect(_set_departure)
	_hud.spawn_kingdom_pressed.connect(_spawn_kingdom_line)


func _change_width(lane_key: String, delta: int) -> void:
	var lane: Dictionary = _lanes[lane_key]
	lane["width"] = clampi(lane["width"] + delta, 1, LANE_WIDTHS[lane_key])
	lane["production"].configure(_pool.assigned(lane_key), lane["width"])


func _set_departure(lane_key: String, automatic: bool) -> void:
	var departure := (
		FormationProduction.Departure.AUTO_WHEN_FULL
		if automatic
		else FormationProduction.Departure.MANUAL
	)
	_lanes[lane_key]["production"].departure = departure


func _spawn_kingdom_line(lane_key: String) -> void:
	var line := []
	for column in range(KINGDOM_LINE):
		line.append([MILITIA, Vector2i(0, column)])
	_lanes[lane_key]["sim"].spawn_squad(KINGDOM_LINE, line, "the_kingdom", false)


func _toggle_pause() -> void:
	_paused_for_wave = false
	if _clock.is_paused():
		_clock.resume()
	else:
		_clock.pause()


func _order(new_order: int) -> void:
	var selected: Array = $Squads.selected
	if not selected.is_empty():
		_lanes[selected[0]]["sim"].order(selected[1], new_order)


func _cycle_selection() -> void:
	var options := []
	for key in _lanes:
		for squad in _lanes[key]["sim"].squads():
			if squad.faction_id == "player" and not squad.is_destroyed():
				options.append([key, squad.id])
	var at := options.find($Squads.selected)
	$Squads.selected = [] if options.is_empty() else options[(at + 1) % options.size()]


func _refresh_hud() -> void:
	if _hud == null:
		return
	var seconds := simulation(lane_keys()[0]).tick_number() * _clock.tick_seconds
	var paused := _clock.is_paused()
	_hud.set_status(
		FormationSkirmishReadout.status(seconds, _clock.speed_multiplier, paused), paused
	)
	_hud.set_pool(FormationSkirmishReadout.pool(_pool))
	for key in _lanes:
		var line := FormationSkirmishReadout.lane(
			_lanes[key]["production"], _lanes[key]["width"], LANE_WIDTHS[key]
		)
		_hud.set_lane(key, line[0], line[1], line[2])
	var chosen: Array = $Squads.selected
	if chosen.is_empty():
		_hud.set_selected("Click a squad (or Tab) to select it")
	else:
		_hud.set_selected(
			FormationSkirmishReadout.selected(chosen[0], _lanes[chosen[0]]["sim"].squad(chosen[1]))
		)


func _log(lane_key: String, event: Dictionary, text: String) -> void:
	if _hud != null:
		_hud.add_log(
			"t%d %s %s: %s" % [event.get("tick", 0), lane_key, event.get("faction", ""), text]
		)


func _banner(text: String) -> void:
	if _hud != null:
		_hud.show_banner(text)


func _frame_camera() -> void:
	var view: MapView = $MapView
	var bounds: Rect2 = view.model.bounds
	var viewport_size := get_viewport_rect().size
	var usable := Vector2(
		maxf(viewport_size.x - FormationSkirmishHud.PANEL_WIDTH - 30.0, 1.0), viewport_size.y
	)
	var fit := minf(usable.x / bounds.size.x, usable.y / bounds.size.y) * 0.92
	var camera: Camera2D = $Camera
	camera.zoom = Vector2(fit, fit)
	camera.position = (
		bounds.get_center() - Vector2((FormationSkirmishHud.PANEL_WIDTH + 30.0) * 0.5, 0.0) / fit
	)

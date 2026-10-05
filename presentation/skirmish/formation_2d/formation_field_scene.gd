class_name FormationFieldScene
extends Node2D
## The 2D formation feel test (Decision 86, spec 27 rounds 1 and 2): a top-down view of the
## FormationField - the kingdom's line across the middle, the player's routes A and B with
## their corridors, and every unit drawn as its body (Decision 106), a tick at its front,
## eased between ticks. Send a route's wave, let it depart when full, send both timed to
## arrive together, or have B wait in the wood (its detection range ringed) until it sees
## A engage (Decision 87). In a fight units seek contact and face their own foes (Decision
## 88); "Line has a captain" restarts with a led line that turns to meet a flank; Reset
## starts afresh under a battle seed (Decision 93). Every action is logged with its tick
## (FormationFieldActions), for copying out; a log pasted back replays live.
## Controls: FormationFieldHud.
## Engine glue - the rules live in sim/skirmish/formation/.
##
##   godot --path . res://presentation/skirmish/formation_2d/formation_field.tscn

const SkirmishClock = preload("res://sim/skirmish/skirmish_clock.gd")
const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationFieldActions = preload("res://sim/skirmish/formation/formation_field_actions.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationFieldHud = preload("res://presentation/skirmish/formation_2d/formation_field_hud.gd")

const CELL_PX := 8.0
const ORIGIN := Vector2(16, 56)
const FLASH_SECONDS := 0.3
const COLOURS := {
	"grass": Color(0.33, 0.45, 0.25),
	"wood": Color(0.16, 0.3, 0.14),
	"stream": Color(0.18, 0.35, 0.65),
	"ford": Color(0.45, 0.62, 0.8),
	"hill": Color(0.5, 0.45, 0.3),
	"A": Color(0.95, 0.85, 0.3),
	"B": Color(0.95, 0.55, 0.2),
	"C": Color(0.85, 0.4, 0.7),
	"player": Color(0.6, 0.3, 0.75),
	"the_kingdom": Color(0.3, 0.5, 0.9),
	"flash": Color(1, 0.2, 0.2),
	"leader": Color(0.35, 0.1, 0.45),
	"staging": Color(1, 1, 1, 0.8),
	"sight": Color(1, 1, 1, 0.25),
}

var _clock := SkirmishClock.new()
var _field: FormationField
var _previous := {}  # unit id -> position (cells) at the previous tick
var _current := {}  # unit id -> position (cells) at the latest tick
var _flashes := {}  # unit id -> seconds left
var _hud: FormationFieldHud
var _battle_seed := 0
var _log := PackedStringArray()  # "<tick> <action>", after a "seed <n> captain <on|off>"
var _squads_before := {}  # squad id -> its front's position at the previous tick
var _squads_now := {}
var _queued := []  # [tick, action] still to replay, in order


func field() -> FormationField:
	return _field


func clock() -> SkirmishClock:
	return _clock


## Runs `count` ticks at once (the frame loop runs whatever the clock says is due).
func run_ticks(count: int) -> void:
	for _i in range(count):
		while not _queued.is_empty() and _queued[0][0] <= _field.sim.tick_number():
			act(_queued.pop_front()[1])
		for event in _field.step():
			if event["type"] == "hit" and event["flank"]:
				_flashes[event["target"]] = FLASH_SECONDS
		_snapshot()


func _ready() -> void:
	restart(false, randi() % 1000000)
	_hud = FormationFieldHud.new()
	add_child(_hud)
	_hud.build(self)
	var camera := Camera2D.new()
	camera.position = ORIGIN + Vector2(FormationField.SIZE) * CELL_PX * 0.5 - Vector2(0, 40)
	add_child(camera)


## A fresh field, its line led by a captain or not, its battle under `battle_seed`
## (Decision 93: the same seed and orders replay a battle). `queued` ([tick, action] pairs,
## FormationFieldActions.parse) are played at their ticks as the clock runs: a replay.
func restart(captained: bool, battle_seed: int, queued: Array = []) -> void:
	_battle_seed = battle_seed
	_queued = queued.duplicate()
	_field = FormationFieldActions.field(battle_seed, captained)
	_log = PackedStringArray(["seed %d captain %s" % [battle_seed, "on" if captained else "off"]])
	_previous = {}
	_current = {}
	_snapshot()


func _process(delta: float) -> void:
	var due := _clock.advance(delta)
	run_ticks(due)
	for unit_id in _flashes.keys():
		_flashes[unit_id] -= delta
		if _flashes[unit_id] <= 0.0:
			_flashes.erase(unit_id)
	if _hud != null:
		_hud.show_status(_field, _clock.is_paused(), _battle_seed)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_pause()


func _draw() -> void:
	var size := Vector2(FormationField.SIZE) * CELL_PX
	draw_rect(Rect2(ORIGIN, size), COLOURS["grass"])
	draw_rect(_cells(FormationField.WOOD), COLOURS["wood"])
	for ring in range(FormationField.HILL_QUARTERS):
		var shade: Color = COLOURS["hill"].lightened(ring * 0.05)
		draw_rect(_cells(FormationField.HILL.grow(-ring)), shade)
	draw_rect(_cells(FormationField.STREAM), COLOURS["stream"])
	draw_rect(_cells(FormationField.FORD), COLOURS["ford"])
	for key in _field.routes:
		_draw_route(key)
	var fraction := 1.0 if _clock.is_paused() else _clock.fraction()
	_draw_staging()
	for squad in _field.sim.squads():
		for unit in squad.living():
			_draw_unit(squad, unit, fraction)
		_draw_morale(squad)


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
	var radius := minf(unit.footprint_width, unit.footprint_depth) / 2.0 * CELL_PX - 0.5
	var colour: Color = COLOURS["flash"] if _flashes.has(unit.id) else COLOURS[squad.faction_id]
	if unit.leadership > 0 and not _flashes.has(unit.id):
		colour = COLOURS["leader"]
	if squad.state == SkirmishSquad.State.ROUTING:
		colour.a = 0.45  # routers flee one by one
	draw_circle(centre, radius, colour)  # its body (Decision 106)
	if unit.rank == 0 or squad.loose.has(unit.id):
		var front := centre + UnitMotion.vector(unit.bearing) * radius
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


## A bar over the squad's front: its morale, coloured by band (Decision 82).
func _draw_morale(squad: SkirmishSquad) -> void:
	if squad.living().is_empty() or squad.state == SkirmishSquad.State.ROUTING:
		return
	var band_colours := [Color(0.3, 0.9, 0.3), Color(0.95, 0.85, 0.2), Color(1, 0.5, 0.1)]
	var band: int = FormationMorale.band(squad)
	var colour: Color = band_colours[band] if band < band_colours.size() else Color.RED
	var fraction := 1.0 if _clock.is_paused() else _clock.fraction()
	var before: Vector2 = _squads_before.get(squad.id, squad.position)
	var front: Vector2 = before.lerp(_squads_now.get(squad.id, squad.position), fraction)
	var top := ORIGIN + front * CELL_PX + Vector2(-12, -6 * CELL_PX)  # eased, as its units
	draw_rect(Rect2(top, Vector2(24, 3)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(top, Vector2(24 * squad.morale / 100.0, 3)), colour)


func _cells(area: Rect2) -> Rect2:
	return Rect2(ORIGIN + area.position * CELL_PX, area.size * CELL_PX)


func _snapshot() -> void:
	_previous = _current
	_current = {}
	_squads_before = _squads_now
	_squads_now = {}
	for squad in _field.sim.squads():
		_squads_now[squad.id] = squad.position
	for squad in _field.sim.squads():
		for unit in squad.units:
			_current[unit.id] = unit.position


## Applies a player action (FormationFieldActions' words) and logs it with its tick.
func act(action: String) -> void:
	if FormationFieldActions.apply(_field, action):
		_log.append("%d %s" % [_field.sim.tick_number(), action])


## The session so far, to copy out: a replay of it gives the same battle.
func action_log() -> String:
	return "\n".join(_log)


func toggle_pause() -> void:
	if _clock.is_paused():
		_clock.resume()
	else:
		_clock.pause()

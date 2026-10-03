class_name FormationField
extends RefCounted
## The 2D feel test's field (Decision 86, spec 27 round 1): one FormationSimulation over a
## strip 2 tiles wide and 1 deep (128 x 64 cells). The kingdom holds a line across the
## middle, facing the player. The player's waves come from the west on two routes:
## - **A**, straight at the line over open grass
## - **B**, swinging north through the wood (and its ford) and, in round 1, rejoining A
##   before the line, so its wave reinforces from behind (Decision 44); round 2 redraws it
##   onto the line's side
## The wood, ford and hill are drawn only until terrain arrives (round 4). The player's
## domain builders fill both waves in turn. Pure.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const DomainProduction = preload("res://sim/skirmish/formation/domain_production.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const SIZE := Vector2i(128, 64)
## Where the kingdom's line holds its front, in cells along x.
const LINE_AT := 80.0
const KINGDOM_WIDTH := 8
const KINGDOM_RANKS := 2
const WAVE_WIDTH := 8
## Scenery, in cells, drawn by the scene (no effect until round 4).
const WOOD := Rect2(16, 0, 28, 22)
const FORD := Rect2(28, 0, 3, 22)
const HILL := Rect2(92, 16, 20, 32)

var tick_seconds: float
var sim: FormationSimulation
var player := DomainProduction.new("player")
var routes := {}  # "A" / "B" -> FormationRoute
var waves := {}  # "A" / "B" -> FormationProduction
var kingdom_line: SkirmishSquad

var _tick := 0


## The routes' waypoints in cells: both end at the far side along the centre line.
static func route_points() -> Dictionary:
	return {
		"A": PackedVector2Array([Vector2(0, 32), Vector2(128, 32)]),
		"B":
		PackedVector2Array([Vector2(0, 10), Vector2(48, 10), Vector2(48, 32), Vector2(128, 32)]),
	}


func _init(
	seconds_per_tick: float, wave_unit: UnitDef, builders: int, kingdom_unit: UnitDef
) -> void:
	tick_seconds = seconds_per_tick
	sim = FormationSimulation.new(float(SIZE.x) / MapLayoutDef.CELLS_PER_TILE, seconds_per_tick)
	sim.combat_width = WAVE_WIDTH
	var points := route_points()
	for key in points:
		routes[key] = FormationRoute.new(points[key], WAVE_WIDTH / 2.0)
		var wave := FormationProduction.new("player", true)
		wave.route = routes[key]
		wave.set_template(WavePresets.line(wave_unit, WAVE_WIDTH, WAVE_WIDTH))
		waves[key] = wave
	player.set_builders(wave_unit, builders)
	player.prefer("")  # round robin (Decision 51)
	_hold_the_line(kingdom_unit)


## One tick: the builders fill the waves, full waves announce (and depart if automatic),
## then the fight.
func step() -> Array:
	var events := player.step(waves, tick_seconds, _tick)
	for key in waves:
		events.append_array(waves[key].step(sim))
	events.append_array(sim.step())
	_tick += 1
	return events


## Sends a route's wave with whatever is built; null if nothing is.
func send(key: String) -> SkirmishSquad:
	return waves[key].send(sim)


func set_auto(key: String, automatic: bool) -> void:
	waves[key].departure = (
		FormationProduction.Departure.AUTO_WHEN_FULL
		if automatic
		else FormationProduction.Departure.MANUAL
	)


func _hold_the_line(unit_def: UnitDef) -> void:
	var placements := []
	for rank in range(KINGDOM_RANKS):
		for column in range(KINGDOM_WIDTH):
			placements.append([unit_def, Vector2i(rank, column)])
	kingdom_line = sim.spawn_squad(KINGDOM_WIDTH, placements, "the_kingdom", false, 0, routes["A"])
	kingdom_line.front_distance = LINE_AT / MapLayoutDef.CELLS_PER_TILE
	kingdom_line.home_distance = kingdom_line.front_distance
	sim.order(kingdom_line.id, SkirmishUnit.Order.HOLD)

class_name FormationField
extends RefCounted
## The 2D feel test's field (Decision 86, spec 27 rounds 1 and 2): one FormationSimulation
## over a strip 2 tiles wide and 1 deep (128 x 64 cells). The kingdom holds a line across
## the middle, facing the player. The player's waves come from the west on two routes:
## - **A**, straight at the line over open grass
## - **B**, north through the wood (and its ford), then south onto the line's north side
## A wave on B can wait in the wood until it sees A's wave, its chieftain timing the flank
## to land with A's attack (Decision 87's hold-until, coordinated by a leader), or both can
## be sent together, timed to arrive at once (planned rendezvous). Wings walk round the
## line's ends (Decision 81). A broken line routs east into the kingdom's reserve on the
## hill (Decision 82); the player's routers who reach home go back to the reserve. The
## ground matters (Decision 85): the wood slows and hides, B's wave narrows through the
## ford, and the reserve fights down from the hill. The player's domain builders fill both
## waves in turn. Pure.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const FormationRendezvous = preload("res://sim/skirmish/formation/formation_rendezvous.gd")
const FormationStaging = preload("res://sim/skirmish/formation/formation_staging.gd")
const DomainProduction = preload("res://sim/skirmish/formation/domain_production.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const SIZE := Vector2i(128, 64)
## Where the kingdom's line holds its front, in cells along x, across y = 32.
const LINE_AT := 80.0
const KINGDOM_WIDTH := 6
const KINGDOM_RANKS := 2
## The kingdom's reserve holds behind the line, on the hill.
const RESERVE_AT := 96.0
const RESERVE_WIDTH := 6
const WAVE_WIDTH := 8
## Where route B turns south onto the line's side, and where its wave waits in the wood.
const FLANK_X := 81.0
## Route B runs east along the wood's southern edge, one cell inside the trees.
const B_Y := 21.0
const STAGING := Vector2(56, B_Y)
## How long a waiting wave holds before going anyway (seconds).
const WAIT_SECONDS := 60.0
## Scenery, in cells, drawn by the scene (no effect until round 4).
## The ground (Decision 85): a wood (half pace, blocks sight) that route B runs through
## along its southern edge, a stream too deep for grems with a 4-cell ford on route B, and
## the hill under the reserve, rising a quarter-cell a cell to 2 cells high.
const WOOD := Rect2(16, 0, 44, 22)
const STREAM := Rect2(28, 0, 3, 28)
const FORD := Rect2(28, B_Y - 2, 3, 4)
const HILL := Rect2(92, 16, 20, 32)
const STREAM_DEPTH := 1.2
const FORD_DEPTH := 0.4
const HILL_QUARTERS := 8

var tick_seconds: float
var sim: FormationSimulation
var player := DomainProduction.new("player")
var routes := {}  # "A" / "B" -> FormationRoute
var waves := {}  # "A" / "B" -> FormationProduction
var kingdom_line: SkirmishSquad
var kingdom_reserve: SkirmishSquad

var _wave_unit: UnitDef
var _tick := 0


static func route_points() -> Dictionary:
	return {
		"A": PackedVector2Array([Vector2(0, 32), Vector2(128, 32)]),
		"B": PackedVector2Array([Vector2(0, B_Y), Vector2(FLANK_X, B_Y), Vector2(FLANK_X, 64)]),
	}


## How far along each route a wave's front meets the line: A its front, B its north side.
static func contact_cells() -> Dictionary:
	var north_face := 32.0 - KINGDOM_WIDTH / 2.0
	return {"A": LINE_AT - 1.0, "B": FLANK_X + (north_face - 1.0 - B_Y)}


## `leader_unit`, if given, leads route B's wave from its second rank.
func _init(
	seconds_per_tick: float,
	wave_unit: UnitDef,
	builders: int,
	kingdom_unit: UnitDef,
	leader_unit: UnitDef = null
) -> void:
	tick_seconds = seconds_per_tick
	_wave_unit = wave_unit
	sim = FormationSimulation.new(float(SIZE.x) / MapLayoutDef.CELLS_PER_TILE, seconds_per_tick)
	sim.combat_width = WAVE_WIDTH
	sim.walk_wings = true
	sim.terrain = _ground()
	var points := route_points()
	for key in points:
		routes[key] = FormationRoute.new(points[key], WAVE_WIDTH / 2.0)
		var wave := FormationProduction.new("player", true)
		wave.route = routes[key]
		var template := WavePresets.line(wave_unit, WAVE_WIDTH, WAVE_WIDTH)
		if key == "B" and leader_unit != null:
			template.slot_limit += 1
			template.paint(leader_unit, Vector2i(1, WAVE_WIDTH / 2))
		wave.set_template(template)
		waves[key] = wave
	player.set_builders(wave_unit, builders)
	if leader_unit != null:
		player.set_builders(leader_unit, 1)
	player.prefer("")  # round robin (Decision 51)
	_hold_the_line(kingdom_unit)


## One tick: the builders fill the waves, full waves announce (and depart if automatic),
## then the fight.
func step() -> Array:
	var events := player.step(waves, tick_seconds, _tick)
	for key in waves:
		events.append_array(waves[key].step(sim))
	var fought := sim.step()
	for event in fought:
		if event["type"] == "fled_home" and event["faction"] == "player":
			player.bank([event["definition"]])  # back to the reserve
	events.append_array(fought)
	_tick += 1
	return events


## Sends a route's wave with whatever is built; null if nothing is.
func send(key: String) -> SkirmishSquad:
	return waves[key].send(sim)


## Sends the routes' waves now, each waiting so that all reach the line together (planned
## rendezvous, Decision 87). Returns the squads sent.
func send_together(keys: Array) -> Array:
	var predicted := {}
	var cells_per_second := _wave_unit.speed * FormationSimulation.TRAVEL_SCALE * 64.0
	for key in keys:
		predicted[key] = FormationRendezvous.ticks_to(
			routes[key],
			contact_cells()[key],
			WAVE_WIDTH,
			cells_per_second,
			tick_seconds,
			0.0,
			sim.terrain
		)
	var waits := FormationRendezvous.waits(predicted)
	var sent := []
	for key in keys:
		var squad: SkirmishSquad = waves[key].send(sim, waits[key])
		if squad != null:
			sent.append(squad)
	return sent


func set_auto(key: String, automatic: bool) -> void:
	waves[key].departure = (
		FormationProduction.Departure.AUTO_WHEN_FULL
		if automatic
		else FormationProduction.Departure.MANUAL
	)


## Makes route B's waves wait in the wood until they see route A's wave (Decision 87). A
## coordinated chieftain then times the flank to land as A reaches the line's front;
## without one the wave goes on sight. After the wait runs out it goes anyway. False sends
## them straight on.
func set_wait(waiting: bool) -> void:
	waves["B"].staging = {}
	if waiting:
		waves["B"].staging = {
			"at": STAGING.x,
			"trigger": FormationStaging.SEES_PARTNER,
			"partner": 0,
			"fallback": roundi(WAIT_SECONDS / tick_seconds),
			"then": "go",
			"meet": Vector2(contact_cells()["A"], 32),
			"meet_cells": contact_cells()["B"],
		}


## The field's terrain (Decision 85).
static func _ground() -> FormationTerrain:
	var terrain := FormationTerrain.new(SIZE)
	terrain.paint(Rect2i(WOOD), {"cost": 0.5, "blocks_sight": true})
	terrain.paint(Rect2i(STREAM), {"depth": STREAM_DEPTH})
	terrain.paint(Rect2i(FORD), {"depth": FORD_DEPTH})
	for ring in range(HILL_QUARTERS):
		terrain.paint(Rect2i(HILL.grow(-ring)), {"height": ring + 1})
	return terrain


func _hold_the_line(unit_def: UnitDef) -> void:
	var placements := []
	for rank in range(KINGDOM_RANKS):
		for column in range(KINGDOM_WIDTH):
			placements.append([unit_def, Vector2i(rank, column)])
	kingdom_line = sim.spawn_squad(KINGDOM_WIDTH, placements, "the_kingdom", false, 0, routes["A"])
	kingdom_line.front_distance = LINE_AT / MapLayoutDef.CELLS_PER_TILE  # home: the far end
	sim.order(kingdom_line.id, SkirmishUnit.Order.HOLD)
	var reserve := []
	for column in range(RESERVE_WIDTH):
		reserve.append([unit_def, Vector2i(0, column)])
	kingdom_reserve = sim.spawn_squad(RESERVE_WIDTH, reserve, "the_kingdom", false, 0, routes["A"])
	kingdom_reserve.front_distance = RESERVE_AT / MapLayoutDef.CELLS_PER_TILE
	sim.order(kingdom_reserve.id, SkirmishUnit.Order.HOLD)

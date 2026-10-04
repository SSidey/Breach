class_name FormationMarch
extends RefCounted
## A squad's march along its route (Decisions 74 and 75, spec 27 round 1): how long its
## route is, which way it faces there, reaching either end, and where its units stand for
## views - along the route (`distance`, for the one-lane scene) and in cells (`position`).
## Pure over the squads it is given; FormationSimulation calls it each tick.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationShuffle = preload("res://sim/skirmish/formation/formation_shuffle.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")


## The squad's route length in tiles (`fallback` for a squad without a route).
static func length(squad: SkirmishSquad, fallback: float) -> float:
	if squad.route == null:
		return fallback
	return squad.route.length_cells() / MapLayoutDef.CELLS_PER_TILE


## Which way the squad's order takes it along its route: +1 up it, -1 down it. Advancing
## heads for the end away from home, retreating for home.
static func travel_sign(squad: SkirmishSquad, route_end: float) -> int:
	var enemy_end := route_end if is_zero_approx(squad.home_distance) else 0.0
	var advancing := squad.order == SkirmishUnit.Order.ADVANCE
	var target := enemy_end if advancing else squad.home_distance
	if is_equal_approx(target, squad.front_distance):
		return squad.direction
	return 1 if target > squad.front_distance else -1


## Turns the squad at once to the facing nearest its route's heading at its front: where it
## is placed (FormationTurning times turns on the march).
static func face(squad: SkirmishSquad) -> void:
	if squad.route == null:
		return
	var cells := squad.front_distance * MapLayoutDef.CELLS_PER_TILE
	squad.facing = squad.route.facing_at(cells, squad.direction, squad.facing)


## Arrival at the enemy's end (the fort is immune in the feel test), or a retreat home.
static func check_ends(mover: SkirmishSquad, route_end: float, tick: int, events: Array) -> void:
	var enemy_end := route_end if is_zero_approx(mover.home_distance) else 0.0
	if (
		mover.order == SkirmishUnit.Order.ADVANCE
		and is_equal_approx(mover.front_distance, enemy_end)
	):
		mover.front_distance = enemy_end
		mover.state = SkirmishSquad.State.ARRIVED
		events.append(FormationEvents.squad_event("arrived", tick, mover))
	elif (
		mover.order == SkirmishUnit.Order.RETREAT
		and is_equal_approx(mover.front_distance, mover.home_distance)
	):
		mover.front_distance = mover.home_distance
		mover.order = SkirmishUnit.Order.HOLD
		mover.state = SkirmishSquad.State.HOLDING
		events.append(FormationEvents.squad_event("returned", tick, mover))


## Units mirror their squad's placement - including any swap under way - so views can read
## unit.distance (along the route) and unit.position (the centre of its cells).
static func sync_units(squads: Array) -> void:
	for entry in squads:
		for unit in entry.units:
			var swapping := FormationShuffle.offset(entry, unit)
			unit.distance = (
				entry.unit_distance(unit) + entry.direction * swapping.x * SkirmishSquad.RANK_DEPTH
			)
			var rect := SquadFrame.unit_rect(
				entry.position, entry.facing, entry.width, entry.centre_shift, unit
			)
			var shift := (
				SquadFrame.forward(entry.facing) * swapping.x
				+ SquadFrame.right(entry.facing) * swapping.y
			)
			unit.position = rect.get_center() + shift

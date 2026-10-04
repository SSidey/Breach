class_name FormationPursuit
extends RefCounted
## A formation pursuing as a whole (Decision 95, spec 27 round 8): ordered to pursue, or
## led by a pursuer, when its enemy retreats it stays locked on it and its frame advances
## along its own route after it, no faster than its units keep up, its units seeking
## contact as they go at the march pace. When
## the enemy is out of PURSUIT_REACH, gone, or no longer retreating, it gives up: it marches
## back to the post it held and turns to face the way it held it, taking up its order
## again. Squads keep `pursuit` ({"foe", "post", "home", "direction", "order",
## "returning"}). Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const ScrumTurn = preload("res://sim/skirmish/formation/scrum_turn.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

## How far (cells, between their extents) it follows before giving up (placeholder).
const PURSUIT_REACH := 16.0
## It advances while its enemy is more than this many cells ahead of its front, and its
## foremost unit no more than LAG_CELLS behind it.
const CLOSE_ENOUGH := 1.0
const LAG_CELLS := 2.0


## Sets `squad` pursuing the retreating `foe`.
static func begin(squad: SkirmishSquad, foe: SkirmishSquad, tick: int, events: Array) -> void:
	FormationLocks.lock(squad, foe)
	if squad.pursuit.is_empty():
		squad.pursuit = {
			"foe": foe.id,
			"post": squad.front_distance,
			"home": squad.home_distance,
			"direction": squad.direction,
			"order": squad.order,
			"returning": false,
		}
	events.append(FormationEvents.squad_event("pursuing", tick, squad, {"of": foe.id}))


## One tick of pursuit: pursuers advance after their enemy or give up and go back.
static func step(
	squads: Array, tick: int, cells_per_second: float, seconds: float, events: Array
) -> void:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	for squad in squads:
		if squad.pursuit.is_empty() or squad.is_destroyed():
			continue
		if squad.pursuit["returning"]:
			_arrive(squad, tick, events)
			continue
		var foe: SkirmishSquad = by_id.get(squad.pursuit["foe"])
		if _given_up(squad, foe):
			_go_back(squad, squads, tick, events)
		else:
			_advance(squad, foe, cells_per_second * seconds)


static func _given_up(squad: SkirmishSquad, foe: SkirmishSquad) -> bool:
	if foe == null or foe.is_destroyed() or foe.order != SkirmishUnit.Order.RETREAT:
		return true
	return _gap(squad, foe) > PURSUIT_REACH


## Its frame moves along its route towards the enemy while the enemy is ahead.
static func _advance(squad: SkirmishSquad, foe: SkirmishSquad, step_cells: float) -> void:
	var ahead := (SquadEdges.bounds(foe).get_center() - squad.position).dot(
		SquadFrame.forward(squad.facing)
	)
	if ahead <= CLOSE_ENOUGH or _lagging(squad):
		return
	var tiles := minf(squad.speed() * step_cells, ahead - CLOSE_ENOUGH)
	tiles /= MapLayoutDef.CELLS_PER_TILE
	var length := 1e9
	if squad.route != null:
		length = squad.route.length_cells() / MapLayoutDef.CELLS_PER_TILE
	squad.front_distance = clampf(squad.front_distance + squad.direction * tiles, 0.0, length)


## True if its units lag too far behind its front to follow it further.
static func _lagging(squad: SkirmishSquad) -> bool:
	var forward := SquadFrame.forward(squad.facing)
	var foremost := -INF
	for unit_id in squad.loose:
		var entry: Dictionary = squad.loose[unit_id]
		foremost = maxf(foremost, (entry["at"] - squad.position).dot(forward))
	return foremost < -LAG_CELLS


## It ends its fight and marches back to its post (a march home, with home its post).
static func _go_back(squad: SkirmishSquad, squads: Array, tick: int, events: Array) -> void:
	FormationLocks.release(squad, squads)
	squad.pursuit["returning"] = true
	squad.home_distance = squad.pursuit["post"]
	squad.order = SkirmishUnit.Order.RETREAT
	events.append(FormationEvents.squad_event("pursuit_ended", tick, squad))


## Back at its post (its march home ended), it faces the way it held it and takes up its
## order again.
static func _arrive(squad: SkirmishSquad, tick: int, events: Array) -> void:
	if squad.order == SkirmishUnit.Order.RETREAT:
		return  # still marching back
	var held: Dictionary = squad.pursuit
	squad.home_distance = held["home"]
	squad.order = held["order"]
	squad.pursuit = {}
	ScrumTurn.begin(squad, held["direction"], tick, events)


static func _gap(squad: SkirmishSquad, foe: SkirmishSquad) -> float:
	var mine := SquadEdges.bounds(squad)
	var theirs := SquadEdges.bounds(foe)
	var near := theirs.get_center().clamp(mine.position, mine.end)
	return near.distance_to(near.clamp(theirs.position, theirs.end))

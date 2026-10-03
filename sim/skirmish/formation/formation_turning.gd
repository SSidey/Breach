class_name FormationTurning
extends RefCounted
## Turning a squad as a block (Decision 74, spec 27 round 1):
## - an **about-face** when its order leads back the way it faces (a retreat, or advancing
##   again after one): a short pause, then its back rank is its front
## - a **wheel** where its route bends: as long as the outer end needs to march its quarter
##   arc, pivoting on the front centre
## A turning squad neither advances nor strikes; blows on it are flank blows
## (FormationSimulation). It may be engaged meanwhile, and fights once the turn ends.
## Pure over the squad it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadTurn = preload("res://sim/skirmish/formation/squad_turn.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")


## Starts a turn if the squad must face another way before it moves `travel_sign` (+1 up
## its route, -1 down it). True if it started one; the squad doesn't move this tick.
static func begin(
	squad: SkirmishSquad, travel_sign: int, cells_per_second: float, tick_seconds: float
) -> bool:
	if travel_sign != squad.direction:
		_start(squad, SquadFrame.opposite(squad.facing), SquadTurn.about_face_ticks(tick_seconds))
		squad.about_facing = true
		return true
	if squad.route == null:
		return false
	var cells := squad.front_distance * MapLayoutDef.CELLS_PER_TILE
	var wanted := squad.route.facing_at(cells, squad.direction, squad.facing)
	if wanted == squad.facing:
		return false
	var ticks := SquadTurn.wheel_ticks(squad.width, cells_per_second, tick_seconds)
	_start(squad, wanted, ticks * 2 if wanted == SquadFrame.opposite(squad.facing) else ticks)
	return true


## One tick of a turn under way; on its last the squad takes its new facing (an about-face
## its reversed ranks too) and goes back to fighting or marching. True if the squad was
## turning this tick, so it doesn't move.
static func step(squad: SkirmishSquad, tick: int, events: Array) -> bool:
	if squad.state != SkirmishSquad.State.TURNING:
		return false
	squad.turn_ticks -= 1
	if squad.turn_ticks > 0:
		return true
	if squad.about_facing:
		var depth := SquadTurn.reverse_ranks(squad)
		squad.front_distance -= squad.direction * depth * SkirmishSquad.RANK_DEPTH
		squad.direction = -squad.direction
		squad.about_facing = false
	squad.facing = squad.turn_to
	var fighting := squad.engaged_with != 0 or not squad.flank_contacts.is_empty()
	squad.state = SkirmishSquad.State.FIGHTING if fighting else SkirmishSquad.State.MOVING
	events.append(FormationEvents.squad_event("turned", tick, squad, {"facing": squad.facing}))
	return true


static func _start(squad: SkirmishSquad, facing: int, ticks: int) -> void:
	squad.state = SkirmishSquad.State.TURNING
	squad.turn_to = facing
	squad.turn_ticks = ticks

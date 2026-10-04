class_name ScrumStance
extends RefCounted
## A led squad meets a threat as a line (Decision 88, spec 27 round 5): with its front
## free, when it sees an enemy coming at another face it re-lays its places facing the
## threat at that face (its stance) before contact, from further off the better it is led.
## Its units keep to those places until the threat has gone. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

## How far off (cells) a led squad turns to meet a threat: 4 plus 4 per point of leadership.
const ANTICIPATE := 4.0
const ANTICIPATE_PER_LEADERSHIP := 4.0


## The place a unit keeps to: in its squad's stance if it has one.
static func anchor(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	if squad.stance.is_empty():
		var rect := SquadFrame.unit_rect(
			squad.position, squad.facing, squad.width, squad.centre_shift, unit
		)
		return rect.get_center()
	var place := SquadFrame.unit_rect(
		squad.stance["anchor"], squad.stance["facing"], squad.width, 0.0, unit
	)
	return place.get_center()


## A led squad with a free front turns its line to meet a threat it sees coming at
## another face; it lets the stance go once none is near and it isn't fighting.
static func anticipate(
	squad: SkirmishSquad, squads: Array, tick: int, events: Array, terrain: FormationTerrain
) -> void:
	var standing := squad.state in [SkirmishSquad.State.HOLDING, SkirmishSquad.State.FIGHTING]
	var led := FormationMorale.leadership(squad)
	if not standing or squad.engaged_with != 0 or led < 1:
		return
	var reach := ANTICIPATE + ANTICIPATE_PER_LEADERSHIP * led
	var threat := _threat(squad, squads, terrain, reach)
	if threat < 0 or threat == squad.facing:
		if squad.state != SkirmishSquad.State.FIGHTING:
			squad.stance = {}
		return
	if not squad.stance.is_empty() and squad.stance["facing"] == threat:
		return
	var area := SquadEdges.bounds(squad)
	var outward := SquadFrame.forward(threat)
	var face := area.get_center() + outward * area.size / 2.0
	squad.stance = {"anchor": face, "facing": threat}
	events.append(FormationEvents.squad_event("faced", tick, squad, {"facing": threat}))


## The facing towards the nearest seen hostile within `reach` cells, or -1.
static func _threat(
	squad: SkirmishSquad, squads: Array, terrain: FormationTerrain, reach: float
) -> int:
	var area := SquadEdges.bounds(squad)
	var best := reach + 0.000001
	var facing := -1
	for other in squads:
		if other.faction_id == squad.faction_id or other.is_destroyed():
			continue
		if other.state == SkirmishSquad.State.ROUTING:
			continue
		if not FormationSight.detects(squad, other, terrain):
			continue
		var theirs := SquadEdges.bounds(other)
		var nearest := theirs.get_center().clamp(area.position, area.end)
		var point := nearest.clamp(theirs.position, theirs.end)
		var gap := nearest.distance_to(point)
		if gap < best:
			best = gap
			facing = ScrumReach.facing_to(area.get_center(), point)
	return facing

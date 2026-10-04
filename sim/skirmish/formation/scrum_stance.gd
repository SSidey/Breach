class_name ScrumStance
extends RefCounted
## A disciplined squad meets a threat as a line (Decisions 88 and 92, spec 27 rounds 5
## and 6): marching or holding, with its front free, when it sees an enemy closing in on
## another face within ANTICIPATE cells and is disciplined enough (FormationDiscipline), it
## re-lays its places facing the threat at that face (its stance) before contact. Its
## units walk there at its re-form pace and keep to those places until the threat has
## gone; it doesn't march meanwhile. A less disciplined squad meets it unit by unit. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

## How far off (cells) a squad re-forms to meet a threat closing in (placeholder).
const ANTICIPATE := 12.0


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


## A disciplined squad with a free front turns its line to meet a threat it sees closing
## in at another face; it lets the stance go once none is and it isn't fighting.
static func anticipate(
	squad: SkirmishSquad, squads: Array, tick: int, events: Array, terrain: FormationTerrain
) -> void:
	var able := (
		squad.state
		in [SkirmishSquad.State.HOLDING, SkirmishSquad.State.MOVING, SkirmishSquad.State.FIGHTING]
	)
	if not able or squad.engaged_with != 0 or not FormationDiscipline.meets_threats(squad):
		return
	var threat := _threat(squad, squads, terrain, true)
	if threat < 0 or threat == squad.facing:
		var gone := _threat(squad, squads, terrain, false) < 0
		if squad.state != SkirmishSquad.State.FIGHTING and (gone or threat == squad.facing):
			squad.stance = {}  # held while the enemy that started it is still near
		return
	if not squad.stance.is_empty() and squad.stance["facing"] == threat:
		return
	var area := SquadEdges.bounds(squad)
	var outward := SquadFrame.forward(threat)
	var face := area.get_center() + outward * area.size / 2.0
	squad.stance = {"anchor": face, "facing": threat}
	events.append(FormationEvents.squad_event("faced", tick, squad, {"facing": threat}))


## The facing towards the nearest seen hostile within ANTICIPATE cells - closing in, if
## `closing` - or -1.
static func _threat(
	squad: SkirmishSquad, squads: Array, terrain: FormationTerrain, closing: bool
) -> int:
	var area := SquadEdges.bounds(squad)
	var best := ANTICIPATE + 0.000001
	var facing := -1
	for other in squads:
		if other.faction_id == squad.faction_id or other.is_destroyed():
			continue
		if other.state == SkirmishSquad.State.ROUTING:
			continue
		if not FormationSight.detects(squad, other, terrain):
			continue
		if closing and not _closing(other, area):
			continue
		var theirs := SquadEdges.bounds(other)
		var nearest := theirs.get_center().clamp(area.position, area.end)
		var point := nearest.clamp(theirs.position, theirs.end)
		var gap := nearest.distance_to(point)
		if gap < best:
			best = gap
			facing = ScrumReach.facing_to(area.get_center(), point)
	return facing


## True if `other` is closing in on `area`: marching or fighting with its front towards it
## (a reserve holding its ground is no reason to re-form).
static func _closing(other: SkirmishSquad, area: Rect2) -> bool:
	if other.state not in [SkirmishSquad.State.MOVING, SkirmishSquad.State.FIGHTING]:
		return false
	var towards := area.get_center() - SquadEdges.bounds(other).get_center()
	return towards.dot(SquadFrame.forward(other.facing)) > 0.0

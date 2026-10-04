class_name ScrumStance
extends RefCounted
## A disciplined squad meets a threat as a line (Decisions 88 and 92, spec 27 rounds 5
## and 6): marching or holding, with its front free, when it sees an enemy closing in on
## another face within ANTICIPATE cells and is disciplined enough (FormationDiscipline), it
## re-lays its places facing the threat at that face (its stance) before contact, and
## commits to it: it faces that enemy while it is still a threat, not swinging to another. Its
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
	if not able or squad.engaged_with != 0:
		return
	if not FormationDiscipline.meets_threats(squad):
		if squad.state != SkirmishSquad.State.FIGHTING:
			squad.stance = {}  # it can't hold a re-formed line: back to its places
		return
	if _committed(squad, squads):
		return  # it made its call: it faces that enemy while it is still a threat
	var found := _threat(squad, squads, terrain, true)
	var threat: int = found[0]
	if threat < 0 or threat == squad.facing:
		var gone: bool = _threat(squad, squads, terrain, false)[0] < 0
		var holds := squad.order == SkirmishUnit.Order.HOLD and not gone
		if squad.state != SkirmishSquad.State.FIGHTING and (not holds or threat == squad.facing):
			squad.stance = {}  # a holding line keeps it while that enemy is near (Decision 94)
		return
	if not squad.stance.is_empty() and squad.stance["facing"] == threat:
		return
	var area := SquadEdges.bounds(squad)
	var outward := SquadFrame.forward(threat)
	var face := area.get_center() + outward * area.size / 2.0
	squad.stance = {"anchor": face, "facing": threat, "foe": found[1]}
	events.append(FormationEvents.squad_event("faced", tick, squad, {"facing": threat}))


## True if the squad holds a re-formed line towards an enemy that is still a threat - alive,
## not routing, within ANTICIPATE cells, and closing in (or near a line ordered to hold): it
## doesn't swing to another.
static func _committed(squad: SkirmishSquad, squads: Array) -> bool:
	if squad.stance.is_empty() or not squad.stance.has("foe"):
		return false
	for other in squads:
		if other.id != squad.stance["foe"]:
			continue
		if other.is_destroyed() or other.state == SkirmishSquad.State.ROUTING:
			return false
		var holding := squad.order == SkirmishUnit.Order.HOLD
		var pressing := holding or _closing(other, squad)
		return pressing and _gap(squad, other) <= ANTICIPATE
	return false


## [facing, squad id] towards the nearest seen hostile within ANTICIPATE cells - closing
## in, if `closing` - or [-1, 0].
static func _threat(
	squad: SkirmishSquad, squads: Array, terrain: FormationTerrain, closing: bool
) -> Array:
	var area := SquadEdges.bounds(squad)
	var best := ANTICIPATE + 0.000001
	var facing := -1
	var foe := 0
	for other in squads:
		if other.faction_id == squad.faction_id or other.is_destroyed():
			continue
		if other.state == SkirmishSquad.State.ROUTING:
			continue
		if not FormationSight.detects(squad, other, terrain):
			continue
		if closing and not _closing(other, squad):
			continue
		var gap := _gap(squad, other)
		if gap < best:
			best = gap
			var theirs := SquadEdges.bounds(other)
			var point := area.get_center().clamp(theirs.position, theirs.end)
			facing = ScrumReach.facing_to(area.get_center(), point)
			foe = other.id
	return [facing, foe]


static func _gap(squad: SkirmishSquad, other: SkirmishSquad) -> float:
	var area := SquadEdges.bounds(squad)
	var theirs := SquadEdges.bounds(other)
	var nearest := theirs.get_center().clamp(area.position, area.end)
	return nearest.distance_to(nearest.clamp(theirs.position, theirs.end))


## True if `other` is closing in on `squad`: marching with its front towards it, or
## fighting it. A line holding its ground, or fighting someone else, is no reason to
## re-form.
static func _closing(other: SkirmishSquad, squad: SkirmishSquad) -> bool:
	var fights_it: bool = (
		other.engaged_with == squad.id
		or other.flank_contacts.values().any(func(c): return c["foe"] == squad.id)
	)
	if fights_it:
		return true
	if other.state != SkirmishSquad.State.MOVING:
		return false
	var towards := SquadEdges.bounds(squad).get_center() - SquadEdges.bounds(other).get_center()
	return towards.dot(SquadFrame.forward(other.facing)) > 0.0

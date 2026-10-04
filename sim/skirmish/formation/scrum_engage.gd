class_name ScrumEngage
extends RefCounted
## Fights start where units meet (Decision 88, spec 27 round 6): with contact-seeking, two
## hostile squads whose units come within REACH of each other lock into a fight, whatever
## their faces - a squad passing beside a line, or a line it brushes, fights rather than
## walking by. A squad already fighting is joined by the one that reached it, and keeps
## its own foe. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")

## How far apart (cells, between their cells) two units may be for their squads to engage.
const REACH := 1.0


## Locks free squads onto hostile squads their units have come within reach of. Returns
## "engaged" events.
static func step(squads: Array, tick: int) -> Array:
	var events := []
	for squad in squads:
		if not _free(squad):
			continue
		for other in squads:
			if other.faction_id == squad.faction_id or not FormationContact.can_engage(other):
				continue
			if not _near(squad, other):
				continue
			FormationLocks.lock(squad, other)
			if _free(other):
				FormationLocks.lock(other, squad)
			events.append(FormationEvents.squad_event("engaged", tick, squad, {"with": other.id}))
			break
	return events


static func _free(squad: SkirmishSquad) -> bool:
	return (
		FormationContact.can_engage(squad)
		and squad.engaged_with == 0
		and squad.flank_contacts.is_empty()
		and squad.state != SkirmishSquad.State.FIGHTING
		and squad.state != SkirmishSquad.State.TURNING
	)


static func _near(squad: SkirmishSquad, other: SkirmishSquad) -> bool:
	for unit in squad.living():
		var mine := ScrumReach.area(squad, unit).grow(REACH - ScrumReach.CONTACT)
		for foe in other.living():
			if ScrumReach.touching(mine, ScrumReach.area(other, foe)):
				return true
	return false

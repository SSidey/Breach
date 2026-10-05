class_name ScrumEngage
extends RefCounted
## Fights start where units meet (Decision 88, spec 27 round 6): with contact-seeking, two
## hostile squads whose units come within REACH of each other lock into a fight, whatever
## their faces - a squad passing beside a line, or a line it brushes, fights rather than
## walking by. A squad already fighting is joined by the one that reached it, and keeps
## its own foe. Every free squad picks the nearest hostile it has come within reach of, all
## from one snapshot before any lock lands, a tie going to the squads' seeded draws -
## never to the order they are listed in (Decision 97). Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")

## How far apart (cells, between their cells) two units may be for their squads to engage.
const REACH := 1.0


## Locks free squads onto hostile squads their units have come within reach of. Returns
## "engaged" events.
static func step(squads: Array, tick: int, fight_seed: int = 0) -> Array:
	var picks := {}  # squad -> the foe it locks onto, every one chosen before any lands
	for squad in squads:
		if _free(squad):
			var foe := _nearest(squad, squads, fight_seed)
			if foe != null:
				picks[squad] = foe
	var events := []
	for squad in picks:
		FormationLocks.lock(squad, picks[squad])
		events.append(
			FormationEvents.squad_event("engaged", tick, squad, {"with": picks[squad].id})
		)
	return events


static func _free(squad: SkirmishSquad) -> bool:
	return (
		FormationContact.can_engage(squad)
		and squad.engaged_with == 0
		and squad.flank_contacts.is_empty()
		and squad.state != SkirmishSquad.State.FIGHTING
		and squad.state != SkirmishSquad.State.TURNING
	)


## The hostile squad nearest `squad` within REACH (between their nearest units' cells),
## ties by the squads' draws; null if none is.
static func _nearest(squad: SkirmishSquad, squads: Array, fight_seed: int) -> SkirmishSquad:
	var best: SkirmishSquad = null
	var best_key := []
	for other in squads:
		if other.faction_id == squad.faction_id or not FormationContact.can_engage(other):
			continue
		var gap := _gap(squad, other)
		var key := [snappedf(gap, 0.000001), ScrumContest.squad_draw(other, fight_seed)]
		if gap <= REACH + 0.000001 and (best == null or key < best_key):
			best = other
			best_key = key
	return best


## Cells between the two squads' nearest units' bodies (0 where they touch or overlap).
static func _gap(squad: SkirmishSquad, other: SkirmishSquad) -> float:
	var least := INF
	for unit in squad.living():
		for foe in other.living():
			least = minf(least, ScrumReach.gap(squad, unit, other, foe))
	return least

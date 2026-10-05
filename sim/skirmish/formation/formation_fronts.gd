class_name FormationFronts
extends RefCounted
## Front-to-front locks (Decisions 40 and 97): every free squad picks the nearest hostile
## front within melee reach (FormationContact.nearest_hostile), all from one snapshot, then
## the locks land together - a squad between two foes isn't taken by whichever was listed
## first. A free foe that picked no one locks onto the nearest of the squads that picked it
## - unless it is getting away, retreating or routing: it may be engaged, but doesn't turn
## to fight (Decision 111).
## Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")


## Locks free squads onto the hostile fronts they reach. Adds "engaged" events.
static func engage(squads: Array, tick: int, fight_seed: int, events: Array) -> void:
	var picks := {}  # attacker -> foe, every one chosen before any lock lands
	for attacker in squads:
		if not FormationContact.can_engage(attacker) or attacker.engaged_with != 0:
			continue
		var foe := FormationContact.nearest_hostile(attacker, squads, fight_seed)
		if foe != null:
			picks[attacker] = foe
	for attacker in picks:
		FormationLocks.lock(attacker, picks[attacker])
		var extra := {"with": picks[attacker].id}
		events.append(FormationEvents.squad_event("engaged", tick, attacker, extra))
	for foe in picks.values():
		if foe.engaged_with != 0 or not FormationContact.can_engage(foe):
			continue  # one getting away doesn't turn to fight (Decision 111)
		var pickers := picks.keys().filter(func(a): return picks[a] == foe)
		var nearest := FormationContact.nearest_hostile(foe, pickers, fight_seed)
		if nearest != null:  # reach is mutual, so one always is
			FormationLocks.lock(foe, nearest)

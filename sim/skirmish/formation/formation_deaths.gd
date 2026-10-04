class_name FormationDeaths
extends RefCounted
## Deaths (specs/22-formation-feel-test.md, Decisions 47 and 82): units at 0 hp die and
## shake their squad, the ranks behind step up, a squad whose front fell frees its enemy
## to advance (not with contact-seeking: units find the fight themselves), and a squad
## with no one left is destroyed, freeing whoever fought it. Pure over the squads.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")


static func bury(squads: Array, tick: int, seek_contact: bool, events: Array) -> void:
	for fallen_squad: SkirmishSquad in squads:
		var fallen := []
		for unit in fallen_squad.living():
			if unit.hp <= 0:
				unit.state = SkirmishUnit.State.DEAD
				fallen.append(unit)
				events.append(FormationEvents.unit_event("died", tick, fallen_squad, unit))
		if fallen.is_empty():
			continue
		FormationMorale.losses(fallen_squad, fallen, tick, events)
		var front_before: float = fallen_squad.front_distance
		for moved in fallen_squad.compact():
			var extra := {"rank": moved.rank}
			events.append(
				FormationEvents.unit_event("stepped_up", tick, fallen_squad, moved, extra)
			)
		fallen_squad.reforming = true  # front units may close gaps (Decision 49)
		if not is_equal_approx(front_before, fallen_squad.front_distance) and not seek_contact:
			# Its front fell: the enemy must advance (Decision 47).
			FormationLocks.release(fallen_squad, squads)
			events.append(FormationEvents.squad_event("front_fell", tick, fallen_squad))
		if fallen_squad.is_destroyed() and fallen_squad.state != SkirmishSquad.State.DESTROYED:
			fallen_squad.state = SkirmishSquad.State.DESTROYED
			FormationLocks.release(fallen_squad, squads)
			events.append(FormationEvents.squad_event("destroyed", tick, fallen_squad))

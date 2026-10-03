class_name FormationLocks
extends RefCounted
## Which squads are locked in a fight (Decisions 40 and 47): a lock makes a squad fight its
## foe from this tick; a release frees it and everyone fighting it. A turning squad keeps
## turning through either and takes up the fight when the turn ends (Decision 74).
## Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")


static func lock(squad: SkirmishSquad, foe: SkirmishSquad) -> void:
	squad.engaged_with = foe.id
	if squad.state != SkirmishSquad.State.TURNING:
		squad.state = SkirmishSquad.State.FIGHTING
	if not squad.joined.is_empty():
		squad.reforming = true  # units merged on the march may now spread
	for unit in squad.living():
		unit.attack_cooldown = 1  # the first blows land this tick


## Ends a squad's fight and frees every squad that was fighting it.
static func release(released: SkirmishSquad, squads: Array) -> void:
	_free(released)
	for other in squads:
		if other.engaged_with == released.id:
			_free(other)


static func _free(squad: SkirmishSquad) -> void:
	squad.engaged_with = 0
	if squad.state == SkirmishSquad.State.FIGHTING:
		squad.state = SkirmishSquad.State.MOVING

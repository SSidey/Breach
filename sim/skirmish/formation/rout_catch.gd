class_name RoutCatch
extends RefCounted
## Which friendly formation catches a router (Decisions 82, 89 and 98): any standing
## friend a router runs into holds it, wherever it then steps to, until it joins that
## formation or the formation itself routs; the nearest friend catches, not the first
## listed. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")


## The formation holding a router (its `entry` in the routing squad's `fleeing`): the one
## that caught it while it stands, else the nearest friend within `reach` of `at`.
static func holder(
	squad: SkirmishSquad, entry: Dictionary, at: Vector2, squads: Array, reach: float
) -> SkirmishSquad:
	for friend in squads:
		if friend.id == entry.get("held_by") and stands(friend):
			return friend
	return friend_near(squad, at, squads, reach, false)


## The nearest standing friendly formation with a unit within `reach` of `at`; if `led`,
## only one with a leader.
static func friend_near(
	squad: SkirmishSquad, at: Vector2, squads: Array, reach: float, led: bool
) -> SkirmishSquad:
	var best: SkirmishSquad = null
	var best_gap := INF
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id or not stands(friend):
			continue
		if led and FormationMorale.leadership(friend) < 1:
			continue
		for unit in friend.living():
			var gap := ScrumReach.at(friend, unit).distance_to(at)
			if gap <= reach and gap < best_gap:
				best = friend
				best_gap = gap
	return best


## True if the formation is neither routing nor destroyed.
static func stands(squad: SkirmishSquad) -> bool:
	return not squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]

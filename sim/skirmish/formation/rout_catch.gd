class_name RoutCatch
extends RefCounted
## Which friendly formation catches a router (Decisions 82, 89 and 98; spec 27 round 11):
## any standing friend a router has run into and got behind - the friend now between it and
## the enemy - holds it, wherever it then steps to, until it joins that formation (its rear)
## or the formation itself routs; the nearest friend catches, not the first
## listed, a tie going to the friends' units' seeded draws (Decision 97). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")


## The formation holding a router (its `entry` in the routing squad's `fleeing`): the one
## that caught it while it stands, else the nearest friend within `reach` of `at`.
static func holder(
	squad: SkirmishSquad,
	entry: Dictionary,
	at: Vector2,
	squads: Array,
	reach: float,
	fight_seed: int = 0
) -> SkirmishSquad:
	for friend in squads:
		if friend.id == entry.get("held_by") and stands(friend):
			return friend
	return friend_near(squad, at, squads, reach, false, fight_seed)


## The nearest standing friendly formation with a unit's body within `reach` of `at`
## (measured to the body's edge, Decision 106); if `led`, only one with a leader.
static func friend_near(
	squad: SkirmishSquad, at: Vector2, squads: Array, reach: float, led: bool, fight_seed: int = 0
) -> SkirmishSquad:
	var best: SkirmishSquad = null
	var best_key := []
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id or not stands(friend):
			continue
		if led and FormationMorale.leadership(friend) < 1:
			continue
		for unit in friend.living():
			var there := ScrumReach.at(friend, unit)
			var gap := there.distance_to(at) - ScrumReach.radius(unit)
			var key := [snappedf(gap, 0.000001), ScrumContest.draw(unit, fight_seed)]
			if gap <= reach and behind(squad, at, there) and (best == null or key < best_key):
				best = friend
				best_key = key
	return best


## Cells from `at` to the formation's nearest living unit.
static func gap(squad: SkirmishSquad, at: Vector2) -> float:
	var least := INF
	for unit in squad.living():
		least = minf(least, ScrumReach.at(squad, unit).distance_to(at))
	return least


## True if a router at `at` has got behind a friend's unit at `there`: past it, on the
## side of its route towards home, so the friend stands between it and the enemy.
static func behind(squad: SkirmishSquad, at: Vector2, there: Vector2) -> bool:
	if squad.route == null:
		return true
	var home: float = squad.home_distance * MapLayoutDef.CELLS_PER_TILE
	var mine: float = squad.route.distance_of(at)
	var theirs: float = squad.route.distance_of(there)
	return (mine - theirs) * (home - theirs) >= 0.0


## True if the formation is neither routing nor destroyed.
static func stands(squad: SkirmishSquad) -> bool:
	return not squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]
